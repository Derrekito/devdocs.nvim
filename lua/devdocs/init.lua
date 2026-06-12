-- devdocs.nvim — offline reference docs from devdocs.io, converted to real
-- markdown at install time by scripts/convert.py (purpose-built for the
-- structures generic converters mangle: cppreference declaration/revision
-- tables, Sphinx definition lists, …). Opening a page is just reading a
-- pre-converted .md into a scratch buffer.
--
-- :Devdocs                  — fuzzy-browse every installed docset
-- :Devdocs <query>          — browse, pre-filtered
-- :Devdocs <docset> [query] — browse one docset
-- :DevdocsUpdate [docset]   — download + convert one docset (default: all)
-- gK (mapped filetypes)     — exact lookup of the symbol under the cursor

local M = {}

M.config = {
  data_dir = vim.fn.stdpath("data") .. "/devdocs",
  -- name -> docset definition. slug is the devdocs.io document slug
  -- (https://devdocs.io/docs.json); lang is the default code-fence language
  -- used during conversion; prefixes are tried for unqualified gK lookups.
  docsets = {
    cpp    = { slug = "cpp",         lang = "cpp",    prefixes = { "std::" } },
    c      = { slug = "c",           lang = "c" },
    lua    = { slug = "lua~5.1",     lang = "lua" },
    bash   = { slug = "bash",        lang = "bash" },
    cmake  = { slug = "cmake",       lang = "cmake" },
    python = { slug = "python~3.14", lang = "python" },
  },
  -- filetype -> docset name (drives the gK mapping)
  filetypes = {
    cpp = "cpp", c = "c", lua = "lua", python = "python", cmake = "cmake",
    sh = "bash", bash = "bash", zsh = "bash",
  },
  -- chars temporarily added to iskeyword so <cword> captures qualified names
  keyword_chars = { cpp = ":", lua = ".", python = "." },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- ── data access ──────────────────────────────────────────────────────────────

local index_cache = {}

local function root(name)
  return M.config.data_dir .. "/" .. M.config.docsets[name].slug
end

local function load_index(name)
  if index_cache[name] then return index_cache[name] end
  local f = io.open(root(name) .. "/index.json", "r")
  if not f then return nil end
  index_cache[name] = vim.json.decode(f:read("*a"))
  f:close()
  return index_cache[name]
end

-- Installed = index.json exists.
function M.installed()
  local names = {}
  for name, _ in pairs(M.config.docsets) do
    if vim.fn.filereadable(root(name) .. "/index.json") == 1 then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

-- ── viewing ──────────────────────────────────────────────────────────────────

-- Show a pre-converted markdown page (path without #anchor) in a split.
local function show(docset, name, path)
  local file = root(docset) .. "/pages-md/" .. path:gsub("#.*$", "") .. ".md"
  if vim.fn.filereadable(file) == 0 then
    vim.notify("devdocs: page missing: " .. file .. " — run :DevdocsUpdate " .. docset,
      vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true) -- scratch, unlisted
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(file))
  vim.api.nvim_buf_set_name(buf, "devdocs://" .. docset .. "/" .. name)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
  -- Set the filetype only AFTER the buffer is displayed: renderers like
  -- render-markdown.nvim attach on FileType and do their initial paint on the
  -- windows showing the buffer — firing it while hidden leaves the page
  -- unrendered (attached but never painted).
  vim.bo[buf].filetype = "markdown"
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.conceallevel = 2
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "close devdocs page" })

  -- Single-page docsets (e.g. the Lua manual) address entries by anchor;
  -- jump to the entry's name inside the page instead of staying at the top.
  if path:find("#", 1, true) then
    vim.fn.search("\\V" .. vim.fn.escape(name, "\\"), "cw")
  end
end

