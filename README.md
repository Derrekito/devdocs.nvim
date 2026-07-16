# devdocs.nvim

Offline reference documentation in Neovim, done right.

Docsets come from [devdocs.io](https://devdocs.io). Pages are converted to
**real markdown once at install time** by a converter that understands the
structures generic HTML→markdown tools mangle (see
[Language support](#language-support) for what that means per docset).
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
| `:Devdocs` | Fuzzy-browse every installed docset (with page preview) |
| `:Devdocs <query>` | Browse, pre-filtered |
| `:Devdocs <docset> [query]` | Browse one docset |
| `:DevdocsExamples [docset] [query]` | Browse code examples from the notes (see below) |
| `:DevdocsUpdate [docset]` | Download + convert (runs in the background) |
| `:DevdocsAdopt <docset>` | Copy an installed docset into `manuals/` to own and refine it |

Inside a doc page, press `<C-h>` (or `g?`) for the built-in help screen.
Paging and search use Neovim's native keys — same letters as `less`, just
Ctrl-chorded — so normal editor motions stay untouched:

| Key | Action |
|---|---|
| `<C-f>` / `<C-b>` | Page forward / back |
| `<C-d>` / `<C-u>` | Half page forward / back |
| `K` / `<C-]>` / `gK` | Follow the reference under the cursor (same docset, replaces in-window) |
| `]c` / `[c` | Jump to the next / previous code block |
| `gy` | Yank the code block under the cursor (unnamed register + clipboard) |
| `<C-T>` | Back to the previous page |
| `gO` | Section TOC (man viewer) |
| `<C-h>` / `g?` | Help screen |
| `q` / `:q` | Back out one page; closes the window only at the top of the stack |
| `Q` / `:q!` | Close the page window immediately |

Following references (`K`/`gK`/`<C-]>`) inside a page is a **nested
lookup**: each followed entry stacks on the previous one, and each
`q`/`:q` unwinds one level — you land back on the entry you came from,
and only quitting the last page closes the window.

`]c`/`[c`/`gy` work in both viewers — the man viewer remembers where each
fenced block landed after typesetting, and `gy` always yanks the original
source, never troff indentation.

`gK` resolves what's under the cursor in stages: LSP-derived candidates
first (the language server knows a variable's type and a member's qualified
name), each validated against the docset index, then the literal word
(qualified names as-is, bare names via the docset's `prefixes` and the
`name()` form), and finally the search picker pre-filled. Per-language
resolution details live in [Language support](#language-support).

## Viewers

Two page styles, switched by the `viewer` option:

- **`"markdown"`** (default) — the pre-converted markdown (prose wrapped at
  `width` columns) in a scratch buffer. Code fences get treesitter
  highlighting, and markdown renderers
  ([render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim),
  markview, …) apply their full treatment: bordered code blocks, styled
  headings, decorated lists.
- **`"man"`** — the page converted to a man page on the fly (`pandoc`
  required) and displayed through Neovim's `:Man` machinery: troff
  typesetting, bold/underline rendering, `gO` section TOC. Falls back to
  markdown automatically if `pandoc`/`man` are unavailable.

## Language support

The pipeline (download → structure-aware conversion → index → viewers →
notes) is docset-generic. What differs per language: which HTML structures
the converter understands, how `gK` resolves symbols, and index naming
conventions. Each docset's specifics aggregate here.

### C++ (`cpp`) and C (`c`)

- **Source**: current [cppreference](https://en.cppreference.com) — C++23
  included; the C docset is cppreference's C library.
- **Converter**: declaration tables → numbered ` ```cpp ` fences with
  `(since C++NN)` tags; revision tables → `*(since/until C++NN)*`
  annotations; numbered overload descriptions → one line each; parameter,
  member, and see-also tables → definition lists; examples → `cpp` + `text`
  fences.
- **`gK` with clangd**: variable → its type (`oss` →
  `std::basic_ostringstream`, typedefs chased via hover's `aka`); member →
  qualified name (cursor on `str` in `oss.str()` →
  `std::basic_ostringstream::str`); `auto` → its deduced type. Scope-stripped
  hover names are re-qualified by namespace-suffix matching (a hover saying
  just `directory_entry` resolves to `std::filesystem::directory_entry`).
- **Lookup conventions**: `std::` prefix tried for bare names; `:` joins
  qualified names under the cursor.

### Python (`python~3.14`)

- **Converter**: Sphinx definition lists → bolded terms with indented
  bodies.
- **Lookup conventions**: `.` joins dotted names under the cursor; the
  index's `name()` form is matched (`str.split` → `str.split()`).

### Lua (`lua~5.1`)

- **Single-page docset**: the whole manual is one page; entries anchor-jump
  to their section. Default is 5.1 to match Neovim/LuaJIT — switch the slug
  for 5.4.
- **Lookup conventions**: `.` joins dotted names; `string.format` →
  `string.format()`.

### Bash (`bash`)

- **Source**: the GNU Bash manual, split by topic; builtins like `declare`
  resolve through the index.

### CMake (`cmake`)

- **Converter**: Sphinx definition lists.
- **Lookup conventions**: command pages use the `name()` form
  (`add_library` → `add_library()`).

### Adding a language

Everything is config — no code:

```lua
docsets = {
  rust = { slug = "rust", lang = "rust" },  -- any slug from devdocs.io/docs.json
},
filetypes = { rust = "rust" },              -- gK in rust buffers
keyword_chars = { rust = ":" },             -- if qualified names need extra chars
```

Then `:DevdocsUpdate rust`. The converter's generic rules (headings,
paragraphs, lists, fences, definition lists, tables) cover most docsets;
`lang` sets the code-fence language for highlighting. Notes work
immediately at `notes/rust/…`. If a docset renders poorly, its HTML uses
structures the converter doesn't know yet — add a rule to
`scripts/convert.py` and document it in a new subsection here.

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

**Finding examples**: `:DevdocsExamples [docset] [query]` is a picker
over every fenced code example in the notes, titled
`page › nearest heading` and matched against the code itself — typing
`stable_sort` finds the example that uses it even if no heading mentions
it. `<CR>` opens the page positioned at that example; `<C-y>` yanks the
code straight from the picker without opening anything.

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

## Owning a manual

Downloaded docsets are a starting point, not a destination: cppreference
prose can be dense, and its structure isn't ours to change. To take
ownership of a docset's content:

1. `:DevdocsAdopt cpp` — copies the installed tree (`index.json` +
   `pages-md/`) into `manuals/cpp/`.
2. Make `manuals/cpp` its own git repository and add it back as a
   **submodule** — one content repo per language, so the plugin repo
   never becomes a monolith:

   ```bash
   cd manuals/cpp && git init && git add -A && git commit -m "Adopt cpp docset"
   # push it somewhere, then in the plugin repo:
   git submodule add <url> manuals/cpp
   ```

3. Refine pages in place — rewrite descriptions, restructure, delete
   noise. Reads prefer `manuals/<docset>` over the downloaded tree from
   then on (`:checkhealth devdocs` shows which source each docset uses),
   and `:DevdocsUpdate` keeps writing only to `data_dir`, so a future
   upstream refresh never touches your manual: adopt it into a scratch
   directory and diff when a new spec lands.

Notes still layer on top of manual pages exactly as they do on generated
ones, so annotation content survives an adoption unchanged.

**Licensing**: content derived from cppreference is CC-BY-SA — a
published manual repo needs attribution and the same license. Docsets
from other sources carry their own terms; check before publishing.

## Configuration (defaults shown)

```lua
require("devdocs").setup({
  data_dir = vim.fn.stdpath("data") .. "/devdocs",
  viewer = "markdown", -- or "man" (see Viewers above)
  width = 80,          -- column width: man-viewer typesetting AND markdown
                       -- prose wrapping (applied at :DevdocsUpdate time)
  split = "horizontal", -- "above"|"below"|"left"|"right" place relative to the
                        -- current window; "horizontal"|"vertical" obey
                        -- 'splitbelow'/'splitright'
  reuse_window = true,  -- one docs window per tab (opens from code adopt it);
                        -- false: new split per open, for side-by-side pages
  notes_dirs = { "<plugin>/notes" }, -- note sources; first entry is writable
  manual_dirs = { "<plugin>/manuals" }, -- owned-manual sources (see Owning a
                                        -- manual); first entry is where
                                        -- :DevdocsAdopt seeds new manuals
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

## Tests

```
make test               # plugin behavior (plenary)
make check-examples     # compile-check every code example in notes/
make check-examples-run # …also run full programs, diff ```text output
make check              # both
```

`check-examples` treats the notes as code under test: every fenced
example must compile (`g++ -std=c++17 -Wall -Wextra` for cpp; fragments
are wrapped in a main() that carries the context of earlier fences in
the file). Pin a fence to a standard with ` ```cpp c++20 `, or opt one
out with ` ```cpp skip `. With `--run`, a ` ```text ` fence directly
after a full program is asserted against its stdout.
