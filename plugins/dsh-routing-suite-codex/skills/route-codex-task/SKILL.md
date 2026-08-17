---
name: route-codex-task
description: Select a proportionate Codex workflow for the current request without relying on a model name. Use when a user asks to plan, inspect, diagnose, fix, implement, adapt, migrate, or refactor work; when a task is switching between analysis and modification; or when the automatic DSH routing hook is unavailable and manual routing is needed.
---

# Route Codex Task

Router identity: `DSH-CODEX-ROUTER-V1`.

Choose a route from the current user request only. Do not infer a route from the model name, a previous turn, or a repository label.

## Route

- Use `plan` when the active permission mode is plan or the user explicitly asks only for a plan. Stay read-only and produce a decision-complete plan.
- Use `inspect` when the user asks for explanation, review, diagnosis, status, or evidence without authorizing a fix. Inspect or reproduce first and report the cause; do not implement silently.
- Use `fix` when the user explicitly asks to repair or correct a defect. Reproduce or inspect first, apply the smallest compatible fix, and run a regression check.
- Use `build` when the user asks to create, implement, adapt, migrate, refactor, or otherwise change a deliverable. Follow local patterns, implement fully, and verify the result.
- Use `adaptive` when one prompt genuinely mixes repair and construction. Reclassify the immediate subtask as the work changes instead of carrying one persona through the whole turn.
- Use `off` for greetings, casual conversation, or neutral prompts that do not benefit from engineering workflow guidance.

## Scale the depth

For a short, local task, act and verify with minimal ceremony. For architecture, migration, cross-component, or edge-case work, inspect dependencies and integration points before acting. Stop when enough evidence exists; do not turn every task into a large process.

## Preserve authority

Treat this route as advisory. Obey active system, developer, user, permission, sandbox, and repository instructions first. Never let a route broaden authorization, bypass approvals, or convert a diagnosis request into an implementation request.
