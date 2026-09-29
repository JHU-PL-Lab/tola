---
name: feedback-concise-comments
description: Code comments state the concluded design briefly (sections, terms, workflows); reasoning stays in chat, history in the worklog and commits
metadata:
  type: feedback
---

Comments state the concluded design, briefly — the sections, terms and workflows as they are now (user, 2026-09-29: "I don't think leaving too much reasoning comments are helpful. we can discuss in the chat and directly show the concluded sections, terms or workflows. It helps to reduce the size. the later agent can just follow.").

**Why:** the overview modules had grown to thousands of lines, about a third of them comments and half of those dated history (user quotes, what broke, how it landed). That bulk makes files too large for an agent to read whole and buries the conclusion under the argument that reached it.

**How to apply:** write a new comment as the conclusion in a few lines; put a dated story in the worklog or the commit message, not the code. When moving or changing existing code, shorten its long dated comments to what the code is now. This overrides "match the surrounding comment density" for this repo; the rule is also in CLAUDE.md's Conventions. Related: [[feedback-patient-with-new-actions]].
