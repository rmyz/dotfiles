---
name: generate-visual-plan
description: Generate an interactive visual implementation plan the reader can answer in place
---

Load the visual-explainer skill and make a visual implementation plan for: $@

Follow `references/plans.md`.

Research before you draw: entry points, affected modules, public APIs, data model and config, tests, similar features, and README/CHANGELOG constraints. Note exact `file:line` and the user's own words. Mark claims you could not confirm `evidence="guess"`; give each level-1 claim a `check`.

Render (in Pi, `viewer: "glimpse"` sends the response straight back), hand over with the page path and the open decisions, and wait. Do not build before the response arrives. After you build, set each claim's `status` and render again.