-- Find an index entry by exact name, trying docset prefixes for unqualified
-- words (e.g. vector -> std::vector) and the "name()" form many docsets use
-- (string.format(), add_library(), str.split()). Exposed for tests.
function M._find_entry(docset, word)
  local idx = load_index(docset)
  if not idx then return nil end
  local stems = { word }
  for _, p in ipairs(M.config.docsets[docset].prefixes or {}) do
    table.insert(stems, p .. word)
  end
  local candidates = {}
  for _, s in ipairs(stems) do
    table.insert(candidates, s)
    table.insert(candidates, s .. "()")
  end
  for _, candidate in ipairs(candidates) do
    for _, e in ipairs(idx.entries) do
      if e.name == candidate then return e end
    end
  end
  return nil
end

-- Exact lookup; falls back to the picker pre-filtered with the word.
function M.open(word, docset)
  if not load_index(docset) then
    vim.notify("devdocs: docset '" .. docset .. "' not installed — run :DevdocsUpdate " .. docset,
      vim.log.levels.WARN)
    return
  end
  local entry = M._find_entry(docset, word)
  if entry then
    show(docset, entry.name, entry.path)
  else
    M.search(word, docset)
  end
end

-- ── searching ────────────────────────────────────────────────────────────────

-- Telescope picker over one docset's entries, or all installed docsets.
function M.search(query, docset)
  local items = {}
  local names = docset and { docset } or M.installed()
  if #names == 0 then
    vim.notify("devdocs: no docsets installed — run :DevdocsUpdate", vim.log.levels.WARN)
    return
  end
  local tag = #names > 1
  for _, name in ipairs(names) do
    local idx = load_index(name)
    if idx then
      for _, e in ipairs(idx.entries) do
        table.insert(items, {
          docset = name,
          entry = e,
          label = tag and ("[" .. name .. "] " .. e.name) or e.name,
        })
      end
    end
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = docset and ("devdocs: " .. docset) or "devdocs",
    default_text = query or "",
    finder = finders.new_table({
      results = items,
      entry_maker = function(it)
        return { value = it, display = it.label, ordinal = it.label }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        actions.close(bufnr)
        local sel = action_state.get_selected_entry()
        if sel then show(sel.value.docset, sel.value.entry.name, sel.value.entry.path) end
      end)
      return true
    end,
  }):find()
end

-- ── updating ─────────────────────────────────────────────────────────────────

local function plugin_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h")
end

