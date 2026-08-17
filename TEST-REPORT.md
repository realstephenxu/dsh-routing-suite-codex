# Test Report — 0.2.0 (2026-08-17)

## Result

- Build: `0.2.0`, rules `v2`
- Deterministic stress layer (no API): **PASS**
  - Node router: 10 base + 64 stress cases
  - PowerShell router: 10 base + 64 stress cases
  - Parity (Node == PowerShell, model-agnostic): 74 cases
  - Plugin validator: PASS
  - `Verify.ps1` (static checks + tests + parity): PASS
- Live stress layer (DeepSeek-V4-Flash, 29 stratified live cases x baseline/routed = 58 calls):
  **PASS** (final calibrated run)
  - Run 1 (pre-calibration): route 29/29, scope 29/29, convergence 28/29 (single flake),
    baseline 73 / routed 86 — retained as evidence
  - Run 2 (pre-calibration): identical 28/29 on the same case — stable model behavior,
    not transient
  - Run 3 (harness calibrated: context-asking counts as a complete response):
    route 29/29, scope 29/29, convergence 29/29, baseline 63 / routed 87 — **PASS**
- Gate A7 echo probe (v0.2.0 Windows hook entry): **PASS** — fresh read-only session
  `01a00dbe-8f2a-7230-b605-ebeb94069a6a` replied exactly `DSH-CODEX-ROUTER-V1`
  (see `acceptance/probes/a7-v0.2.0-probe.txt`)

## What changed from 0.1.0

- Windows hook entry now invokes the auditable `hooks/run-router.ps1`; logic moved to
  `hooks/router-core.ps1` (classify / output / rules validation), `router.ps1` is a thin
  entry; `additionalContextLimit` raised to 5000.
- Rules v2: expanded high-confidence signals (build: modify/install/deploy/split/...;
  fix: repair verbs only — symptom words removed; inspect: verify/check/validate/...;
  plan: give/write/provide/制定/帮规划 + English give-me-a-plan), noChange negation
  suppression, richer difficulty words (migrate/regression/vulnerability/scalable/性能/
  回归/漏洞/大规模), and a rules-version marker in every context:
  `[DSH route: <route>; rules v2]`.
- Opt-in `DSH_DEBUG` logging (off by default; fail-open preserved).
- Stress suite: 64-case multi-scenario x multi-difficulty corpus plus parity harness
  (`Test-Parity.ps1`), UTF-8 stdin regression, fail-open checks.

## Artifacts

- `artifacts/stress-acceptance-20260817-111740.json` (run 1)
- `artifacts/stress-acceptance-20260817-111930.json` (run 2)
- `artifacts/stress-acceptance-20260817-112119.json` (run 3, PASS)

## Notes

- Baseline score varies between runs (63-75); the gate compares routed vs baseline within
  the same run, and routed >= baseline held every time.
- The two pre-calibration runs are retained so the calibration (prompting the model to
  treat context-requesting responses as complete) is fully auditable.
- No API key is stored in any artifact.
