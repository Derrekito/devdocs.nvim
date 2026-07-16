-- Page display: the markdown and man viewers, man-style window navigation
-- (in-window replace + <C-T> history), the less-style pager help, and
-- treesitter code highlighting inside man-rendered pages.

local data = require("devdocs.data")

local M = {}

local function cfg()
  return require("devdocs").config
end

-- Capture the (possibly qualified) word under the cursor using the docset's
-- extra keyword chars (':' for cpp, '.' for lua/python, ...).
function M.capture_word(docset)
  local extra = cfg().keyword_chars[docset]
  if not extra then return vim.fn.expand("<cword>") end
  local save = vim.bo.iskeyword
  vim.bo.iskeyword = save .. "," .. extra
  local word = vim.fn.expand("<cword>")
  vim.bo.iskeyword = save
  return word
end

-- ── pager chrome ────────────────────────────────────────────────────────────

-- Per-window stack of visited pages, for man-style <C-T> back-navigation.
local history = {}

local help_hinted = false

-- less(1)-style help screen, so the pager feels like terminal man. Paging
-- and search are nvim's native keys (same letters as less, Ctrl-chorded), so
-- normal editor navigation stays untouched — the help screen just makes them
-- discoverable.
local HELP = {
  "  devdocs pager                              ",
  "",
  "  C-f / C-b      page forward / back         ",
  "  C-d / C-u      half page forward / back    ",
  "  /  ?  n  N     search forward / back       ",
  "  gg / G         top / bottom                ",
  "  K  C-]  gK     follow reference at cursor  ",
  "  ]c / [c        next / previous code block  ",
  "  gy             yank code block at cursor   ",
  "  C-t            previous page               ",
  "  gO             section TOC (man viewer)    ",
  "  C-h / g?       this help                   ",
  "  q  :q          back out (close at top)     ",
  "  Q  :q!         close page window           ",
}

local function show_pager_help()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local width = vim.fn.strdisplaywidth(HELP[1])
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = #HELP,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - #HELP) / 2),
    style = "minimal",
    border = "rounded",
    title = " help ",
    title_pos = "center",
  })
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, "<cmd>close<cr>", { buffer = buf, nowait = true })
  end
  return win
end

-- Nested-lookup quit: following references stacks pages man-style, so
-- quitting unwinds the stack — q (and :q) pops back to the parent page and
-- only closes the window once there is no parent left. force (Q / :q!)
-- closes outright, history or not.
function M.back_or_close(force)
  local win = vim.api.nvim_get_current_win()
  local h = history[win]
  local prev = not force and h and table.remove(h)
  if prev then
    M.show(prev.docset, prev.name, prev.path, false)
    return
  end
  history[win] = nil
  if not pcall(vim.api.nvim_win_close, win, false) then
    vim.cmd("quit" .. (force and "!" or "")) -- last window in the tab
  end
end

