-- devdocs.nvim — offline reference docs from devdocs.io, converted to real
-- markdown at install time by scripts/convert.py (purpose-built for the
-- structures generic converters mangle: cppreference declaration/revision
-- tables, Sphinx definition lists, …).
--
-- :Devdocs                  — fuzzy-browse every installed docset
-- :Devdocs <query>          — browse, pre-filtered
-- :Devdocs <docset> [query] — browse one docset
-- :DevdocsUpdate [docset]   — download + convert one docset (default: all)
-- gK (mapped filetypes)     — exact lookup of the symbol under the cursor
--
-- Module layout:
--   devdocs       (this file) config, setup, entry points (open/search/cmd)
--   devdocs.data  index loading, install state, download/convert pipeline
--   devdocs.view  markdown + man viewers, pager keys/history/help, code hl
--   devdocs.lsp   LSP candidate resolution for gK

local M = {}

M.config = {
  data_dir = vim.fn.stdpath("data") .. "/devdocs",
  -- "markdown": pre-converted .md in a scratch buffer (treesitter-highlighted
  --             fences; renderers like render-markdown.nvim apply).
  -- "man":      page converted to a man page on the fly (pandoc) and shown
  --             through nvim's :Man machinery (troff typesetting, gO TOC).
  --             Falls back to markdown if pandoc/man are unavailable.
  viewer = "markdown",
  -- Column width: the man viewer typesets at it (clamped to the window) and
  -- the converter wraps markdown prose to it at :DevdocsUpdate time (code
  -- fences, tables, and headings are never wrapped).
  width = 80,
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

local data = require("devdocs.data")
local view = require("devdocs.view")
local lsp = require("devdocs.lsp")
local notes = require("devdocs.notes")

-- Note sources: directories whose files extend pages (same relative path) or
-- add custom ones (any other path). Curated content ships inside the plugin;
-- append your own directories via setup().
M.config.notes_dirs = { data.plugin_root() .. "/notes" }

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  data.invalidate() -- data_dir/docsets may have changed
end

-- ── public API (stable surface; internals live in the submodules) ───────────

M.installed = data.installed
M.update = data.update

-- Exact lookup (index, then custom notes pages); falls back to the picker
-- pre-filtered with the word.
function M.open(word, docset)
  if not data.load_index(docset) then
    vim.notify("devdocs: docset '" .. docset .. "' not installed — run :DevdocsUpdate " .. docset,
      vim.log.levels.WARN)
    return
  end
  local entry = data.find_entry(docset, word)
  if not entry then
    local c = notes.find_custom(docset, word)
    if c then entry = { name = c.name, path = c.file } end
  end
  if entry then
    view.show(docset, entry.name, entry.path)
  else
    M.search(word, docset)
  end
end

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
    local idx = data.load_index(name)
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
  -- custom notes pages, tagged so their provenance is visible
  for _, e in ipairs(notes.custom_entries()) do
    if not docset or e.docset == docset then
      table.insert(items, {
        docset = e.docset,
        entry = { name = e.name, path = e.file },
        label = (tag and ("[" .. e.docset .. "] ") or "") .. e.name .. "  [notes]",
      })
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
        if sel then view.show(sel.value.docset, sel.value.entry.name, sel.value.entry.path) end
      end)
      return true
    end,
  }):find()
end

-- :Devdocs [docset] [query...]
function M.cmd(fargs)
  local docset = nil
  if fargs[1] and M.config.docsets[fargs[1]] then
    docset = table.remove(fargs, 1)
  end
  M.search(table.concat(fargs, " "), docset)
end

-- :DevdocsNote — open (creating if needed) the annotation file for the doc
-- page in the current window; for a custom notes page, edit its source.
function M.note()
  local page = vim.b.devdocs
  if not page then
    vim.notify("devdocs: :DevdocsNote works inside a doc page", vim.log.levels.WARN)
    return
  end
  if page.path:sub(1, 1) == "/" then
    vim.cmd.vsplit(page.path)
    return
  end
  local f = notes.note_file(page.docset, page.path)
  if not f then
    vim.notify("devdocs: no notes_dirs configured", vim.log.levels.WARN)
    return
  end
  local new = vim.fn.filereadable(f) == 0
  vim.fn.mkdir(vim.fn.fnamemodify(f, ":h"), "p")
  vim.cmd.vsplit(f)
  if new then
    -- seed with an h3 heading: the man converter turns ### into a proper .SH
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "### Notes", "", "" })
  end
end

-- gK handler: LSP-resolved candidates first (validated against the index),
-- then the (possibly qualified) word under the cursor.
function M.lookup_cword()
  local docset = M.config.filetypes[vim.bo.filetype]
  if not docset then return end
  local word = view.capture_word(docset)

  lsp.candidates(vim.api.nvim_get_current_buf(), function(candidates)
    for _, c in ipairs(candidates) do
      -- exact first; then namespace-suffix matching, since clangd hover
      -- prints types as visible from the cursor's scope (often unqualified)
      local e = data.find_entry(docset, c) or data.find_entry_suffix(docset, c)
      if e then
        view.show(docset, e.name, e.path)
        return
      end
    end
    if word ~= "" then M.open(word, docset) end
  end)
end

-- ── internals re-exported for tests ──────────────────────────────────────────

M._find_entry = data.find_entry
M._normalize_type = lsp.normalize_type
M._hover_candidates = lsp.hover_candidates
M._symbol_candidates = lsp.symbol_candidates
M._lsp_candidates = lsp.candidates

return M
