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

vim.api.nvim_create_user_command("DevdocsNote", function()
  require("devdocs").note()
end, { desc = "Annotate the current devdocs page" })

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
