# Findings & Decisions

## Requirements
- Adapt `$HOME\Downloads\dsh-routing-suite-main` from DeepSeek Harness to Codex.
- Support any Codex model/version without model-name branching.
- Reproduce on Windows + PowerShell 7 + Codex.
- Write the formal deliverable beneath `<repo-parent>`.

## Research Findings
- The local suite top level matches upstream suite commit `a09eb0a` dated 2026-08-15.
- The downloaded ZIP leaves three git submodules empty. Audited gitlink commits are injector `f4ef59fb`, preset `eff787e`, and mode-boost `a9a666`.
- The source contains no literal `0731` or `过拟合`; its directly verifiable scope is DeepSeek v4-flash routing experimentation.
- Original behavior includes per-turn classification, near-field guidance, later-turn reclassification, depth adaptation, persona replacement, and initial tool pruning.
- Current environment: Windows x64, PowerShell 7.4.17, Codex CLI 0.147.0, Node 24.15.0, Python 3.14, Git 2.54.
- `plugins` and `hooks` are stable and enabled in the installed Codex CLI.

## Official OpenAI Documentation Findings
- A plugin requires `.codex-plugin/plugin.json` and may package skills and lifecycle hooks.
- The default plugin hook file is `hooks/hooks.json`; the plugin manifest does not need a `hooks` field.
- `UserPromptSubmit` accepts JSON on stdin and can return `hookSpecificOutput.additionalContext`.
- Hook commands can provide `commandWindows`; plugins receive `PLUGIN_ROOT` and `PLUGIN_DATA`.
- Windows is supported with native PowerShell and the Windows sandbox.
- Local command hooks require review/trust; a vetted one-off test may use `--dangerously-bypass-hook-trust` without persisting trust.
- DeepSeek's current official model ids are `deepseek-v4-flash` and `deepseek-v4-pro`; the legacy `deepseek-chat` alias passed its announced deprecation date.
- Live acceptance will use `GET /models` before `POST /chat/completions`, thinking disabled, JSON output, and 32 baseline/routed calls.
- First live matrix: routed route 16/16 and scope 16/16; combined score 33 versus baseline 27. The initial `done` wording was ambiguous, so honest requests for missing repository context were counted as non-converged.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Routes: `plan`, `inspect`, `fix`, `build`, `adaptive`, `off` | Covers Codex workflows without inheriting DeepSeek-specific personas. |
| Fresh classification on every prompt | Preserves DSH near-field behavior while avoiding stale turn state. |
| Fail open with no output on malformed input | A routing helper must never block Codex. |
| No persistent routing state | Supports all Codex variants and avoids plugin-data coupling. |
| No MCP server | Routing only needs a deterministic local hook and skill; fewer dependencies improve portability. |

## 0.2.0 Architecture Decisions
| Decision | Rationale |
|----------|-----------|
| Windows hook entry = auditable `run-router.ps1`, logic in `router-core.ps1` | The old inline base64 entry caused the UTF-8/GBK bug and was un-reviewable; a runner script plus static decode check makes the entry verifiable. |
| Symptom words (timeout/crash/leak/vulnerability/...) are NOT `fix` signals | A diagnosis prompt mentioning a symptom must stay `inspect`; only repair verbs (`fix/修复/解决/...`) authorize the `fix` route. |
| `noChange` negation suppression | `不要修改/do not change` must not route to `build`/`fix`; negation now zeroes those scores. |
| Plan-explicit tightened (制定/出/给/写/提供 + plan; 只做方案 kept) | `先做方案再实施` is a build request, not a plan-only request. |
| Difficulty words extended (migrate/regression/vulnerability/scalable/性能/回归/漏洞/大规模) | Makes L3/L4 complexity detection deterministic for the stress corpus. |
| Rules-version marker `[DSH route: X; rules v2]` | Diagnosing stale caches/versions becomes a one-liner. |
| Live acceptance = stratified stress matrix with harness calibration | Context-requesting responses are complete at available scope (done=true); the two pre-calibration runs remain as evidence. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| README/version metadata in the source history is inconsistent | Pin provenance to commit hashes instead of claiming a package version. |
| Local plugin validator rejects unsupported manifest `hooks` fields | Use the official default `hooks/hooks.json` discovery path. |

## Resources
- https://developers.openai.com/plugins/build/plugins
- https://learn.chatgpt.com/docs/hooks
- https://learn.chatgpt.com/docs/windows/windows-sandbox
- https://learn.chatgpt.com/docs/build-skills

## Browser Findings
- Official pages fetched on 2026-08-17 confirm plugin packaging, hook output shape, Windows command overrides, hook trust, and native Windows support.