local function update_one(name)
  local ds = M.config.docsets[name]
  local r = root(name)
  local script = ([[
set -e
mkdir -p %s/pages
curl -s "https://documents.devdocs.io/%s/index.json" -o %s/index.json
curl -s "https://documents.devdocs.io/%s/db.json" -o "$tmp"
python - <<'PY'
import json, pathlib, os
root = pathlib.Path("%s/pages")
db = json.load(open(os.environ["tmp"]))
for path, html in db.items():
    f = root / (path + ".html")
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(html)
print("pages:", len(db))
PY
python %s %s --lang=%s
rm -f "$tmp"
]]):format(
    vim.fn.shellescape(r), ds.slug, vim.fn.shellescape(r), ds.slug, r,
    vim.fn.shellescape(plugin_root() .. "/scripts/convert.py"),
    vim.fn.shellescape(r), ds.lang or "text")
  local out = vim.fn.system({ "sh", "-c", "tmp=$(mktemp); export tmp; " .. script })
  index_cache[name] = nil
  local ok = vim.v.shell_error == 0
  vim.notify(("devdocs: %s %s — %s"):format(name, ok and "updated" or "FAILED", vim.trim(out)),
    ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  return ok
end

-- Download + convert a docset (or all configured docsets). Blocking.
function M.update(name)
  if name and name ~= "all" then
    if not M.config.docsets[name] then
      vim.notify("devdocs: unknown docset '" .. name .. "'", vim.log.levels.ERROR)
      return
    end
    update_one(name)
    return
  end
  local names = vim.tbl_keys(M.config.docsets)
  table.sort(names)
  for _, n in ipairs(names) do
    update_one(n)
  end
end

-- ── command plumbing ─────────────────────────────────────────────────────────

-- :Devdocs [docset] [query...]
function M.cmd(fargs)
  local docset = nil
  if fargs[1] and M.config.docsets[fargs[1]] then
    docset = table.remove(fargs, 1)
  end
  M.search(table.concat(fargs, " "), docset)
end

-- ── LSP-aware lookup ─────────────────────────────────────────────────────────
-- The word under the cursor is often not the thing to document: a variable
-- should resolve to its TYPE (oss -> std::basic_ostringstream) and a member
-- to Type::member (str -> std::basic_ostringstream::str). clangd knows both:
-- textDocument/symbolInfo gives {name, containerName} for members, and hover
-- exposes a variable's type as "Type: `std::ostringstream (aka
-- basic_ostringstream<char>)`". Candidates are validated against the docset
-- index, so wrong guesses cost nothing.

-- Normalize a type spelling to index form: drop template args, cv/ref
-- qualifiers, implementation inline namespaces, and trailing '::'.
function M._normalize_type(t)
  t = t:gsub("%b<>", "")
  t = t:gsub("__cxx11::", ""):gsub("__1::", "")
  t = t:gsub("const ", ""):gsub("volatile ", "")
  t = t:gsub("^%s+", ""):gsub("[%s&%*]+$", "")
  t = t:gsub("::$", "")
  return t
end

-- Candidates from a clangd hover markdown blob ("Type: `X (aka Y)`").
function M._hover_candidates(markdown)
  local ty = markdown and markdown:match("Type: `([^`\n]+)`")
  if not ty then return {} end
  local primary = ty:match("^(.-)%s*%(aka%s") or ty
  local aka = ty:match("%(aka%s+(.*)%)%s*$")
  local out = {}
  for _, raw in ipairs({ primary, aka }) do
    if raw then
      local n = M._normalize_type(raw)
      if n ~= "" then
        table.insert(out, n)
        if not n:match("^std::") then table.insert(out, "std::" .. n) end
      end
    end
  end
  return out
end

-- Candidate from a clangd textDocument/symbolInfo response (member case).
function M._symbol_candidates(res)
  local sym = res and res[1]
  if not (sym and sym.name) then return {} end
  local container = M._normalize_type(sym.containerName or "")
  if container == "" or not container:find("::", 1, true) then
    -- container is a bare function/file scope, not a qualified type
    return {}
  end
  return { container .. "::" .. sym.name }
end

-- Ask the buffer's LSP for lookup candidates; cb receives a (possibly empty)
-- ordered list. Member resolution (symbolInfo) outranks type-of-variable
-- (hover); both fire in parallel with a guard timeout.
function M._lsp_candidates(bufnr, cb)
  if #vim.lsp.get_clients({ bufnr = bufnr }) == 0 then
    cb({})
    return
  end
  local params = vim.lsp.util.make_position_params(0, "utf-16")
  local results = { sym = {}, hover = {} }
  local pending, fired = 2, false
  local function step()
    pending = pending - 1
    if pending > 0 or fired then return end
    fired = true
    local out = {}
    vim.list_extend(out, results.sym)
    vim.list_extend(out, results.hover)
    cb(out)
  end
  vim.lsp.buf_request(bufnr, "textDocument/symbolInfo", params, function(_, res)
    results.sym = M._symbol_candidates(res)
    step()
  end)
  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(_, res)
    local md = res and res.contents and res.contents.value
    results.hover = M._hover_candidates(md)
    step()
  end)
  vim.defer_fn(function()
    if not fired then
      fired = true
      cb({})
    end
  end, 2000)
end

-- gK handler: LSP-resolved candidates first (validated against the index),
-- then the (possibly qualified) word under the cursor.
function M.lookup_cword()
  local docset = M.config.filetypes[vim.bo.filetype]
  if not docset then return end
  local extra = M.config.keyword_chars[docset]
  local word
  if extra then
    local save = vim.bo.iskeyword
    vim.bo.iskeyword = save .. "," .. extra
    word = vim.fn.expand("<cword>")
    vim.bo.iskeyword = save
  else
    word = vim.fn.expand("<cword>")
  end

  M._lsp_candidates(vim.api.nvim_get_current_buf(), function(candidates)
    for _, c in ipairs(candidates) do
      local e = M._find_entry(docset, c)
      if e then
        M.open(c, docset)
        return
      end
    end
    if word ~= "" then M.open(word, docset) end
  end)
end

return M
