#!/usr/bin/env python3
"""Replace a document's GENERATED region with freshly generated text.

    splice_generated.py <document> <generated-text>

`agreements.md` is half narrative and half registry dump: §2 and §3 come
from `canary checks --catalogue --md`, everything else is written by
hand. Rather than keep them in two files, the generated half lives
between two markers and this script swaps it.

WHY A SCRIPT AND NOT A MAKEFILE ONE-LINER (2026-09-17). The first
version was an inline `python3 -c`, and it could destroy the document it
was editing:

  * it matched the markers with a plain substring search, so any PROSE
    that quoted a marker — and the document explains its own markers to
    the reader — was a candidate match earlier in the file. A match
    there splices from the middle of the narrative and deletes
    everything to the real end marker;
  * it wrote the result in the same expression that computed it, so a
    half-formed splice reached the disk before anything could object.

Both are fixed here, and the fixes are the point of the file:

  * markers must be ALONE ON THEIR LINE. Prose mentions them inline,
    inside backticks, mid-sentence — never as a whole line — so a line
    test cannot confuse the two;
  * the result is CHECKED before it is written. Both markers must
    survive, in order, and the document must still be longer than the
    text spliced into it. A splice that loses a marker is refused with
    the document untouched, because the next run would have nothing to
    find.
"""

import sys

BEGIN = "<!-- BEGIN GENERATED"
END = "<!-- END GENERATED -->"


def marker_line(lines, prefix):
    """Index of the one line that IS this marker, not one that mentions it."""
    hits = [i for i, l in enumerate(lines) if l.strip().startswith(prefix)]
    if len(hits) != 1:
        sys.exit(
            "splice: expected exactly one line starting with %r, found %d"
            % (prefix, len(hits))
        )
    return hits[0]


def main(doc_path, gen_path):
    doc = open(doc_path, encoding="utf-8").read().split("\n")
    generated = open(gen_path, encoding="utf-8").read().strip()

    if not generated:
        sys.exit("splice: generated text is empty — refusing to blank the region")

    begin = marker_line(doc, BEGIN)
    end = marker_line(doc, END)
    if end <= begin:
        sys.exit("splice: END marker precedes BEGIN marker")

    # The BEGIN marker may be a multi-line comment; keep all of it.
    close = begin
    while close < end and "-->" not in doc[close]:
        close += 1
    if close >= end:
        sys.exit("splice: BEGIN marker comment is never closed")

    out = doc[: close + 1] + ["", generated, ""] + doc[end:]
    text = "\n".join(out)

    # Refuse to write a result the next run could not splice again.
    after = text.split("\n")
    if len(
        [l for l in after if l.strip().startswith(BEGIN)]
    ) != 1 or len([l for l in after if l.strip().startswith(END)]) != 1:
        sys.exit("splice: the result would not carry exactly one of each marker")

    open(doc_path, "w", encoding="utf-8").write(text)
    print(
        "spliced %d generated lines into %s"
        % (len(generated.split("\n")), doc_path)
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
