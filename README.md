# devdocs.nvim

Offline reference documentation in Neovim, done right.

Docsets come from [devdocs.io](https://devdocs.io) (cpp/c are current
[cppreference](https://en.cppreference.com) content — C++23 included). Pages
are converted to **real markdown once at install time** by a converter that
understands the structures generic HTML→markdown tools mangle:

- cppreference declaration tables → numbered ` ```cpp ` fences
- revision tables → `*(since/until C++NN)*` annotations
- numbered overload descriptions → one line each, inline code backticked
- parameter/member tables → `- **name** — description` lists
- examples → fenced code blocks your treesitter highlights
- Sphinx definition lists (python, cmake) → bolded terms with indented bodies

Opening a page is just reading a pre-converted `.md` into a scratch buffer:
no HTML, no subprocess, no pager at view time.

## Requirements

- `curl`, `python` with `beautifulsoup4` + `lxml` (conversion only)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

```lua
-- lazy.nvim
{
  "Derrekito/devdocs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  opts = {},
}
```

Then download the docsets you want:

```
:DevdocsUpdate          " all configured docsets
:DevdocsUpdate cpp      " just one
```

## Usage

| Mapping/Command | Action |
|---|---|
| `gK` (in mapped filetypes) | Look up the symbol under the cursor (exact match, falls back to search) |
| `:Devdocs` | Fuzzy-browse every installed docset |
| `:Devdocs <query>` | Browse, pre-filtered |
| `:Devdocs <docset> [query]` | Browse one docset |
| `:DevdocsUpdate [docset]` | Download + convert |
| `q` (in a doc page) | Close the page |

`gK` is LSP-aware when a language server is attached: on a **variable** it
resolves the variable's type (`oss` → `std::basic_ostringstream`, via hover's
`Type: … (aka basic_ostringstream<char>)`), and on a **member** it resolves
the qualified name (`oss.str()` with the cursor on `str` →
`std::basic_ostringstream::str`, via clangd's `textDocument/symbolInfo`).
Candidates are validated against the docset index, falling back to the word
under the cursor: qualified names work as-is (`std::vector`), bare names try
the docset's prefixes (`vector` → `std::vector`) and the `name()` form
(`string.format`, `add_library`) before opening the search picker.

## Configuration (defaults shown)

```lua
require("devdocs").setup({
  data_dir = vim.fn.stdpath("data") .. "/devdocs",
  docsets = {
    cpp    = { slug = "cpp",         lang = "cpp", prefixes = { "std::" } },
    c      = { slug = "c",           lang = "c" },
    lua    = { slug = "lua~5.1",     lang = "lua" },
    bash   = { slug = "bash",        lang = "bash" },
    cmake  = { slug = "cmake",       lang = "cmake" },
    python = { slug = "python~3.14", lang = "python" },
  },
  filetypes = {
    cpp = "cpp", c = "c", lua = "lua", python = "python", cmake = "cmake",
    sh = "bash", bash = "bash", zsh = "bash",
  },
  keyword_chars = { cpp = ":", lua = ".", python = "." },
})
```

Add any docset from [devdocs.io/docs.json](https://devdocs.io/docs.json) by
slug — e.g. `rust = { slug = "rust", lang = "rust" }` plus a `filetypes`
entry.

## Tests

```
make test
```
