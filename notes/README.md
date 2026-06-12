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
  in ` ```text ` fences.
- Write task-oriented content ("how do I list a directory"), not API
  re-description — the reference part of the page already does that.

## Quality bar for shipped notes

- Every code example must compile/run as shown (e.g.
  `g++ -std=c++17 -Wall -Wextra` for cpp notes) before committing.
- Verify the merged page renders in both viewers (`viewer = "man"` and
  `"markdown"`) before committing.

## Authoring workflow

Open any page, run `:DevdocsNote`, write, save — the next view of the
page shows the merged result. Personal (non-shipped) note directories
can be added via `setup({ notes_dirs = { ... } })`; the **first**
directory in the list is where `:DevdocsNote` creates new files, so put
a personal directory first if you don't want to write into the plugin
checkout.