-- Keys inside both viewers. Paging/search use nvim's native chords (listed
-- in the help screen) so normal motions (h, b, d, u, Space) keep working:
--   K / <C-]> / gK  follow the reference under the cursor (same docset)
--   <C-T>           go back to the previous page
--   <C-H> / g?      help screen; q backs out, Q closes
local function map_page_keys(buf, docset)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = "devdocs: " .. desc, nowait = true })
  end

  map("q", function() M.back_or_close(false) end, "previous page / close")
  map("Q", function() M.back_or_close(true) end, "close page")
  map("<C-h>", show_pager_help, "pager help")
  map("g?", show_pager_help, "pager help")

  -- :q / :quit in a doc page mean "back out", like the q key — rewritten via
  -- buffer-local cmdline abbreviations. The bang survives expansion, so :q!
  -- becomes :DevdocsBack! (force close); :qa and longer commands are left
  -- alone (the getcmdline() guard only matches the bare command).
  for _, cmd in ipairs({ "q", "quit" }) do
    vim.keymap.set("ca", cmd, function()
      if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == cmd then
        return "DevdocsBack"
      end
      return cmd
    end, { buffer = buf, expr = true })
  end

  local follow = function()
    local word = M.capture_word(docset)
    if word ~= "" then require("devdocs").open(word, docset) end
  end
  for _, lhs in ipairs({ "K", "gK", "<C-]>" }) do
    map(lhs, follow, "follow reference")
  end

  -- code-example navigation: doc pages are never diff buffers, so ]c/[c are
  -- free to mean "next/previous code block" here
  local examples = require("devdocs.examples")
  map("]c", function() examples.jump(1) end, "next code block")
  map("[c", function() examples.jump(-1) end, "previous code block")
  map("gy", examples.yank, "yank code block")

  map("<C-t>", function()
    local h = history[vim.api.nvim_get_current_win()]
    local prev = h and table.remove(h)
    if prev then
      M.show(prev.docset, prev.name, prev.path, false)
    else
      vim.notify("devdocs: no previous page", vim.log.levels.INFO)
    end
  end, "previous page")

  -- one-time discoverability hint, in the spirit of less's prompt
  if not help_hinted then
    help_hinted = true
    vim.defer_fn(function()
      vim.notify("devdocs: press Ctrl-H for pager help", vim.log.levels.INFO)
    end, 100)
  end
end

-- Put a page buffer on screen: one docs window per tabpage. If any window
-- on the current tab is showing a devdocs page (the current one, or e.g.
-- the docs split while the cursor is in code), replace its page in place,
-- pushing the replaced page onto that window's <C-T> history unless this is
-- back-navigation. Otherwise open a split per config.
local function display(buf, page, push)
  -- "vertical"/"left"/"right" produce a vsplit; the rest are horizontal.
  local vertical = ({ vertical = true, left = true, right = true })[cfg().split] or false

  -- The code window we're opening docs alongside: the window gK was invoked
  -- from, when that isn't itself a docs window. We size THIS to config.width
  -- (docs take the leftover space), so the code frame stays at `width` columns
  -- rather than the docs pane being carved off the frame edge.
  local code_win
  if not vim.b[vim.api.nvim_get_current_buf()].devdocs then
    code_win = vim.api.nvim_get_current_win()
  end

  local target
  if vim.b[vim.api.nvim_get_current_buf()].devdocs then
    target = vim.api.nvim_get_current_win()
  elseif cfg().reuse_window ~= false then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.b[vim.api.nvim_win_get_buf(win)].devdocs then
        target = win
        break
      end
    end
  end

  if target then
    local prev = vim.b[vim.api.nvim_win_get_buf(target)].devdocs
    if push and prev then
      history[target] = history[target] or {}
      table.insert(history[target], prev)
    end
    vim.api.nvim_win_set_buf(target, buf)
    vim.api.nvim_set_current_win(target)
  else
    local split_cmds = {
      horizontal = "split",
      vertical = "vsplit",
      above = "aboveleft split",
      below = "belowright split",
      left = "aboveleft vsplit",
      right = "belowright vsplit",
    }
    vim.cmd(split_cmds[cfg().split] or "split")
    vim.api.nvim_win_set_buf(0, buf)
    target = vim.api.nvim_get_current_win()
  end

  -- Keep the code frame at config.width on EVERY display (docs get the rest):
  -- reuse_window means later gK / reference-follows reuse the docs window, so
  -- re-asserting here keeps the code pane from drifting. Explicit set_width
  -- survives 'equalalways' re-balancing; winfixwidth keeps <C-w>= and later
  -- splits off the code pane. When gK is fired from inside a docs page there's
  -- no code window to size, so we leave the layout alone.
  if cfg().pin and vertical and code_win and vim.api.nvim_win_is_valid(code_win) then
    vim.api.nvim_win_set_width(code_win, cfg().width)
    vim.wo[code_win].winfixwidth = true
  end

  vim.b[buf].devdocs = page
end

-- Buffer names must be unique. The previous page buffer wipes itself once
-- hidden (bufhidden=wipe), but a namesake can survive hidden in another
-- tabpage or via timing; drop it before naming the fresh buffer.
local function claim_buf_name(buf, name)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= buf and vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == name then
      if vim.fn.bufwinid(b) == -1 then
        vim.api.nvim_buf_delete(b, { force = true })
      end
    end
  end
  pcall(vim.api.nvim_buf_set_name, buf, name)
end

-- ── code highlighting in man pages ──────────────────────────────────────────
-- troff has no syntax highlighting, but we still have the markdown source:
-- extract its fenced code blocks, find their (verbatim, just indented) lines
-- in the rendered buffer, give each region a background, and paint real
-- treesitter captures over it via a string parser.

local code_ns = vim.api.nvim_create_namespace("devdocs.code")

-- Fenced blocks from the markdown source: { lang, lines }.
local function md_code_blocks(md_file)
  local blocks, cur = {}, nil
  for _, line in ipairs(vim.fn.readfile(md_file)) do
    local lang = line:match("^```(%w*)")
    if lang and not cur then
      cur = { lang = lang ~= "" and lang or "text", lines = {} }
    elseif line:match("^```") and cur then
      table.insert(blocks, cur)
      cur = nil
    elseif cur then
      table.insert(cur.lines, line)
    end
  end
  return blocks
end

-- Locate `lines` in `rendered` starting at row `from` (1-based): every
-- non-blank line must reappear in order as the suffix of a rendered line
-- (troff adds uniform leading indent). Returns first row and per-line cols.
local function locate_block(rendered, lines, from)
  local nonblank = vim.tbl_filter(function(l) return l:match("%S") end, lines)
  if #nonblank == 0 then return nil end
  for row = from, #rendered - #nonblank + 1 do
    local ok, cols, r = true, {}, row
    for _, ol in ipairs(nonblank) do
      -- skip blank rendered lines between code lines (troff may drop/keep them)
      while r <= #rendered and not rendered[r]:match("%S") do r = r + 1 end
      local rl = rendered[r] or ""
      if rl:sub(-#ol) == ol then
        cols[#cols + 1] = { row = r, col = #rl - #ol, text = ol }
        r = r + 1
      else
        ok = false
        break
      end
    end
    if ok then return row, cols, r end
  end
  return nil
end

-- Treesitter-highlight one code region. cols maps original code lines to
-- buffer rows/byte-offsets.
local function ts_highlight_region(buf, lang, cols)
  local code = {}
  for i, c in ipairs(cols) do code[i] = c.text end
  local source = table.concat(code, "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
  if not ok or not parser then return end
  local ok2, trees = pcall(parser.parse, parser)
  if not ok2 or not trees or not trees[1] then return end
  local query = vim.treesitter.query.get(lang, "highlights")
  if not query then return end

  for id, node in query:iter_captures(trees[1]:root(), source) do
    local capture = query.captures[id]
    local sr, sc, er, ec = node:range()
    -- only single-line captures map cleanly; multi-line ones are rare in
    -- reference snippets and safely skipped
    if sr == er and cols[sr + 1] then
      local c = cols[sr + 1]
      vim.api.nvim_buf_set_extmark(buf, code_ns, c.row - 1, c.col + sc, {
        end_col = c.col + ec,
        hl_group = "@" .. capture .. "." .. lang,
        priority = 105,
      })
    end
  end
end

-- Paint all code blocks of a man-rendered page: background for the block
-- (DevdocsCodeBlock, override to taste) + treesitter syntax. Located regions
-- are recorded in b:devdocs_code_blocks so ]c/[c/gy work here too — the
-- rendered page has no fences left to parse (lines hold the original code,
-- so gy yanks clean source, not troff indentation).
local function highlight_man_code(buf, md_file)
  vim.api.nvim_set_hl(0, "DevdocsCodeBlock", { default = true, link = "ColorColumn" })
  local rendered = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local from = 1
  local regions = {}
  for _, block in ipairs(md_code_blocks(md_file)) do
    local row, cols, next_from = locate_block(rendered, block.lines, from)
    if row then
      table.insert(regions, {
        srow = cols[1].row,
        erow = cols[#cols].row,
        lang = block.lang,
        lines = block.lines,
      })
      for _, c in ipairs(cols) do
        vim.api.nvim_buf_set_extmark(buf, code_ns, c.row - 1, 0, {
          line_hl_group = "DevdocsCodeBlock",
          priority = 90,
        })
      end
      if block.lang ~= "text" then
        ts_highlight_region(buf, block.lang, cols)
      end
      from = next_from
    end
  end
  vim.b[buf].devdocs_code_blocks = regions
end

-- ── viewers ─────────────────────────────────────────────────────────────────

-- Render the page as a man page (pandoc -> troff -> man -l) and hand the
-- output to nvim's :Man machinery: troff typesetting, bold/underline
-- highlights, gO section TOC. Returns false if any tool is missing/fails so
-- the caller can fall back to the markdown viewer.
local function show_man(docset, name, path, md_file, push)
  local src = vim.fn.tempname() .. ".3"
  local out = vim.fn.system({
    data.plugin_root() .. "/scripts/md2man.sh", md_file, src, name,
    docset .. " — devdocs",
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("devdocs: md2man failed (" .. vim.trim(out) .. ") — falling back to markdown",
      vim.log.levels.WARN)
    return false
  end
  local width = math.max(40, math.min(cfg().width or 100, vim.api.nvim_win_get_width(0) - 2))
  -- stderr must be discarded: troff emits adjustment warnings ("cannot adjust
  -- line; underset by Nn") for long unbreakable declarations, and systemlist
  -- merges stderr into the output, turning warnings into page content.
  local rendered = vim.fn.systemlist({
    "sh", "-c",
    ("MANWIDTH=%d man -l %s 2>/dev/null"):format(width, vim.fn.shellescape(src)),
  })
  os.remove(src)
  if vim.v.shell_error ~= 0 or #rendered == 0 then
    vim.notify("devdocs: man rendering failed — falling back to markdown", vim.log.levels.WARN)
    return false
  end

  -- :Man comes from a runtime plugin; load it on demand (absent under
  -- --noplugin, e.g. headless test runners).
  if vim.fn.exists(":Man") ~= 2 then
    vim.cmd("runtime plugin/man.lua")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, rendered)
  display(buf, { docset = docset, name = name, path = path }, push)
  local ok, err = pcall(vim.cmd, "Man!")
  if not ok then
    -- Rendering already succeeded; :Man! only adds highlighting/TOC. Degrade
    -- to plain man filetype rather than bouncing to the markdown viewer.
    vim.notify("devdocs: :Man! unavailable (" .. tostring(err) .. ") — plain man view",
      vim.log.levels.WARN)
    vim.bo[buf].filetype = "man"
  end
  claim_buf_name(buf, "devdocs-man://" .. docset .. "/" .. name)
  vim.bo[buf].bufhidden = "wipe"
  pcall(highlight_man_code, buf, md_file)
  -- (also overrides :Man!'s pager-mode q, which can quit nvim when this is
  -- the last window — close just the split instead)
  map_page_keys(buf, docset)
  if path:find("#", 1, true) then
    vim.fn.search("\\V" .. vim.fn.escape(name, "\\"), "cw")
  end
  return true
end

-- Merged page content: the generated page plus any annotations from the
-- configured notes_dirs (an absolute path is a custom notes page, served
-- directly from its file). Both viewers and the :Devdocs previewer render
-- exactly these lines. Returns nil, file when the page file is absent.
function M.page_lines(docset, path)
  local custom = path:sub(1, 1) == "/"
  local file = custom and path
    or (data.root(docset) .. "/pages-md/" .. path:gsub("#.*$", "") .. ".md")
  if vim.fn.filereadable(file) == 0 then return nil, file end
  local lines = vim.fn.readfile(file)
  local annotations = custom and {} or require("devdocs.notes").annotations(docset, path)
  for _, a in ipairs(annotations) do
    table.insert(lines, "")
    vim.list_extend(lines, vim.fn.readfile(a))
  end
  return lines, file, #annotations > 0
end

-- Show a page (path without #anchor). push=false means back-navigation
-- (don't record the page we're leaving in the window history).
function M.show(docset, name, path, push)
  if push == nil then push = true end

  -- Reopening a page that's already on screen just focuses it (close it
  -- first with q if you want a rebuild, e.g. after editing its notes).
  if push then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local p = vim.b[vim.api.nvim_win_get_buf(win)].devdocs
      if p and p.docset == docset and p.name == name then
        vim.api.nvim_set_current_win(win)
        vim.notify("devdocs: already open — " .. name, vim.log.levels.INFO)
        return
      end
    end
  end
  local lines, file, annotated = M.page_lines(docset, path)
  if not lines then
    vim.notify("devdocs: page missing: " .. file .. " — run :DevdocsUpdate " .. docset,
      vim.log.levels.WARN)
    return
  end

  if cfg().viewer == "man" then
    local md_file, tmp = file, nil
    if annotated then
      tmp = vim.fn.tempname() .. ".md"
      vim.fn.writefile(lines, tmp)
      md_file = tmp
    end
    local shown = show_man(docset, name, path, md_file, push)
    if tmp then os.remove(tmp) end
    if shown then return end
  end

  local buf = vim.api.nvim_create_buf(false, true) -- scratch, unlisted
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Regular buftype, not nofile: renderers special-case nofile as "LSP hover
  -- float" and pad block-width backgrounds with NormalFloat, which bleeds a
  -- float-colored band to the window edge in a normal split.
  vim.bo[buf].buftype = ""
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  display(buf, { docset = docset, name = name, path = path }, push)
  -- Name AFTER displaying: replacing a window's previous page buffer lets it
  -- wipe (bufhidden), freeing the name a reopened page needs (E95 otherwise).
  claim_buf_name(buf, "devdocs://" .. docset .. "/" .. name)
  -- Set the filetype only AFTER the buffer is displayed: renderers like
  -- render-markdown.nvim attach on FileType and do their initial paint on the
  -- windows showing the buffer — firing it while hidden leaves the page
  -- unrendered (attached but never painted).
  vim.bo[buf].filetype = "markdown"
  -- Prose is hard-wrapped at config.width by the converter, so display
  -- wrapping is unnecessary — and renderers' block-width code backgrounds
  -- bleed to the window edge under 'wrap'.
  vim.wo.wrap = false
  vim.wo.conceallevel = 2
  map_page_keys(buf, docset)

  -- Single-page docsets (e.g. the Lua manual) address entries by anchor;
  -- jump to the entry's name inside the page instead of staying at the top.
  if path:find("#", 1, true) then
    vim.fn.search("\\V" .. vim.fn.escape(name, "\\"), "cw")
  end
end

return M
