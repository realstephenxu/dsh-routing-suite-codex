# Acceptance Standard

## What this plugin is for

`dsh-routing-suite-codex` ports the task-aware part of DSH Routing Suite to Codex. Its purpose is to reduce workflow overfitting: Codex should not keep one heavy persona or one execution style for every prompt. It must classify the current request afresh, use a proportionate workflow, preserve plan/read-only boundaries, converge on an authorized deliverable, and leave neutral prompts alone.

This plugin does not alter DeepSeek weights and does not claim to make probabilistic outputs deterministic. It supplies near-field workflow context through Codex's `UserPromptSubmit` hook.

## Acceptance gates

### Gate A — deterministic packaging and routing

All items must pass:

1. Skill and plugin validators pass.
2. Node and PowerShell routers pass every shared test case.
3. PowerShell and Node agree on route semantics.
4. Changing the input `model` value does not change classification.
5. `off` emits no context, and malformed input fails open.
6. The Windows hook entry command consumes Codex stdin correctly.
7. A fresh Codex session can repeat the unguessable `DSH-CODEX-ROUTER-V1` identity from injected context.

Gate A7 was proven on the tested host (Codex CLI 0.147.0, Windows 10) after the UTF-8 stdin
fix in the PowerShell hook entry; host variance is still recorded when it occurs, and the
bundled skill remains the documented fallback.

### Gate B — Windows + pwsh + Codex reproduction

All items must pass on the target machine:

1. `Verify.ps1` passes under PowerShell 7.
2. Codex CLI reports Plugins and Hooks available.
3. The local marketplace installs and the plugin appears enabled.
4. A new Codex session discovers the bundled skill, and explicit `$dsh-routing-suite-codex:route-codex-task` invocation can return `DSH-CODEX-ROUTER-V1`.
5. The PowerShell Hook entry passes its direct Codex-stdin contract test.

Automatic plugin-Hook injection is an enhancement gate, not the universal fallback gate. When a particular Codex host does not surface plugin Hook output, record that host limitation and use the bundled skill; do not claim automatic injection passed.

### Gate C — live DeepSeek-V4-Flash evaluation

Run 16 task types in baseline and routed conditions (32 API calls total). The routed condition uses the exact context produced by the PowerShell hook.

The routed condition passes only when:

- route accuracy is 16/16;
- scope accuracy is 16/16 (`read_only`, `change`, or `no_engineering`);
- response convergence is 16/16 (valid JSON and `done: true`, meaning the current evaluation response is complete at the available scope, not that absent repository work was executed);
- its combined score is not below the baseline score;
- the API confirms the requested model is currently available.

Save model id, system fingerprint, token usage, sanitized request fixtures, responses, and per-case scores. Never save the API key.

### Gate S — multi-context, multi-difficulty stress acceptance (0.2.0)

Acceptance for 0.2.0 requires passing a stratified stress suite instead of the 16-case
matrix alone:

1. Deterministic layer (no API): the shared stress corpus (`tests/stress-cases.json`,
   at least 12 scenario families x L1-L4 difficulty, plus edge cases) must pass with
   100% accuracy for route and complexity in BOTH implementations.
2. Parity: Node and PowerShell must agree on route and complexity for every corpus case,
   and classification must be invariant to the `model` value.
3. Robustness: malformed input fails open with no output; `off` emits no context;
   the Windows hook entry decodes UTF-8 stdin correctly (Chinese prompts keep signals).
4. Context integrity: every non-`off` output carries the route marker, the router
   identity `DSH-CODEX-ROUTER-V1`, and the rules version marker (`rules v2`).
5. Live layer (DeepSeek API): a stratified subset (every family, simple + complex) runs
   baseline/routed; passes only when route 16+/16, scope 16+/16, convergence 16+/16,
   routed score >= baseline, and the requested model is available.
6. Gate A7 echo probe: a fresh read-only Codex session repeats
   `DSH-CODEX-ROUTER-V1` when the injected context is present.

The deterministic layer must pass before any live layer runs, and any failure at either
layer blocks acceptance of the 0.2.0 build.

## Interpretation

Passing proves this plugin package, route contract, Windows path, the stratified stress
suite, and one recorded DeepSeek API sample met the declared standard. It does not prove
universal elimination of overfitting. A release-grade statistical claim would additionally
require repeated seeds/runs, frozen prompts, and comparison across multiple clean machines.
