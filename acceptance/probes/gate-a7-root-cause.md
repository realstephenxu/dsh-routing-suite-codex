# Gate A7 root cause analysis

Date: 2026-08-17
Host: Windows 10 Pro x64, PowerShell 7.4.17, Codex CLI 0.147.0

## Symptom

`UserPromptSubmit` hook reported `Completed`, but the model never saw the router
identity from injected context; the model replied `none` to an exact-echo probe.

## Diagnosis

- Feature flags: `hooks` stable, `plugins` stable, `plugin_hooks` removed in this build.
  The removed flag was a suspect but is not the cause: plugin hook output IS injected.
- `codex debug prompt-input` with a `fix`-routed prompt rendered 5 input items and no
  hook context (hooks are not run by this debug renderer).
- RUST_LOG trace of a real `codex exec`: the hook runs (~0.5 s) between
  `hook/started` and `hook/completed`, and the first HTTP request to
  `https://api.deepseek.com/responses` contained only skills/permissions/agent/env/user
  items — no hook context.
- Temporary probe plugin: a hook that always emits `PROBE-MARKER-7F3A9C2E` had its
  output injected as a developer message in the request. Pipeline is functional.
- The probe's stdin log revealed the trigger: Codex pipes UTF-8, but
  `[Console]::In.ReadToEnd()` decoded with GBK, so the Chinese prompt arrived as
  mojibake (`修复这个示例报错` -> `淇鎶ラ敊锛...`).
- Mojibake defeated routing: Chinese signals never matched; English `\b` word
  boundaries failed adjacent to mangled CJK characters (e.g. `欵Error` has no boundary
  before `Error`), so the router classified the prompt as `off` and emitted nothing.

## Fix and verification

- Windows hook entry now sets UTF-8 input encoding before reading stdin.
- `router.ps1` sets `[Console]::InputEncoding` defensively.
- Regression test added for UTF-8 Chinese stdin.
- End-to-end post-fix request contained:
  `[DSH route: fix] Router identity: DSH-CODEX-ROUTER-V1 ...` as a developer message.

## Conclusion

Gate A7 passes with the fix. The earlier "NOT PROVEN / FAIL on this host" records were
caused by this Windows encoding bug and by probes whose prompts routed to `off`.
