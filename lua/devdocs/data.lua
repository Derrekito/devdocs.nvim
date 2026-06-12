-- Docset data on disk: index loading/caching, install state, entry lookup,
-- and the download+convert pipeline. Config is read lazily from the main
-- module so there is no load-time cycle.

local M = {}

local index_cache = {}

local function cfg()
  return require("devdocs").config
end

function M.plugin_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h")
end

function M.root(name)
  return cfg().data_dir .. "/" .. cfg().docsets[name].slug
end

-- Drop cached indexes (config changed or docset re-downloaded).
function M.invalidate(name)
  if name then
    index_cache[name] = nil
  else
    index_cache = {}
  end
end

function M.load_index(name)
  if index_cache[name] then return index_cache[name] end
  local f = io.open(M.root(name) .. "/index.json", "r")
  if not f then return nil end
  index_cache[name] = vim.json.decode(f:read("*a"))
  f:close()
  return index_cache[name]
end

-- Installed = index.json exists.
function M.installed()
  local names = {}
  for name, _ in pairs(cfg().docsets) do
    if vim.fn.filereadable(M.root(name) .. "/index.json") == 1 then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

-- Find an index entry by exact name, trying docset prefixes for unqualified
-- words (e.g. vector -> std::vector) and the "name()" form many docsets use
-- (string.format(), add_library(), str.split()).
function M.find_entry(docset, word)
  local idx = M.load_index(docset)
  if not idx then return nil end
  local stems = { word }
  for _, p in ipairs(cfg().docsets[docset].prefixes or {}) do
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

-- Last-resort lookup for LSP-derived type names: clangd hover prints types
-- as visible from the cursor's scope, often without their namespace
-- ('directory_entry' for std::filesystem::directory_entry). Match entries
-- ending in '::word' and pick the shortest name (the most general page).
-- Not used for raw cursor words — a variable named 'size' must not resolve
-- to std::vector::size.
function M.find_entry_suffix(docset, word)
  if word:find("::", 1, true) then return nil end
  local idx = M.load_index(docset)
  if not idx then return nil end
  local suffix = "::" .. word
  local best
  for _, e in ipairs(idx.entries) do
    if e.name:sub(-#suffix) == suffix then
      if not best or #e.name < #best.name then best = e end
    end
  end
  return best
end

-- ── download + convert ──────────────────────────────────────────────────────

local function update_one(name)
  local ds = cfg().docsets[name]
  local r = M.root(name)
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
python %s %s --lang=%s --width=%d
rm -f "$tmp"
]]):format(
    vim.fn.shellescape(r), ds.slug, vim.fn.shellescape(r), ds.slug, r,
    vim.fn.shellescape(M.plugin_root() .. "/scripts/convert.py"),
    vim.fn.shellescape(r), ds.lang or "text", cfg().width or 80)
  local out = vim.fn.system({ "sh", "-c", "tmp=$(mktemp); export tmp; " .. script })
  M.invalidate(name)
  local ok = vim.v.shell_error == 0
  vim.notify(("devdocs: %s %s — %s"):format(name, ok and "updated" or "FAILED", vim.trim(out)),
    ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  return ok
end

-- Download + convert a docset (or all configured docsets). Blocking.
function M.update(name)
  if name and name ~= "all" then
    if not cfg().docsets[name] then
      vim.notify("devdocs: unknown docset '" .. name .. "'", vim.log.levels.ERROR)
      return
    end
    update_one(name)
    return
  end
  local names = vim.tbl_keys(cfg().docsets)
  table.sort(names)
  for _, n in ipairs(names) do
    update_one(n)
  end
end

return M
