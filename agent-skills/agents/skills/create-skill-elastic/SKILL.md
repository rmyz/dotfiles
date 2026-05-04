---
name: create-skill-elastic
description: Create a new Cursor skill and publish it to the elastic/skills repo via PR. Use when the user asks to create a skill, new skill, add skill, or share a skill with the team.
---

# Create and Publish Skill

Creates a new Cursor skill locally and publishes it to `elastic/skills` via a pull request.

## Instructions

### Step 1: Create the Skill Locally

Follow the built-in `create-skill` workflow to create the skill at `~/.cursor/skills/<skill-name>/SKILL.md`. This includes:
- Gathering requirements (purpose, triggers, domain knowledge)
- Writing the SKILL.md with proper frontmatter
- Creating any supporting files

### Step 2: Publish to elastic/skills

After the skill is created locally, sync it to the central repo:

```bash
# Clone or update local copy
if [ -d /tmp/elastic-skills ]; then
  cd /tmp/elastic-skills && git fetch origin && git checkout main && git pull origin main
else
  git clone https://github.com/elastic/skills.git /tmp/elastic-skills
  cd /tmp/elastic-skills
fi

# Create feature branch
git checkout -b feat/add-<skill-name>

# Copy skill from local to repo
cp -r ~/.cursor/skills/<skill-name> /tmp/elastic-skills/skills/<skill-name>

# Commit and push
git add skills/<skill-name>
git commit -m "feat: add <skill-name> skill"
git push origin feat/add-<skill-name>

# Open PR
gh pr create --repo elastic/skills \
  --base main \
  --head feat/add-<skill-name> \
  --title "feat: add <skill-name> skill" \
  --body "$(cat <<'PREOF'
## New Skill: <skill-name>

<skill description from SKILL.md frontmatter>

### Dependencies
- Required: <list required deps>
- Optional: <list optional deps>
PREOF
)"
```

### Step 3: Update README (if needed)

If the skill has dependencies (MCP servers, CLI tools), update the dependency table in `/tmp/elastic-skills/README.md` before committing. Add a row to the skills catalog table.

### Step 4: Report Back

Share the PR URL with the user. The skill is available locally immediately and will be available to others once the PR is merged and they run the install script.

## Key Rules

- `main` is protected -- always use feature branches and PRs
- Branch naming: `feat/add-<skill-name>` for new skills, `feat/update-<skill-name>` for updates
- One skill per PR
- Always create locally first, then publish (local copy is the working copy)
