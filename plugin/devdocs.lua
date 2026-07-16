-- Plugin entry point: user commands + gK mapping for configured filetypes.

if vim.g.loaded_devdocs then
  return
end
vim.g.loaded_devdocs = 1

local function docset_names(prefix)
  local names = vim.tbl_keys(require("devdocs").config.docsets)
  table.sort(names)
  return vim.tbl_filter(function(n) return vim.startswith(n, prefix) end, names)
end

vim.api.nvim_create_user_command("Devdocs", function(opts)
  require("devdocs").cmd(opts.fargs)
end, { nargs = "*", complete = docset_names, desc = "Browse/search devdocs docsets" })

vim.api.nvim_create_user_command("DevdocsUpdate", function(opts)
  require("devdocs").update(opts.fargs[1])
end, { nargs = "?", complete = docset_names, desc = "Download + convert devdocs docsets" })

vim.api.nvim_create_user_command("DevdocsAdopt", function(opts)
  require("devdocs").adopt(opts.fargs[1])
end, { nargs = 1, complete = docset_names,
  desc = "Copy an installed docset into manuals/ to own and refine it" })

vim.api.nvim_create_user_command("DevdocsNote", function()
  require("devdocs").note()
end, { desc = "Annotate the current devdocs page" })

vim.api.nvim_create_user_command("DevdocsExamples", function(opts)
  require("devdocs").examples(opts.fargs)
end, { nargs = "*", complete = docset_names, desc = "Browse code examples from devdocs notes" })

-- :q inside a doc page abbreviates to this (see view.map_page_keys): pop
-- back to the parent page, closing the window only at the top of the stack.
vim.api.nvim_create_user_command("DevdocsBack", function(opts)
  require("devdocs.view").back_or_close(opts.bang)
end, { bang = true, desc = "devdocs: previous page, or close the page window" })

-- Buffer-local gK in any filetype that maps to a docset. Checked at fire
-- time so setup() can run before or after this file is sourced.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("DevdocsKeymap", { clear = true }),
  callback = function(ev)
    local devdocs = require("devdocs")
    if not devdocs.config.filetypes[ev.match] then return end
    vim.keymap.set("n", "gK", devdocs.lookup_cword,
      { buffer = ev.buf, desc = "devdocs: lookup symbol under cursor" })
  end,
})
