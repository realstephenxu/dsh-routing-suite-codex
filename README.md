# DSH Routing Suite for Codex

This project is a **Codex adaptation** of [dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite).

本项目是 [dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) 的 **Codex 适配版**。

这是对 `dsh-routing-suite` 工作流思想的 Codex 原生适配，面向你所描述的 DeepSeek Flash 0731 过拟合场景。它不会按模型名绑定行为：无论当前选择哪一种 Codex 模型，路由只依据本轮提示词和当前 permission mode。

## 核心行为

- 每轮重新分类为 `plan`、`inspect`、`fix`、`build`、`adaptive` 或 `off`。
- 问候、闲聊和无工程意图的提示不注入工作流，避免“凡事重流程”的二次过拟合。
- 诊断请求默认只检查和报告，不擅自变成修复。
- 明确的修改请求才进入修复或构建流程。
- 简单任务保持紧凑；架构、迁移、跨组件任务增加兼容性和边界检查。
- 路由建议永远服从系统、开发者、用户、仓库、权限和沙箱规则，不扩大授权。

可靠主入口是插件内的 `$dsh-routing-suite-codex:route-codex-task` Skill；`UserPromptSubmit` Hook 是自动增强。这样即使某个 Codex 宿主版本没有把插件 Hook 输出送入模型，任何模型选择仍可通过显式 Skill 使用同一套路由标准。

## Windows + pwsh + Codex 复现

要求：PowerShell 7 (`pwsh`)、Node.js、支持 Plugins 与 Hooks 的 Codex CLI。

```powershell
git clone <your-repo-url> dsh-routing-suite-codex
Set-Location .\dsh-routing-suite-codex
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Verify.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
codex
```

首次启用或 Hook 内容改变后，在 Codex 中运行 `/hooks`，审查并信任 `UserPromptSubmit` Hook。官方安全机制会跳过尚未信任的本地 Hook。

如果当前宿主没有显示 Hook 注入，直接在提示开头使用：

```text
$dsh-routing-suite-codex:route-codex-task
```

无需安装时，也可以直接验证 Windows 原生实现：

```powershell
$plugin = '.\plugins\dsh-routing-suite-codex'
$inputJson = '{"prompt":"修复登录失败并运行回归测试","permission_mode":"default","model":"任意-codex"}'
& "$plugin\hooks\router.ps1" -InputJson $inputJson
```

输出中的 `[DSH route: fix; rules v2]` 表示本轮选择了修复工作流（rules v2 = 0.2.0 规则版本）。
换成任意 `model` 值，结果应保持一致。

## 验收：多情境 × 多难度压力测试

0.2.0 的验收不再局限于 16 条基础用例，而是迁移到分层压力测试（见 `ACCEPTANCE.md` Gate S）：

- 确定性层（无 API）：64 例「13 类情境 × L1-L4 难度」语料，覆盖路由、复杂度、双实现 parity、
  模型无关、UTF-8 编码、fail-open 与上下文完整性；
- 真机层（DeepSeek API）：从语料中抽取分层 Live 子集，按 baseline/routed 对照评分，
  要求路由/范围/收敛全部 100% 且 routed 不低于 baseline；
- Gate A7 回显探测：全新会话在注入上下文存在时能复述 `DSH-CODEX-ROUTER-V1`。

运行：`pwsh -File .\Verify.ps1`（确定性层）；`pwsh -File .\acceptance\Invoke-StressTest.ps1 -ApiKeyPath <key文件>`（完整真机层，会调用 DeepSeek API）。

## 目录

```text
.agents/plugins/marketplace.json       本地 Codex marketplace
plugins/dsh-routing-suite-codex/
  .codex-plugin/plugin.json            插件清单
  hooks/hooks.json                     Codex Hook 配置
  hooks/run-router.ps1                 Windows 入口（UTF-8 stdin）
  hooks/router-core.ps1                分类/输出/规则校验核心
  hooks/router.ps1                     Windows + pwsh 原生路由器
  hooks/router.mjs                     跨平台 Node 路由器
  hooks/routing-rules.json             两种实现共享的规则 v2 与提示
  skills/route-codex-task/             Hook 不可用时的手动技能
  tests/                               双实现测试 + 压力语料 + parity
Install.ps1                            验证并安装
Verify.ps1                             本地复现检查
```

## 适配边界

原 DSH 的“逐轮分类、近场提示、深度自适应”被保留。模型专属 persona、首轮工具裁剪和 Harness 自定义工具没有照搬，因为 Codex 当前稳定 Hook 接口没有完全等价且跨版本安全的能力；强行模拟会破坏“任何 Codex”兼容性。

“任何 Codex”指任何模型选择；宿主至少需支持 Plugins/Skills。若组织策略设置 `allow_managed_hooks_only`、禁用 Hooks，或当前宿主未送入插件 Hook 输出，使用上面的 namespaced Skill 入口。

本地源代码中没有出现字面量 `0731` 或 `过拟合`，因此本项目把它作为你的目标场景说明，而不把它伪装成上游仓库的可验证官方声明。详细来源记录见 `SOURCE-AUDIT.md`。

验收目标（多情境 × 多难度压力测试）与判定规则见 `ACCEPTANCE.md`。运行时显式传入 API key 文件，密钥不会写入验收产物。

## 官方依据

- [Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
- [Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)
- [Build skills](https://learn.chatgpt.com/docs/build-skills)
