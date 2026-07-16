# Shipped notes

Markdown files in this tree extend the generated docsets at view time.
Generated pages are never edited — `:DevdocsUpdate` rebuilds them
wholesale — so all curated additions live here and survive updates and
reinstalls by construction.

## Layout

One subdirectory per docset, mirroring the docset's page structure. The
same scheme works for every docset configured in `setup()` — including
ones you add yourself:

- `<docset>/<page-path>.md` — **annotation**: appended to that generated
  page in both viewers. Find a page's path in the buffer name
  (`devdocs://cpp/…` maps to the entry's index path) or just use
  `:DevdocsNote` from the page, which computes it for you.
- `<docset>/<any-other-path>.md` — **custom page**: gets its own index
  entry named by its first `# heading`, searchable via `:Devdocs`
  (tagged `[notes]`) and reachable by exact-name `gK`. Use a
  subdirectory like `guides/` to keep custom pages from colliding with
  future upstream paths.

## Conventions

- Annotations start with an `### Heading` (h3 maps to a proper man
  `.SH`); never `#`/`##`, which collide with page structure.
- Custom pages start with a `# Page Name` heading — that is their index
  name.
- Code examples go in fenced blocks with a language (` ```cpp `,
  ` ```cmake `, …) so both viewers highlight them. Expected output goes
  in ` ```text ` fences (output fences are excluded from the
  `:DevdocsExamples` index).
- Every fenced example is indexed by `:DevdocsExamples` under its
  nearest heading, so write headings that describe the task ("Sort
  structs by a member"), not the API ("Overload (3)") — the heading is
  what people fuzzy-search for.
- Write task-oriented content ("how do I list a directory"), not API
  re-description — the reference part of the page already does that.

- State the language standard when it matters: name the version in
  prose or the heading when a feature is version-gated ("`std::clamp`
  is C++17"), and pin fences that need a newer standard than the
  default with ` ```cpp c++20 ` so the checker compiles them with it.

## Quality bar for shipped notes

- Every code example must compile — enforced by `make check-examples`
  (`g++ -std=c++17 -Wall -Wextra` for cpp; fragments get earlier fences'
  context, see `scripts/check_examples.py`). Run it before committing.
  ` ```cpp skip ` opts a fence out; use it sparingly and only for
  intentionally illustrative non-code.
- Verify the merged page renders in both viewers (`viewer = "man"` and
  `"markdown"`) before committing.

## Authoring workflow

Open any page, run `:DevdocsNote`, write, save — the next view of the
page shows the merged result. Personal (non-shipped) note directories
can be added via `setup({ notes_dirs = { ... } })`; the **first**
directory in the list is where `:DevdocsNote` creates new files, so put
a personal directory first if you don't want to write into the plugin
checkout.
