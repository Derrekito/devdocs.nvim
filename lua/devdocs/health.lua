-- :checkhealth devdocs — verify external tools, python modules, and docsets.

local M = {}

function M.check()
  local health = vim.health
  local config = require("devdocs").config

  health.start("devdocs.nvim")

  -- required tools
  for _, t in ipairs({
    { bin = "curl",   why = "downloading docsets (:DevdocsUpdate)" },
    { bin = "python", why = "splitting and converting docsets" },
  }) do
    if vim.fn.executable(t.bin) == 1 then
      health.ok(t.bin .. " found")
    else
      health.error(t.bin .. " not found — needed for " .. t.why)
    end
  end

  -- python modules used by scripts/convert.py
  vim.fn.system({ "python", "-c", "import bs4, lxml" })
  if vim.v.shell_error == 0 then
    health.ok("python modules bs4 + lxml found")
  else
    health.error("python modules bs4/lxml missing — scripts/convert.py needs both",
      { "pip install beautifulsoup4 lxml (or your distro's packages)" })
  end

  -- telescope (search/browse UI)
  if pcall(require, "telescope") then
    health.ok("telescope.nvim found")
  else
    health.error("telescope.nvim not found — :Devdocs and search fallback need it")
  end

  -- man viewer dependencies, only relevant when configured
  health.start("viewer")
  if config.viewer == "man" then
    for _, bin in ipairs({ "pandoc", "man" }) do
      if vim.fn.executable(bin) == 1 then
        health.ok(bin .. " found")
      else
        health.warn(bin .. " not found — viewer = 'man' will fall back to markdown")
      end
    end
  elseif config.viewer == "markdown" then
    health.ok("viewer = 'markdown' (no extra tools needed)")
  else
    health.error(("viewer = %q is not valid — use 'markdown' or 'man'"):format(tostring(config.viewer)))
  end

  -- docsets on disk
  health.start("docsets")
  local devdocs = require("devdocs")
  local installed = devdocs.installed()
  if #installed == 0 then
    health.warn("no docsets installed — run :DevdocsUpdate")
  end
  for name, ds in vim.spairs(config.docsets) do
    local dir = config.data_dir .. "/" .. ds.slug
    if vim.fn.filereadable(dir .. "/index.json") == 1 then
      local pages = #vim.fn.glob(dir .. "/pages-md/**/*.md", false, true)
      if pages > 0 then
        health.ok(("%s (%s): %d pages converted"):format(name, ds.slug, pages))
      else
        health.warn(("%s (%s): index present but no converted pages — run :DevdocsUpdate %s")
          :format(name, ds.slug, name))
      end
    else
      health.warn(("%s (%s): not installed — run :DevdocsUpdate %s"):format(name, ds.slug, name))
    end
  end
end

return M
