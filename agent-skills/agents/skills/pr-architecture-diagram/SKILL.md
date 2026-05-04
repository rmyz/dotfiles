---
name: pr-architecture-diagram
description: Generate architecture diagrams for pull requests using Excalidraw MCP and attach them to the PR. Use when the user asks to create a diagram for a PR, visualize PR changes, draw architecture for a PR, or says "diagram this PR".
---

# PR Architecture Diagram

Generates Excalidraw architecture diagrams from PR diffs and embeds them in the PR description.

## Instructions

### Step 1: Get PR Context

Fetch the PR diff and understand the changes:

```bash
gh pr view <PR_NUMBER> --repo <owner>/<repo> --json title,body,files
gh pr diff <PR_NUMBER> --repo <owner>/<repo>
```

Analyze the changes to identify:
- **Components added/modified** (new files, classes, functions, routes)
- **Data flow** (how data moves between components)
- **Integration points** (APIs called, services connected, storage layers)
- **Before/after** (what changed architecturally)

### Step 2: Call `read_me` (once per conversation)

Call the Excalidraw `read_me` tool to get the element format reference. Only call this once.

### Step 3: Design the Diagram

**Always create a Before/After diagram** showing what changed. This is the most valuable view for PR reviewers.

| PR Type | Before (left side) | After (right side) |
|---------|-------------------|-------------------|
| New API endpoint | No endpoint exists | Full request flow |
| Refactoring | Old structure | New structure with shared helpers |
| Performance | Slow path with bottleneck | Optimized path with metrics |
| Bug fix | Broken flow with X mark | Fixed flow with checkmark |
| New feature | System without feature | System with new component |

**Layout rules:**
- Use Camera XL (1200x900) for before/after diagrams
- Left half = "Before", Right half = "After"
- Vertical dashed line divider in the middle
- Red/orange tones for "Before" problems, green tones for "After" improvements
- Keep it simple: 4-6 components per side max
- Include metrics annotations where available (e.g., "~1s wait" vs "~50ms")

### Step 4: Create the Diagram

Call `create_view` with the Excalidraw elements JSON array.

**Before/After template:**
```json
[
  {"type":"cameraUpdate","width":1200,"height":900,"x":0,"y":0},
  // Title
  {"type":"text","id":"title","x":350,"y":20,"text":"PR Title","fontSize":28},
  // Before label
  {"type":"text","id":"before-lbl","x":200,"y":70,"text":"Before","fontSize":24,"strokeColor":"#ef4444"},
  // After label
  {"type":"text","id":"after-lbl","x":800,"y":70,"text":"After","fontSize":24,"strokeColor":"#22c55e"},
  // Divider
  {"type":"arrow","id":"div","x":580,"y":60,"width":0,"height":800,"points":[[0,0],[0,800]],"strokeColor":"#d4d4d0","strokeWidth":1,"strokeStyle":"dashed","endArrowhead":null},
  // Before components (x: 50-550)
  // After components (x: 620-1150)
]
```

### Step 5: Export and Embed in PR

After `create_view` succeeds, do both:

**1. Export to Excalidraw** (interactive link):
Call `export_to_excalidraw` to get a shareable URL. This lets reviewers click through and explore.

**2. Generate static image** (inline in PR):
Use `GenerateImage` to create a PNG, then upload to GitHub:

```bash
# Compress image for GitHub (must be under 1MB)
sips -s format jpeg -s formatOptions 70 --resampleWidth 900 <source.png> --out /tmp/diagram.jpg

# Upload to fork repo on the PR branch
B64=$(base64 -i /tmp/diagram.jpg)
IMAGE_URL=$(gh api repos/<FORK_OWNER>/<REPO_NAME>/contents/docs/images/<diagram-name>.jpg \
  --method PUT \
  -f message="docs: add architecture diagram" \
  -f branch="<branch-name>" \
  -f content="$B64" \
  --jq '.content.download_url')
```

**3. Embed both in PR description:**

```markdown
### Architecture

![Diagram Description](<IMAGE_URL>)

[View interactive diagram on Excalidraw](<EXCALIDRAW_URL>)
```

Use `gh pr edit` to update the PR body with the embedded image and link.

## Color Conventions for Kibana PRs

| Layer | Fill Color | Use For |
|-------|-----------|---------|
| API/Route | `#a5d8ff` (light blue) | HTTP routes, controllers |
| Service/Logic | `#d0bfff` (light purple) | Business logic, service layer |
| Storage/ES | `#c3fae8` (light teal) | Elasticsearch, indices, storage |
| External | `#ffd8a8` (light orange) | External APIs, connectors |
| Schema/Types | `#fff3bf` (light yellow) | Type definitions, schemas |
| Slow/Problem | `#ffc9c9` (light red) | Bottlenecks, bugs, removed code |
| Fast/Fixed | `#b2f2bb` (light green) | Improvements, new code, fixes |

## Before/After Annotation Tips

- Use `#ef4444` (red) stroke for "slow" or "broken" arrows in Before
- Use `#22c55e` (green) stroke for "fast" or "fixed" arrows in After
- Add timing annotations: "~1s" in red, "~50ms" in green
- Cross out removed components with a red X or strikethrough line
- Highlight new components with a green glow (light green background zone)
- Arrow labels should be verbs: "validates", "indexes", "returns", "calls"
