<div align="center">

# dual-model-answer · 双模型同题对拍

### 让 Claude Code 与 Codex 独立作答、交叉挑错，把每条意见送到真正需要修改的一方

[![License: MIT](https://img.shields.io/badge/License-MIT-f5c542.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-2ea44f.svg)](./SKILL.md)
[![Agent Skills](https://img.shields.io/badge/agent-skills-black.svg)](https://agentskills.io/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-sole%20orchestrator-8a63d2.svg)](https://code.claude.com/docs/en/overview)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-second%20model-3b7dd8.svg)](https://learn.chatgpt.com/docs/codex/cli)

**[English](./README.en.md) | 中文**

</div>

---

## 为什么要做这个 Skill

你把同一个问题交给 Claude Code 和 Codex，屏幕上很快出现两份看起来都很完整的答案。真正费力的工作这才开始：把 Claude 找出的错贴给 Codex，再把 Codex 补充的材料搬回 Claude；核对哪条意见已经处理，哪条被含糊带过，哪段正确内容在改稿时悄悄消失。两个模型各自会写、会审，坐在屏幕前的人却成了维系整个流程的那根线。

一旦把流程自动化，这根线也可能随之消失。一次真实对拍的逐条复核显示，首轮 16 条发现有 10 条在对方次版里原样存活；在那次运行中，终轮审阅因为没有后续载体，发现 100% 丢失，终轮 5 条发现有 4 条「重要」级原样留在交付稿；六次订正中还有三次以删除争议内容代替订正。完整记录见 [`SKILL.md`](./SKILL.md#已知坑实测记录)。

`dual-model-answer` 把这根线做成了一套可审计的工作流。两个模型先独立起稿，再把审阅意见直接送给被审阅方逐条处理，同时保留答案、正文差异、处置记录和终审结果。你在开头给出一个 Prompt，结尾拿到两份独立终稿，以及一张说明哪些问题已经收敛、哪些仍有分歧的表。目标是提高事实置信度与可追溯性，证据始终比模型共识更重要。

## 原理

默认流程包含两轮互审和一次只审不改的终审：

```text
同一 Prompt
   │
   ├── Claude 独立作答 v1
   └── Codex  独立作答 v1
             │
             ▼
       双向交叉审阅
       ├── 对方的审阅意见用于补短
       └── 对方的答案全文用于补长
             │
             ▼
        各自修订为 v2
             │
        再次互审与修订
             │
             ▼
       两份终稿 v3
             │
       只审不改的终审
             │
             ▼
       共识与分歧表
```

四项设计构成闭环：

| 设计 | 作用 |
|---|---|
| **首轮材料隔离** | 两个模型只读同一 Prompt，互不看稿，降低初始锚定 |
| **双通道传递** | 对方的审阅意见修补弱点，对方的答案全文补充遗漏 |
| **一步一档** | 每次作答、互审、修订和终审独立成文，保留从输入、审阅到处置的追溯链，并消除旧设计把多份内容堆在一份文档、靠章节边界指路所造成的切片泄漏路径 |
| **diff 与终审** | diff 检查无声回归和以删代改；终审承载无法再进入修订稿的问题 |

文件分离提供的是投递边界，并非逐文件访问沙箱。首轮互不见面仍依赖调度员只投递原始 Prompt，并要求 agent 遵守材料边界。

每条审阅发现都有稳定编号。修订者只能选择「采纳」「驳回」或「保留分歧」；驳回必须给出证据，保留分歧必须说明属于事实层还是框架层。审阅文档还设有「可吸收之处」，用于传递对方答案中值得复用的证据和论证，避免双方重复核查。稳定编号与封闭处置词表使最终的共识与分歧表可以机械抽取，每一行都能追溯到源文档，不混入调度员的临时判断。

最终交付保留两份独立终稿及其分歧记录，不会把来源不同的判断自动拼成一份表面统一的答案。

## 安装

> **两条前置，分工不同。**
> **调度方只能是 Claude Code**——整条流程由它派发独立子任务、执行 Shell、统一写盘。其他 Harness 可以读取说明、准备材料并交接，不能声称已执行完整流程。
> **Codex CLI 是被调用的第二模型，不需要装这个 skill**，只要本地[装好并认证](https://learn.chatgpt.com/docs/codex/cli)即可：`codex --version` 查安装，`codex login status` 查当前认证方式。Codex 不可用时，工作流会如实停止，不会用单模型输出冒充双模型结果。

**方式一 · 一行命令（推荐）**

```bash
npx skills add HoraceLuBFA/dual-model-answer -g -a claude-code
```

[`npx skills`](https://github.com/vercel-labs/skills) 支持 `owner/repo` 形式的 GitHub 来源，`-g` 表示用户级安装，`-a claude-code` 把安装目标限定为 Claude Code——其他 agent 即使能发现共享安装，也只用于了解前置条件和交接。

安装后检查三件事：skill 装没装、Codex 装没装、Codex 认证如何。

```bash
npx skills ls -g -a claude-code
codex --version
codex login status
```

**方式二 · 交给 agent 安装**

把仓库链接发给 Claude Code：

> 帮我安装这个 skill（只装给 Claude Code）：https://github.com/HoraceLuBFA/dual-model-answer

**方式三 · 手动 clone**

Claude Code 的个人 Skill 目录是 `~/.claude/skills/`，直接 clone 进去即可：

```bash
mkdir -p ~/.claude/skills

git clone https://github.com/HoraceLuBFA/dual-model-answer.git \
  ~/.claude/skills/dual-model-answer
```

如果你习惯把各 agent 共用的 skill 真身集中放在 `~/.agents/skills/`，改为 clone 到那里再建一条软链——Claude Code 接受指向别处的软链并会跟随解析：

```bash
git clone https://github.com/HoraceLuBFA/dual-model-answer.git \
  ~/.agents/skills/dual-model-answer

ln -s ~/.agents/skills/dual-model-answer \
  ~/.claude/skills/dual-model-answer
```

验证发现入口与运行时依赖：

```bash
test -f ~/.claude/skills/dual-model-answer/SKILL.md && \
  test -f ~/.claude/skills/dual-model-answer/scripts/dma-lib.sh && \
  codex --version && \
  codex login status && \
  echo OK
```

## 使用方式

**显式调用**

```text
# 在 Claude Code 里用斜杠命令
/dual-model-answer 评估 X 与 Y 两种方案在我们场景下的取舍
```

Codex 一侧不需要你手动开窗口：调度员为每一步新开一个 `codex exec` 会话，材料以文件路径递进去，回收正文后统一写盘。

**自然语言调用**

```text
用 dual-model-answer 对拍下面的问题，互审 2 轮：

应该如何为一个本地优先的笔记应用设计同步架构？
请比较至少三种方案，核查关键技术事实，并明确适用边界。
```

也可以指定轮数、输出的父目录、事项名、Codex 模型或推理强度。你传入的始终是父目录，产物落在它下面新建的 `dual-model-answer/` 里；未指定时父目录即当前工作目录。事项名默认从 Prompt 概括为 2 至 8 字，并跟随 Prompt 的语言；成稿档位则按任务性质自动选择。研究档要求引证与规范参考文献，通用档不强制编号引证，但事实性断言仍须有可核查依据。

> ⚠️ **这是一条重型工作流。** 默认两轮互审加终审约需 12 次模型调用，并生成 14 份可回溯文件。Codex 侧的消耗取决于本地 CLI 当前的认证方式：ChatGPT 登录使用相应订阅访问权限，API Key 登录按 API 用量计费。开跑前，skill 会播报本次配置。

## 适用场景

适合需要较高事实置信度，且值得投入额外模型调用的任务：

- 深度调研、技术选型与争议问题分析；
- 文章、报告、方案和重要对外文案；
- 代码解读、架构分析与复杂知识问答；
- 需要系统核查引证、归属、术语、数值与日期、过强断言的内容。

以下任务应使用更直接的流程：

| 情形 | 建议流程 |
|---|---|
| 已有一份待审文档，只需要多方互查 | `cross-review` |
| 需要修改代码并经过规划、实现和验收 | `dual-model-dev` |
| 仅审查已有代码 diff | `code-review` |
| 简单、低风险的问题 | 单模型通常更省时 |

## 前置条件与边界

- 调度方只能是 Claude Code：流程依赖它派发独立子任务与执行 Shell 命令的能力，本 skill 也只装给它；
- Codex CLI 必须在本地可用并完成认证，它是被调用的第二模型，无需安装本 skill；
- 事实核查只允许只读操作，核对页码所需的 PDF 只能下载到临时目录；
- Codex 或 Claude 调用失败时会重试一次，仍然失败则暂停并如实报告；
- 工作流只写本次输出目录和临时文件，不动用户的其他文件；
- 两个模型达成一致仍可能同时出错，共识只能作为线索，证据才是裁决依据；
- 已有文档审阅、代码仓库开发和现有 diff 审查分别有更合适的专用流程。

## 交付物

默认配置保留完整链路，而非只留下最后两篇答案：

```text
dual-model-answer/
├── 00 index.md
├── 01 Claude answer v1.md
├── 01 Codex answer v1.md
├── 02 Claude review-1.md
├── 02 Codex review-1.md
├── 03 Claude answer v2.md
├── 03 Codex answer v2.md
├── 04 Claude review-2.md
├── 04 Codex review-2.md
├── 05 Claude answer v3.md
├── 05 Codex answer v3.md
├── 06 Claude 终审意见.md
├── 06 Codex 终审意见.md
└── 07 共识与分歧.md
```

一步一档还有一项实际用途：文件按字典序对应流程顺序；运行中断后，查看缺失的文件对即可判断从哪一步续跑。

通常最值得先读的是：

1. `05 Claude answer v3.md` 与 `05 Codex answer v3.md`：两份独立终稿；
2. `06 Claude 终审意见.md` 与 `06 Codex 终审意见.md`：终稿中仍需警惕的问题；
3. `07 共识与分歧.md`：已收敛事项、证据化驳回、保留分歧和未修正发现。

每份文档顶部的 frontmatter 由调度员写入，记录生成模型、投递通道、读取材料、审阅目标和版本关系。v1 通过取舍备忘保存作者意图；从 v2 起，修订版还会附上逐条处置审阅发现的修订说明。这样，后续修订者既能核查证据，也不会把刻意保留的限定语当成缺陷改掉。

文件名由 `SKILL.md` 固定，不随 Prompt 语言变化；各文档的正文语言跟随 Prompt。

## 仓库结构

```text
dual-model-answer/
├── SKILL.md                    # 工作流规范、调度约定与安全边界
├── README.md                   # 中文说明
├── README.en.md                # English documentation
├── references/
│   └── templates.md            # 作答、互审、修订和终审模板
├── scripts/
│   └── dma-lib.sh              # 提取、diff、调用、校验与写盘函数
└── LICENSE
```

本项目遵循 [Agent Skills 规范](https://agentskills.io/specification)：`SKILL.md` 提供元数据与工作流指令，详细模板和可执行工具分别放入 `references/` 与 `scripts/`。

工具库还封装了三类容易静默失效的操作：长 Prompt 通过 stdin 传入，避免内联截断；Codex 调用以非空回收文件判断完成，避免误信退出码；联网冒烟核验读取会话 rollout，避免把残缺日志当成未调用工具的证据。实现与实测说明均保留在 `scripts/dma-lib.sh` 的注释中。

## 致谢与许可

感谢 [Claude Code](https://code.claude.com/docs/en/overview)、[OpenAI Codex](https://learn.chatgpt.com/docs/codex/cli) 与开放的 [Agent Skills](https://agentskills.io/) 生态。

本 skill 的代码、提示词与组织方式以 [MIT 许可](https://opensource.org/license/mit)发布，可在保留版权声明和许可声明的前提下使用、修改与再分发。完整条款见 [LICENSE](./LICENSE)。

## 模型身份与完成条件

Claude 与 Codex 是工作流角色和文件标签。执行前核对实际 Provider、模型与可用调用方式；路由到同一模型时，如实标记，不能称为跨模型验证。默认完成约定的全部审阅轮次和终审，只有用户选择提前收敛时才提前结束。子进程结束、退出码成功、产生本次调用的新非空产物且符合文档协议后，才计为该步完成。
