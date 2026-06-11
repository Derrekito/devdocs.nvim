#!/usr/bin/env python
"""Convert devdocs.io docset HTML pages into readable markdown.

Generic HTML->markdown converters mangle reference documentation; this script
emits purpose-built markdown for the structures that matter.

cppreference (cpp/c docsets) uses a small fixed vocabulary of table/div
classes, each handled specifically:

  table.t-dcl-begin   -> ``` fence, one declaration per row, numbered
  table.t-rev-begin   -> content followed by *(since/until C++NN)* line
  table.t-par-begin   -> "- **name** — description" list
  table.t-dsc-begin   -> "- **term** — description" list
  table.t-sdsc-begin  -> fenced syntax block
  div.t-li1 / t-li2   -> "N) ..." overload description lines
  div.cpp.source-*    -> ``` fence;  div.text.source-* -> ```text fence

Sphinx-style docs (python, cmake) lean on <dl> definition lists, handled as
bolded terms with indented bodies. Everything else (headings, paragraphs,
lists, <pre>) converts generically.

devdocs flattens some of cppreference's block markup (numbered overload
descriptions become bare inline spans), so block rendering coalesces inline
runs into paragraphs and span.t-li markers carry a sentinel that becomes a
line break.

Usage:
  convert.py <root> [--lang=cpp]          convert root/pages/**.html -> root/pages-md/**.md
  convert.py <root> <page> [--lang=cpp]   convert one page to stdout (debugging)

--lang sets the default fence language for code blocks.
"""

import re
import sys
import pathlib
from bs4 import BeautifulSoup
from bs4.element import NavigableString, Tag

BREAK = "\x00"  # sentinel: forced line break inside a coalesced paragraph
LANG = "cpp"    # default fence language; overridden by --lang=

INLINE_TAGS = {
    "span", "code", "a", "b", "strong", "i", "em", "sub", "sup",
    "small", "u", "abbr", "kbd", "tt", "var", "s", "del", "ins",
}

# ── inline rendering ─────────────────────────────────────────────────────────

def classes(el) -> list[str]:
    cls = el.get("class")
    return list(cls) if cls else []


def inline(el) -> str:
    """Flatten an element's inline content to markdown text."""
    parts = []
    for c in el.children:
        if isinstance(c, NavigableString):
            parts.append(str(c))
            continue
        if not isinstance(c, Tag):
            continue
        if c.name == "code":
            parts.append("`" + re.sub(r"\s+", " ", c.get_text()).strip() + "`")
        elif c.name == "br":
            parts.append(BREAK)
        elif c.name == "span" and "t-li" in classes(c):
            # numbered overload marker: force a break before it
            parts.append(BREAK + re.sub(r"\s+", " ", c.get_text()).strip() + " ")
        elif c.name in ("b", "strong"):
            inner = squash(inline(c))
            parts.append("**" + inner + "**" if inner else "")
        elif c.name in ("i", "em"):
            inner = squash(inline(c))
            parts.append("*" + inner + "*" if inner else "")
        else:
            parts.append(inline(c))
    return "".join(parts)


def squash(text: str) -> str:
    """Collapse whitespace runs; drop break sentinels."""
    return re.sub(r"\s+", " ", text.replace(BREAK, " ")).strip()


def para_lines(text: str) -> list[str]:
    """Inline text -> paragraph lines, honoring break sentinels."""
    out = []
    for chunk in text.split(BREAK):
        chunk = re.sub(r"\s+", " ", chunk).strip()
        if chunk:
            out.append(chunk)
    return out

# ── block rendering ──────────────────────────────────────────────────────────

def code_fence(text: str, lang: str | None = None) -> list[str]:
    lang = lang or LANG
    lines = [l.rstrip() for l in text.strip("\n").splitlines()]
    indents = [len(l) - len(l.lstrip()) for l in lines if l.strip()]
    cut = min(indents) if indents else 0
    return ["```" + lang, *[l[cut:] for l in lines], "```", ""]


def dcl_table(table) -> list[str]:
    """Declaration table: one signature per row + number + version tag."""
    decls = []
    for tr in table.find_all("tr"):
        tds = tr.find_all("td", recursive=False)
        if not tds:
            continue
        decl = tds[0].get_text().strip()
        if not decl:
            continue
        num = squash(tds[1].get_text()) if len(tds) > 1 else ""
        ver = squash(tds[2].get_text()) if len(tds) > 2 else ""
        tag = " ".join(x for x in (num, ver) if x)
        decls.append(decl + ("  // " + tag if tag else ""))
    return code_fence("\n".join(decls)) if decls else []


def rev_table(table) -> list[str]:
    """Revision table: block content + version applicability tag."""
    out = []
    for tr in table.find_all("tr", class_="t-rev"):
        tds = tr.find_all("td", recursive=False)
        if not tds:
            continue
        out.extend(l for l in blocks(tds[0]) if l.strip() != "")
        ver = squash(tds[1].get_text()) if len(tds) > 1 else ""
        if ver:
            out.append("*" + ver + "*")
        out.append("")
    return out


def term_desc_table(table) -> list[str]:
    """Parameter / description tables -> '- **term** — description'."""
    out = []
    for tr in table.find_all("tr"):
        tds = tr.find_all("td", recursive=False)
        if len(tds) == 0:
            continue  # header row (th only)
        if len(tds) == 1:
            heading = squash(inline(tds[0]))
            if heading:
                out.extend(["", "**" + heading + "**", ""])
            continue
        term = squash(inline(tds[0]))
        desc = squash(inline(tds[-1]))
        if not term and not desc:
            continue
        if term and desc:
            out.append("- **" + term + "** — " + desc)
        elif desc:
            out.append("- " + desc)
        else:
            out.append("- **" + term + "**")
    out.append("")
    return out


