# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a GitHub profile repository (`lxi407c/lxi407c`). `README.md` at the root is rendered as the public profile page on GitHub. It also contains a standalone web app in `todo/`.

## Todo App

`todo/index.html` is a single-file vanilla JS app with no build step and no dependencies. Open directly in a browser to run. State persists via `localStorage` under the key `todos` as `{ text: string, done: boolean }[]`.

## README Conventions

- Badge format: `https://img.shields.io/badge/<label>-<color>.svg?&style=for-the-badge&logo=<logo>&logoColor=<color>`
- Header banner: `capsule-render.vercel.app`
- Badge groups are wrapped in `<div>` blocks separated by `</br>`

## Claude Code Settings

`.claude/settings.json` registers a `SessionStart` hook at `.claude/hooks/session-start.sh`. The hook is a no-op unless `CLAUDE_CODE_REMOTE=true` (Claude Code on the web).

---

<!-- maintainer notes

## How to write an effective CLAUDE.md (from official docs)

### When to add an instruction
Add to CLAUDE.md when:
- Claude makes the same mistake a second time
- You type the same correction into chat that you typed last session
- A new teammate would need the same context to be productive

### Size & structure
- Target under 200 lines. Longer files reduce adherence because rules get lost.
- Use markdown headers and bullets. Claude scans structure the way readers do.
- For each line ask: "Would removing this cause Claude to make mistakes?" If not, cut it.
- For path-specific rules, use .claude/rules/<topic>.md with YAML frontmatter `paths:` so
  instructions only load when Claude works with matching files.

### Specificity
Write instructions that are concrete enough to verify:
- "Use 2-space indentation" not "format code properly"
- "Run `npm test` before committing" not "test your changes"
- "API handlers live in src/api/handlers/" not "keep files organized"

### What to include vs. exclude
Include:
- Bash commands Claude can't guess
- Code style rules that differ from defaults
- Architectural decisions specific to this project
- Developer environment quirks (required env vars, gotchas)
- Common non-obvious behaviors

Exclude:
- Anything Claude can figure out by reading the code
- Standard language/framework conventions Claude already knows
- Detailed API documentation (link to docs instead)
- File-by-file descriptions of the codebase
- Information that changes frequently

### Import syntax
CLAUDE.md can reference other files with @path/to/file syntax:
  See @README.md for project overview.
Imported files are loaded into context at session start, so use sparingly.

### File placement
- ./CLAUDE.md          — shared with team via version control (this file)
- ./CLAUDE.local.md    — personal project-specific notes; add to .gitignore
- ~/.claude/CLAUDE.md  — personal preferences across all projects

### Hooks vs. CLAUDE.md
Use hooks (.claude/settings.json) for actions that MUST happen every time with zero
exceptions (e.g. lint after every edit). CLAUDE.md instructions are advisory; hooks
are deterministic.

Source: https://code.claude.com/docs/en/memory
        https://code.claude.com/docs/en/best-practices
-->
