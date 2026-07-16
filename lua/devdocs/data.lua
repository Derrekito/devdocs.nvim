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

-- Where :DevdocsUpdate downloads and converts to.
function M.download_root(name)
  return cfg().data_dir .. "/" .. cfg().docsets[name].slug
end

-- Content root for reads: an owned manual (a tree with index.json +
-- pages-md/ under a manual_dirs entry, e.g. a git submodule checked out at
-- manuals/<name>) takes precedence over the downloaded tree in data_dir.
function M.root(name)
  for _, d in ipairs(cfg().manual_dirs or {}) do
    local r = vim.fn.expand(d) .. "/" .. name
    if vim.fn.filereadable(r .. "/index.json") == 1 then return r end
  end
  return M.download_root(name)
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

local function update_one(name, done)
  local ds = cfg().docsets[name]
  local r = M.download_root(name)
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
  vim.system({ "sh", "-c", "tmp=$(mktemp); export tmp; " .. script }, { text = true },
    function(res)
      vim.schedule(function()
        M.invalidate(name)
        local ok = res.code == 0
        local out = vim.trim((res.stdout or "") .. (res.stderr or ""))
        vim.notify(("devdocs: %s %s — %s"):format(name, ok and "updated" or "FAILED", out),
          ok and vim.log.levels.INFO or vim.log.levels.ERROR)
        if done then done() end
      end)
    end)
end

-- Download + convert a docset (or all configured docsets). Runs in the
-- background (vim.system): the editor stays responsive; each docset notifies
-- as it finishes. Multiple docsets run sequentially — one download + one
-- python conversion at a time is plenty, and the notifications stay ordered.
function M.update(name)
  if name and name ~= "all" then
    if not cfg().docsets[name] then
      vim.notify("devdocs: unknown docset '" .. name .. "'", vim.log.levels.ERROR)
      return
    end
    vim.notify("devdocs: updating " .. name .. " in the background…", vim.log.levels.INFO)
    update_one(name)
    return
  end
  local names = vim.tbl_keys(cfg().docsets)
  table.sort(names)
  vim.notify("devdocs: updating " .. table.concat(names, ", ") .. " in the background…",
    vim.log.levels.INFO)
  local i = 0
  local function next_one()
    i = i + 1
    if names[i] then update_one(names[i], next_one) end
  end
  next_one()
end

-- :DevdocsAdopt <docset> — take ownership of a docset: copy the installed
-- tree (index.json + pages-md, not the intermediate HTML) into
-- manual_dirs[1]/<name>, ready to refine, commit, and split into its own
-- repo (e.g. added back here as a git submodule). Reads prefer the manual
-- from then on; :DevdocsUpdate keeps writing only to data_dir.
function M.adopt(name)
  if not name or not cfg().docsets[name] then
    vim.notify("devdocs: unknown docset '" .. tostring(name) .. "'", vim.log.levels.ERROR)
    return
  end
  local dirs = cfg().manual_dirs or {}
  if #dirs == 0 then
    vim.notify("devdocs: no manual_dirs configured", vim.log.levels.ERROR)
    return
  end
  local src = M.download_root(name)
  if vim.fn.filereadable(src .. "/index.json") == 0 then
    vim.notify("devdocs: '" .. name .. "' not installed — run :DevdocsUpdate " .. name,
      vim.log.levels.WARN)
    return
  end
  local dest = vim.fn.expand(dirs[1]) .. "/" .. name
  if vim.fn.filereadable(dest .. "/index.json") == 1 then
    vim.notify("devdocs: manual already exists at " .. dest, vim.log.levels.WARN)
    return
  end
  vim.fn.mkdir(dest, "p")
  local out = vim.fn.system({ "sh", "-c",
    ("cp %s/index.json %s/ && cp -r %s/pages-md %s/")
      :format(vim.fn.shellescape(src), vim.fn.shellescape(dest),
        vim.fn.shellescape(src), vim.fn.shellescape(dest)) })
  if vim.v.shell_error ~= 0 then
    vim.notify("devdocs: adopt failed — " .. vim.trim(out), vim.log.levels.ERROR)
    return
  end
  M.invalidate(name)
  vim.notify(("devdocs: %s adopted into %s — refine it, then make it a repo/submodule; "
    .. "pages are now read from there"):format(name, dest), vim.log.levels.INFO)
end

return M