def sdsc_table(table) -> list[str]:
    """Syntax-description table -> fenced syntax block."""
    rows = []
    for tr in table.find_all("tr"):
        cells = [squash(td.get_text()) for td in tr.find_all("td")]
        line = "    ".join(c for c in cells if c)
        if line:
            rows.append(line)
    return code_fence("\n".join(rows), lang="text") if rows else []


def generic_table(table) -> list[str]:
    """Fallback: each row as 'cell | cell | ...' text."""
    out = []
    for tr in table.find_all("tr"):
        cells = [squash(inline(c)) for c in tr.find_all(["td", "th"])]
        cells = [c for c in cells if c]
        if cells:
            out.append("  " + " | ".join(cells))
    out.append("")
    return out


def table_block(t) -> list[str]:
    cls = classes(t)
    if "t-dcl-begin" in cls:
        return dcl_table(t)
    if "t-rev-begin" in cls:
        return rev_table(t)
    if "t-par-begin" in cls or "t-dsc-begin" in cls:
        return term_desc_table(t)
    if "t-sdsc-begin" in cls:
        return sdsc_table(t)
    if "eq-fun-cpp-table" in cls:
        out = []
        for pre in t.find_all("pre"):
            out.extend(code_fence(pre.get_text()))
        return out or generic_table(t)
    return generic_table(t)


def blocks(el) -> list[str]:
    """Render an element's children, coalescing inline runs into paragraphs."""
    out: list[str] = []
    buf: list[str] = []

    def flush():
        if buf:
            out.extend(para_lines("".join(buf)))
            out.append("")
            buf.clear()

    for c in el.children:
        if isinstance(c, NavigableString):
            buf.append(str(c))
            continue
        if not isinstance(c, Tag):
            continue
        name = c.name
        cls = classes(c)

        if name in INLINE_TAGS or name == "br":
            buf.append(BREAK if name == "br" else inline_one(c))
            continue

        flush()

        if name in ("h1", "h2", "h3", "h4", "h5"):
            out.extend(["#" * int(name[1]) + " " + squash(inline(c)), ""])
        elif name == "p":
            out.extend(para_lines(inline(c)))
            out.append("")
        elif name in ("ul", "ol"):
            marker = "-" if name == "ul" else "1."
            for li in c.find_all("li", recursive=False):
                out.append(marker + " " + squash(inline(li)))
            out.append("")
        elif name == "pre":
            out.extend(code_fence(c.get_text()))
        elif name == "table":
            out.extend(table_block(c))
        elif name == "dl":
            # Sphinx-style definition list: bold term, indented body
            for child in c.find_all(["dt", "dd"], recursive=False):
                if child.name == "dt":
                    term = squash(inline(child))
                    if term:
                        out.append("**" + term + "**")
                else:
                    for l in blocks(child):
                        out.append(("  " + l) if l.strip() else l)
            out.append("")
        elif name == "div":
            if "t-li1" in cls or "t-li2" in cls:
                indent = "   " if "t-li2" in cls else ""
                out.append(indent + squash(inline(c)))
            elif "source-cpp" in cls or ("cpp" in cls and c.find("pre")):
                out.extend(code_fence(c.get_text()))
            elif "source-text" in cls or ("text" in cls and c.find("pre")):
                out.extend(code_fence(c.get_text(), lang="text"))
            elif "_attribution" in cls:
                link = c.find("a")
                src = str(link.get("href") or "") if isinstance(link, Tag) else ""
                out.extend(["---", "*Source: " + src + "*" if src
                            else "*" + squash(c.get_text()) + "*"])
            elif "t-inheritance-diagram" in cls:
                continue
            else:
                out.extend(blocks(c))  # transparent wrapper (t-example, t-member, …)
        else:
            out.extend(blocks(c))

    flush()
    return out


def inline_one(c) -> str:
    """Render a single inline tag (shares rules with inline())."""
    if c.name == "code":
        return "`" + re.sub(r"\s+", " ", c.get_text()).strip() + "`"
    if c.name == "span" and "t-li" in classes(c):
        return BREAK + re.sub(r"\s+", " ", c.get_text()).strip() + " "
    if c.name in ("b", "strong"):
        inner = squash(inline(c))
        return "**" + inner + "**" if inner else ""
    if c.name in ("i", "em"):
        inner = squash(inline(c))
        return "*" + inner + "*" if inner else ""
    return inline(c)

# ── driver ───────────────────────────────────────────────────────────────────

def convert(html: str) -> str:
    soup = BeautifulSoup(html, "lxml")
    root = soup.body or soup
    text = "\n".join(blocks(root))
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def main():
    global LANG
    args = []
    for a in sys.argv[1:]:
        if a.startswith("--lang="):
            LANG = a.split("=", 1)[1]
        else:
            args.append(a)

    root = pathlib.Path(args[0]).expanduser()
    src = root / "pages"
    if len(args) > 1:  # single page to stdout
        print(convert((src / (args[1] + ".html")).read_text()))
        return
    dst = root / "pages-md"
    n, failed = 0, 0
    for f in src.rglob("*.html"):
        rel = f.relative_to(src).with_suffix(".md")
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        try:
            out.write_text(convert(f.read_text()))
            n += 1
        except Exception as e:
            failed += 1
            print(f"FAIL {rel}: {e}", file=sys.stderr)
    print(f"converted: {n} failed: {failed}")


if __name__ == "__main__":
    main()
