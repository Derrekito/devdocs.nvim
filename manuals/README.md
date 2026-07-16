# Owned manuals

`<docset-name>/` trees here (each with `index.json` + `pages-md/`) take
precedence over docsets downloaded to `data_dir` — this is where the
project stops mirroring upstream references and starts maintaining its
own, one **git submodule per language** so no single repo becomes a
monolith.

Workflow:

1. `:DevdocsUpdate cpp` then `:DevdocsAdopt cpp` — seeds `manuals/cpp/`
   from the installed docset.
2. Turn `manuals/cpp` into its own repository and add it back as a
   submodule (see "Owning a manual" in the top-level README).
3. Refine pages in place. `:checkhealth devdocs` shows which source each
   docset resolves to.

Notes (`notes/<docset>/…`) still layer on top of manual pages exactly as
they do on generated ones.

**Licensing**: manuals seeded from cppreference content are CC-BY-SA
derivatives — keep attribution and the license if you publish the repo.
