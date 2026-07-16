-- Code-example navigation: jump between the fenced code blocks of a doc page
-- (]c / [c), yank the block under the cursor (gy), and a Telescope picker
-- over every fenced example in the notes sources (:DevdocsExamples) that
-- opens the page positioned at the example.
--
-- In-page block positions come from the buffer itself in the markdown viewer;
-- the man viewer records located block regions while highlighting
-- (vim.b.devdocs_code_blocks), since troff output no longer contains fences.

local data = require("devdocs.data")

local M = {}

local function cfg()
  return require("devdocs").config
end

-- ── in-page blocks ───────────────────────────────────────────────────────────

-- Code blocks of the doc page in `buf`: { srow, erow, lang, lines }, 1-based,
-- rows spanning the code itself (not the fence markers). `lines` is the
-- original code — in the man viewer that differs from the (indented) rendered
-- rows, so gy always yanks clean source.
function M.buf_blocks(buf)
  local man = vim.b[buf].devdocs_code_blocks
  if man then return man end
  local blocks, cur = {}, nil
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if cur then
      if line:match("^```") then
        cur.erow = i - 1
        if cur.erow >= cur.srow then table.insert(blocks, cur) end
        cur = nil
      else
        table.insert(cur.lines, line)
      end
    else
      local lang = line:match("^```(%w*)")
      if lang then
        cur = { srow = i + 1, lang = lang ~= "" and lang or "text", lines = {} }
      end
    end
  end
  return blocks
end

-- ]c / [c: move to the first code line of the next/previous block.
function M.jump(dir)
  local blocks = M.buf_blocks(vim.api.nvim_get_current_buf())
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if dir > 0 then
    for _, b in ipairs(blocks) do
      if b.srow > row then
        target = b
        break
      end
    end
  else
    for _, b in ipairs(blocks) do
      if b.srow < row then target = b else break end
    end
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target.srow, 0 })
  else
    vim.notify("devdocs: no " .. (dir > 0 and "next" or "previous") .. " code block",
      vim.log.levels.INFO)
  end
end

-- Yank `lines` linewise into the unnamed register (and the system clipboard
-- when available).
local function yank_lines(lines, lang)
  vim.fn.setreg('"', lines, "l")
  pcall(vim.fn.setreg, "+", lines, "l")
  vim.notify(("devdocs: yanked %d-line %s block"):format(#lines, lang), vim.log.levels.INFO)
end

-- gy: yank the code block under the cursor (fence lines count as inside).
function M.yank()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for _, b in ipairs(M.buf_blocks(vim.api.nvim_get_current_buf())) do
    if row >= b.srow - 1 and row <= b.erow + 1 then
      yank_lines(b.lines, b.lang)
      return
    end
  end
  vim.notify("devdocs: no code block at cursor (]c jumps to one)", vim.log.levels.INFO)
end

-- ── examples index ───────────────────────────────────────────────────────────

-- Fenced blocks of one notes file, each titled by the nearest heading above
-- it: { lang, lines, title }.
local function parse_file(file)
  local out, heading, cur = {}, nil, nil
  for _, line in ipairs(vim.fn.readfile(file)) do
    if cur then
      if line:match("^```") then
        table.insert(out, cur)
        cur = nil
      else
        table.insert(cur.lines, line)
      end
    else
      local lang = line:match("^```(%w*)")
      local h = line:match("^#+%s+(.+)")
      if lang then
        cur = { lang = lang ~= "" and lang or "text", lines = {}, title = heading }
      elseif h then
        heading = h
      end
    end
  end
  return out
end

-- The index entry a notes annotation extends (annotations mirror generated
-- page paths). Falls back to the raw path when the docset isn't installed.
local function page_for(docset, rel)
  local idx = data.load_index(docset)
  if idx then
    for _, e in ipairs(idx.entries) do
      if e.path:gsub("#.*$", "") == rel then return e.name, e.path end
    end
  end
  return rel, rel
end

-- Every fenced example across the notes sources (```text fences are expected
-- output, not examples — skipped). Returns
-- { docset, page_name, page_path, title, lang, lines }.
function M.entries(docset)
  local notes = require("devdocs.notes")
  local out = {}
  for _, d in ipairs(notes.dirs()) do
    for name, _ in pairs(cfg().docsets) do
      if not docset or name == docset then
        local base = d .. "/" .. name
        for _, f in ipairs(vim.fn.glob(base .. "/**/*.md", false, true)) do
          local rel = f:sub(#base + 2):gsub("%.md$", "")
          local generated = data.root(name) .. "/pages-md/" .. rel .. ".md"
          local page_name, page_path
          if vim.fn.filereadable(generated) == 1 then
            page_name, page_path = page_for(name, rel)
          else
            -- custom page: named by its first '# heading', served from file
            page_path = f
            for _, line in ipairs(vim.fn.readfile(f, "", 10)) do
              page_name = line:match("^#%s+(.+)")
              if page_name then break end
            end
            page_name = page_name or vim.fn.fnamemodify(f, ":t:r")
          end
          for _, ex in ipairs(parse_file(f)) do
            if ex.lang ~= "text" and #ex.lines > 0 then
              table.insert(out, {
                docset = name,
                page_name = page_name,
                page_path = page_path,
                title = ex.title or page_name,
                lang = ex.lang,
                lines = ex.lines,
              })
            end
          end
        end
      end
    end
  end
  return out
end

-- Open the example's page and land on the example: find its section heading,
-- then the block's first code line below it (\c: troff may restyle heading
-- case; \V literal substring survives the man viewer's indentation).
local function open_example(ex)
  require("devdocs.view").show(ex.docset, ex.page_name, ex.page_path)
  if not vim.b.devdocs then return end -- page failed to open; don't move around
  local first
  for _, l in ipairs(ex.lines) do
    if l:match("%S") then
      first = l
      break
    end
  end
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  if ex.title then
    vim.fn.search("\\c\\V" .. vim.fn.escape(ex.title, "\\"), "cW")
  end
  if first then
    vim.fn.search("\\V" .. vim.fn.escape(first, "\\"), "W")
  end
end

-- Telescope picker over the examples index. Code content is part of the
-- match text, so queries like "stable_sort" find the example that uses it.
-- <CR> opens the page at the example; <C-y> yanks it without opening.
function M.picker(query, docset)
  local items = M.entries(docset)
  if #items == 0 then
    vim.notify("devdocs: no examples in notes" .. (docset and (" for " .. docset) or ""),
      vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local putils = require("telescope.previewers.utils")

  local tag = not docset
  pickers.new({}, {
    prompt_title = docset and ("devdocs examples: " .. docset) or "devdocs examples",
    default_text = query or "",
    finder = finders.new_table({
      results = items,
      entry_maker = function(it)
        local label = (tag and ("[" .. it.docset .. "] ") or "")
          .. it.page_name .. " › " .. it.title
        return {
          value = it,
          display = label,
          ordinal = label .. " " .. table.concat(it.lines, " "),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "example",
      define_preview = function(self, entry)
        local it = entry.value
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, it.lines)
        pcall(putils.highlighter, self.state.bufnr, it.lang)
      end,
    }),
    attach_mappings = function(bufnr, map)
      actions.select_default:replace(function()
        actions.close(bufnr)
        local sel = action_state.get_selected_entry()
        if sel then open_example(sel.value) end
      end)
      map({ "i", "n" }, "<C-y>", function()
        local sel = action_state.get_selected_entry()
        actions.close(bufnr)
        if sel then yank_lines(sel.value.lines, sel.value.lang) end
      end)
      return true
    end,
  }):find()
end

return M
