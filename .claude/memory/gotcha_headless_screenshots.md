---
name: gotcha-headless-screenshots
description: On WSL, headless Chromium is a snap that writes only under home; how to screenshot a part of the overview page
metadata:
  type: user
---

`chromium-browser` on the WSL box is a snap: `--screenshot` into `/tmp`
or the session scratchpad silently writes nothing. Render into
`_out/shots/` (gitignored) instead.

A screenshot of the page at an `#anchor` comes out blank. To see one
part of the page, render the exported SVG or table from
`doc/canary/research/exhibits/`. Or write a copy of
`docs/canary/overview.html` into `_out/shots/` with a script before
`</body>` that clicks the panel's buttons and moves the element to the
top (`document.body.insertBefore(el, document.body.firstChild)`).
`--dump-dom` on such a copy checks what the page's script did.

The Bash tool runs bash, not the login shell (fish).
