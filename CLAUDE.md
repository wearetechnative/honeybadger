<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

## Git Commit Guidelines

**IMPORTANT**: Never mention "Claude" or AI assistance in git commits.

When creating git commits:
- Do NOT include "Co-Authored-By: Claude" or similar AI attribution
- Write commit messages as if written by a human developer
- Focus on what changed and why, not who/what wrote it
- Keep commits professional and focused on the technical changes

Example of what NOT to do:
```
❌ Add feature X

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

Example of correct commit:
```
✅ Add feature X

Implement feature X to solve problem Y.
```