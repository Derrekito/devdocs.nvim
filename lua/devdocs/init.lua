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
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.conceallevel = 2
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "close devdocs page" })
end

-- Find an index entry by exact name, trying docset prefixes for unqualified
-- words (e.g. vector -> std::vector). Exposed for tests.
function M._find_entry(docset, word)
  local idx = load_index(docset)
  if not idx then return nil end
  local candidates = { word }
  for _, p in ipairs(M.config.docsets[docset].prefixes or {}) do
    table.insert(candidates, p .. word)
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

-- gK handler: capture the (possibly qualified) word under the cursor and
-- look it up in the buffer's docset.
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
  if word ~= "" then M.open(word, docset) end
end

return M
