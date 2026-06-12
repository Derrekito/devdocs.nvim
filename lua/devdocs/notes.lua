-- Notes: shippable content that extends or adds to the generated docsets.
-- Sources are directories listed in config.notes_dirs (default: the notes/
-- directory inside this plugin, so curated content ships with the repo; add
-- personal directories via setup()).
--
-- Inside each source, files mirror the docset layout:
--   <docset>/<page-path>.md   annotation — appended to that page in both
--                             viewers (full code-fence highlighting applies)
--   <docset>/<anything-else>.md
--                             custom page — indexed by its first '# heading'
--                             and searchable alongside upstream entries
--
-- Generated pages are never edited (updates rebuild them); notes survive
-- :DevdocsUpdate and reinstalls by construction.

local data = require("devdocs.data")

local M = {}

local function cfg()
  return require("devdocs").config
end

-- Resolved, expanded source directories.
function M.dirs()
  local out = {}
  for _, d in ipairs(cfg().notes_dirs or {}) do
    table.insert(out, (vim.fn.expand(d)))
  end
  return out
end

-- Annotation files that exist for a page, in source order.
function M.annotations(docset, path)
  local rel = docset .. "/" .. path:gsub("#.*$", "") .. ".md"
  local out = {}
  for _, d in ipairs(M.dirs()) do
    local f = d .. "/" .. rel
    if vim.fn.filereadable(f) == 1 then
      table.insert(out, f)
    end
  end
  return out
end

-- The annotation file to EDIT for a page: same relative location in the
-- first source directory.
function M.note_file(docset, path)
  local dirs = M.dirs()
  if #dirs == 0 then return nil end
  return dirs[1] .. "/" .. docset .. "/" .. path:gsub("#.*$", "") .. ".md"
end

-- Custom pages: notes files that do NOT mirror an existing generated page.
-- Returns { { docset, name, file } }; name comes from the first '# ' heading
-- (filename stem as fallback).
function M.custom_entries()
  local out = {}
  for _, d in ipairs(M.dirs()) do
    for name, _ in pairs(cfg().docsets) do
      local base = d .. "/" .. name
      for _, f in ipairs(vim.fn.glob(base .. "/**/*.md", false, true)) do
        local rel = f:sub(#base + 2):gsub("%.md$", "")
        local generated = data.root(name) .. "/pages-md/" .. rel .. ".md"
        if vim.fn.filereadable(generated) == 0 then
          local title
          for _, line in ipairs(vim.fn.readfile(f, "", 10)) do
            title = line:match("^#%s+(.+)")
            if title then break end
          end
          table.insert(out, {
            docset = name,
            name = title or vim.fn.fnamemodify(f, ":t:r"),
            file = f,
          })
        end
      end
    end
  end
  return out
end

-- Exact-name lookup among custom pages (used by open/gK).
function M.find_custom(docset, word)
  for _, e in ipairs(M.custom_entries()) do
    if e.docset == docset and e.name == word then
      return e
    end
  end
  return nil
end

return M
