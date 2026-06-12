#!/bin/sh
# Prototype: convert one pre-converted devdocs markdown page to a man page.
#
#   md2man.sh <page.md> <out.3> [title]
#
# Preprocessing before pandoc's gfm reader:
#   - drop the leading h1 (the .TH header already carries the title)
#   - isolate "N)" overload-description lines as their own paragraphs AND
#     escape the marker: pandoc would otherwise parse consecutive "N)" lines
#     as an ordered list and RENUMBER them, silently corrupting overload
#     references (9) became 7) in testing)
#   - shift headings so our "### Parameters" becomes a proper .SH
set -e

md=$1
out=$2
title=${3:-$(sed -n '1s/^# //p' "$md")}

sed -e '1{/^# /d}' -e 's/^\([0-9][0-9,-]*\))/\n\1\\)/' "$md" |
  pandoc -s -f gfm -t man \
    --shift-heading-level-by=-2 \
    --metadata title="$title" \
    --metadata section=3 \
    --metadata header="C++ Programmer's Manual" \
    -o "$out"
