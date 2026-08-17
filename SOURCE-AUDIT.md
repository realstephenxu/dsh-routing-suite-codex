# Source Audit

## Input

- Local archive: `$HOME\Downloads\dsh-routing-suite-main`
- Upstream: `https://github.com/yjh051108/dsh-routing-suite`
- Audited suite commit: `a09eb0a` (2026-08-15)

## Submodule provenance

The downloaded ZIP preserved gitlinks but not the submodule contents:

| Component | Audited gitlink commit |
|-----------|------------------------|
| injector | `f4ef59fb` |
| preset | `eff787e` |
| mode-boost | `a9a666` |

The preset commit identifies package version `0.2.0`. Repository README/version history is not consistent enough to claim that the suite itself is version `0.3.0`, so this adaptation records immutable commit identities instead.

## Claim boundary

The audited source contains DeepSeek v4-flash experiment and routing material, but no literal `0731` or `过拟合`. “修复 DeepSeek Flash 0731 过拟合” is therefore treated as the user's intended use case, not as a quoted upstream claim.

## Ported concepts

- Fresh task classification for the current prompt
- Near-field workflow guidance
- Depth adjustment for simple versus complex work
- Neutral/no-op behavior when routing is unnecessary

## Deliberately not ported

- Model-specific persona replacement
- First-turn tool-surface pruning
- Harness-specific custom tools

These have no stable one-to-one Codex Hook equivalent and would introduce model/version coupling or authority risks.
