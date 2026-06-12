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
- `pandoc` + `man` (only for `viewer = "man"`)

Run `:checkhealth devdocs` to verify everything, including which docsets are
installed.

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

Inside a doc page, press `<C-h>` (or `g?`) for the built-in help screen.
Paging and search use Neovim's native keys — same letters as `less`, just
Ctrl-chorded — so normal editor motions stay untouched:

| Key | Action |
|---|---|
| `<C-f>` / `<C-b>` | Page forward / back |
| `<C-d>` / `<C-u>` | Half page forward / back |
| `K` / `<C-]>` / `gK` | Follow the reference under the cursor (same docset, replaces in-window) |
| `<C-T>` | Back to the previous page |
| `gO` | Section TOC (man viewer) |
| `<C-h>` / `g?` | Help screen |
| `q` | Close the page window |

`gK` is LSP-aware when a language server is attached: on a **variable** it
resolves the variable's type (`oss` → `std::basic_ostringstream`, via hover's
`Type: … (aka basic_ostringstream<char>)`), and on a **member** it resolves
the qualified name (`oss.str()` with the cursor on `str` →
`std::basic_ostringstream::str`, via clangd's `textDocument/symbolInfo`).
Candidates are validated against the docset index, falling back to the word
under the cursor: qualified names work as-is (`std::vector`), bare names try
the docset's prefixes (`vector` → `std::vector`) and the `name()` form
(`string.format`, `add_library`) before opening the search picker.

## Viewers

Two page styles, switched by the `viewer` option:

- **`"markdown"`** (default) — the pre-converted markdown in a scratch
  buffer. Code fences get treesitter highlighting, and markdown renderers
  ([render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim),
  markview, …) apply their full treatment: bordered code blocks, styled
  headings, decorated lists.
- **`"man"`** — the page converted to a man page on the fly (`pandoc`
  required) and displayed through Neovim's `:Man` machinery: troff
  typesetting, bold/underline rendering, `gO` section TOC. Falls back to
  markdown automatically if `pandoc`/`man` are unavailable.

## Notes: extending and adding pages

Upstream reference pages are sometimes thin on *how to actually use*
things. Notes fix that — for **any docset** — without ever touching
generated files (which `:DevdocsUpdate` rebuilds wholesale). A note is a
plain markdown file whose location decides what it does:

```
notes/
├── cpp/
│   ├── filesystem/directory_iterator.md   annotation: appended to the
│   │                                      std::filesystem::directory_iterator page
│   └── guides/error-handling.md           custom page: "# Error handling patterns"
├── cmake/
│   └── command/add_library.md             annotation: extends add_library()
└── python/
    └── guides/venv-quickstart.md          custom page, searchable via :Devdocs
```

- **Annotation** — a file mirroring a generated page's path. Appended to
  that page in both viewers; fenced code examples get full treesitter
  highlighting, man mode included.
- **Custom page** — any other path. Indexed by its first `# heading`,
  searchable via `:Devdocs` (tagged `[notes]`), reachable by exact-name
  `gK`.

The same layout works for every docset in your config — add a `rust`
docset and `notes/rust/…` works immediately, nothing else to wire up.

**Authoring workflow**: open a page, run `:DevdocsNote`, write, save —
the next view shows the merged result. Conventions and the quality bar
for shipped notes live in [`notes/README.md`](notes/README.md).

**Sources are layered**: `notes_dirs` is a list. Curated notes ship with
the plugin in `notes/`; append personal directories via
`setup({ notes_dirs = { ... } })` (the first entry is where `:DevdocsNote`
creates files — put your own directory first if you don't want to write
into the plugin checkout). All sources that have a file for a page are
appended in list order. Notes survive docset updates and reinstalls by
construction.

## Configuration (defaults shown)

```lua
require("devdocs").setup({
  data_dir = vim.fn.stdpath("data") .. "/devdocs",
  viewer = "markdown", -- or "man" (see Viewers above)
  width = 80,          -- man-viewer typeset width (clamped to the window)
  split = "horizontal", -- "above"|"below"|"left"|"right" place relative to the
                        -- current window; "horizontal"|"vertical" obey
                        -- 'splitbelow'/'splitright'
  reuse_window = true,  -- one docs window per tab (opens from code adopt it);
                        -- false: new split per open, for side-by-side pages
  notes_dirs = { "<plugin>/notes" }, -- note sources; first entry is writable
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
