# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a GitHub profile repository (`lxi407c/lxi407c`). The `README.md` at the root is rendered as the public profile page for `lxi407c` on GitHub. It also contains a small standalone web app.

## Structure

- `README.md` — GitHub profile page with shield.io badges and capsule-render header
- `todo/index.html` — Self-contained Korean TODO list app (no build step, no dependencies)
- `.claude/settings.json` — Registers a `SessionStart` hook
- `.claude/hooks/session-start.sh` — No-op hook for non-remote environments; prints a message in Claude Code on the web

## Todo App

`todo/index.html` is a single-file vanilla JS app. State is persisted via `localStorage` under the key `todos` as a JSON array of `{ text: string, done: boolean }`. There is no server, no bundler, and no test suite — open the file directly in a browser to run it.

## README Conventions

- Badge images use shields.io format: `https://img.shields.io/badge/<label>-<color>.svg?&style=for-the-badge&logo=<logo>&logoColor=<color>`
- The header banner uses `capsule-render.vercel.app`
- Badge groups are wrapped in `<div>` blocks, separated by `</br>`

## Claude Code Settings

`.claude/settings.json` configures a `SessionStart` hook that runs `.claude/hooks/session-start.sh`. The hook exits early unless `CLAUDE_CODE_REMOTE=true`, so it only takes effect in Claude Code on the web.
