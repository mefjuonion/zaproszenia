---
name: remove-comments
description: "Use when asked to remove, strip or delete comments from code (\"remove comments\", \"usuń komentarze\", \"wywal komentarze\") in a file, a directory, or the current changes. Removes every comment in JS/TS/JSX, CSS, shell, Python, YAML, TOML, Terraform, Dockerfile and ignore files, while keeping the few comment-shaped lines that change behavior (shebangs, directives, lint/type pragmas). Verifies the code still lints, type-checks and parses afterwards."
license: MIT
metadata:
  version: "1.0.0"
---

# Remove comments

Remove **all** comments from the target code. Do not judge whether a comment is useful: every comment goes, except the behavior-changing lines listed under "Keep".

## 1. Scope

| Request | Files |
|---|---|
| Named files or directories | Those, recursively |
| Nothing named | Changed and untracked files: `git status --porcelain` |
| "The whole repo" | All tracked files: `git ls-files` |

Always skip generated or vendored files: `node_modules/`, `.next/`, `out/`, `build/`, `.terraform/`, `.terraform.lock.hcl`, lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `uv.lock`, `poetry.lock`), `next-env.d.ts`, minified files, binaries.

Do not touch Markdown, HTML or Python docstrings unless the user asks for them explicitly. Docstrings are strings, not comments, and `<!-- -->` in docs is often content.

## 2. What to remove

| Language / file | Comment syntax |
|---|---|
| JS, TS, JSX, TSX, MJS, CJS | `// ...`, `/* ... */`, `/** ... */`, JSX `{/* ... */}` |
| CSS, SCSS | `/* ... */` (and `// ...` in SCSS) |
| Shell, Python, YAML, TOML, Terraform/HCL, Dockerfile, `.gitignore`, `.dockerignore`, `.env*` | `# ...` (HCL also `//` and `/* */`) |
| SQL | `-- ...`, `/* ... */` |
| HTML / Markdown (only if asked) | `<!-- ... -->` |

Shell scripts embedded in YAML (`run: |` blocks in lefthook or GitHub workflows) are shell: their `#` comment lines are comments too and get removed.

## 3. Keep (behavior, not commentary)

These look like comments but change how the code runs, builds or is checked. Keep them and list them in the report.

- Shebangs: `#!/usr/bin/env bash`
- React directives: `"use client"`, `"use server"`, `"use cache"` (strings, never comments)
- Lint and type pragmas: `// eslint-disable*`, `/* eslint-disable */`, `// @ts-expect-error`, `// @ts-ignore`, `// @ts-nocheck`, `// prettier-ignore`, `# noqa`, `# type: ignore`, `# pyright:`, `# shellcheck disable=...`, `# tflint-ignore`
- Triple-slash directives: `/// <reference ... />`
- Dockerfile parser directives on the first lines: `# syntax=...`, `# escape=...`
- Encoding and tool headers: `# -*- coding: ... -*-`, `# yaml-language-server: $schema=...`
- Bundler/compiler magic comments: `/* webpackChunkName: ... */`, `//go:build`, `//go:generate`, `# frozen_string_literal: true`
- License headers when the file or repo states they are required

If a pragma has an explanation after it (`// eslint-disable-next-line no-console -- debug output`), keep the pragma and drop only the explanation (`-- debug output`).

## 4. How to edit safely

- Edit with the Edit tool, file by file. Never run a blanket `sed`/regex over many files: comment markers also appear inside code.
- Never touch `#`, `//` or `/*` inside strings, template literals, URLs (`https://`), regex literals, heredocs, CSS `url()` or YAML/TOML string values. Example: `color: "#fff"`, `run: echo "# not a comment"`, `const re = /\/\//`.
- A whole-line comment: delete the line. If that leaves two blank lines in a row, or a blank line right after an opening brace or at the start of a block, delete that blank line too.
- A trailing comment (`x = 1  # note`): delete the comment and the whitespace before it.
- A comment that was the only content of a block (e.g. an empty `catch {}` with a comment, or a YAML key whose value was only comments) stays syntactically valid: leave the empty block, do not delete code.
- Commented-out code is a comment: remove it.

## 5. Verify

Run the checks for every area you touched, from the right directory, and fix anything you broke:

| Touched | Check |
|---|---|
| `src/<name>` with `package.json` | `npx --no-install eslint --max-warnings=0 .` and `npx --no-install tsc --noEmit` (run in `src/<name>`, needs `npm ci` first) |
| `.config/terraform` | `terraform fmt -check -recursive` and `terraform validate` (after `terraform init -backend=false`) |
| Shell scripts | `bash -n <file>` |
| YAML | `ruby -ryaml -e 'ARGV.each { \|f\| YAML.safe_load(File.read(f)) }' <files>` (PyYAML is usually not installed) |
| TOML | `python3 -c 'import sys,tomllib; [tomllib.load(open(f,"rb")) for f in sys.argv[1:]]' <files>` |
| Python | `python3 -m py_compile <files>` |

Then run `git diff --stat` and skim the diff: only comment lines and trailing comments should be gone.

## 6. Report

Keep it short:

- files changed and the number of comments removed,
- the comment-shaped lines you kept on purpose (file:line, which rule from section 3),
- the checks you ran and their result.

Do not commit.
