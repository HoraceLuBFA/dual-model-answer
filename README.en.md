<div align="center">

# dual-model-answer · Adversarial Dual-Model Answers

### Let Claude Code and Codex answer independently, challenge each other, and deliver every finding to the model that must act on it

[![License: MIT](https://img.shields.io/badge/License-MIT-f5c542.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-2ea44f.svg)](./SKILL.md)
[![Agent Skills](https://img.shields.io/badge/agent-skills-black.svg)](https://agentskills.io/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-sole%20orchestrator-8a63d2.svg)](https://code.claude.com/docs/en/overview)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-second%20model-3b7dd8.svg)](https://learn.chatgpt.com/docs/codex/cli)

**English | [中文](./README.md)**

</div>

---

## Why This Skill Exists

Give the same question to Claude Code and Codex and two polished answers soon appear on your screen. That is when the real work begins. You carry Claude's findings into Codex, bring Codex's missing evidence back to Claude, and keep track of which objections were addressed, waved away, or silently lost during rewriting. Both models can write and review, yet the person at the keyboard becomes the wire holding the whole collaboration together.

When that manual process is automated, the wire can disappear with the person. A line-by-line audit of one real run found that 10 of 16 first-round findings survived unchanged in the other model's next draft. In that same run, a final review with no later artifact to carry it lost 100% of its findings; four of its five findings, each rated “important,” remained unchanged in the delivered answer. Three of six corrections also removed disputed material instead of fixing it. The full record is preserved in [`SKILL.md`](./SKILL.md#已知坑实测记录).

`dual-model-answer` turns that wire into an auditable workflow. Claude Code and Codex draft independently, deliver their reviews directly to the model under review, respond to every numbered finding, and preserve answers, body diffs, dispositions, and final checks. You provide one prompt and receive two independent final answers plus a table showing what converged and what remains disputed. The goal is stronger factual confidence and traceability; model agreement never substitutes for evidence.

## How It Works

The default workflow runs two cross-review rounds followed by a review-only final check:

```text
One prompt
   │
   ├── Claude drafts v1 independently
   └── Codex  drafts v1 independently
             │
             ▼
       Bidirectional review
       ├── The other review fixes weaknesses
       └── The other answer fills omissions
             │
             ▼
          Two v2 drafts
             │
       Review and revise again
             │
             ▼
          Two v3 finals
             │
       Review-only final check
             │
             ▼
       Consensus and disagreements
```

Four design choices close the loop:

| Design | Purpose |
|---|---|
| **Round-one material isolation** | Both models see only the same prompt, reducing initial anchoring |
| **Two delivery channels** | The other model's review repairs weaknesses; its full answer exposes substantive omissions |
| **One artifact per step** | Every answer, review, revision, and final check remains separate, preserving a traceable chain from inputs to dispositions and removing the old slicing path created by stacking multiple documents in one file and routing agents by section boundaries |
| **Diffs and final review** | Diffs expose silent regressions and deletion-as-revision; the final check preserves findings that cannot enter another draft |

File separation is a delivery boundary, not a per-file access sandbox. Round-one blindness still depends on the orchestrator providing only the original prompt and on each agent respecting the material boundary.

Every finding receives a stable ID. A revising model must mark it as accepted, rejected, or disputed. Rejections require evidence, while disputes must be identified as factual or framing-level disagreements. Review documents also contain a “worth absorbing” section that carries reusable evidence and arguments from the other answer, avoiding duplicated verification. Stable IDs and a closed disposition vocabulary allow the final consensus table to be extracted mechanically, with every row traceable to a source document and no ad hoc orchestrator judgment mixed in.

The workflow delivers two independent final answers and a disagreement record instead of merging differently sourced judgments into an artificially uniform answer.

## Installation

> **Two prerequisites, with different roles.**
> **Claude Code is the only orchestrator.** It dispatches the independent subtasks, runs the shell commands, and writes every artifact — full execution belongs to Claude Code. Other harnesses may discover the shared skill, prepare materials, and hand off; discovery does not mean they can execute the full workflow.
> **The Codex CLI is the second model being called, and does not need this skill installed.** It only has to be [present and authenticated](https://learn.chatgpt.com/docs/codex/cli) locally: `codex --version` checks the installation, `codex login status` shows the active authentication method. If Codex is unavailable, the workflow stops transparently instead of presenting single-model output as dual-model work.

**Option 1 · One command (recommended)**

```bash
npx skills add HoraceLuBFA/dual-model-answer -g -a claude-code
```

[`npx skills`](https://github.com/vercel-labs/skills) accepts GitHub sources in `owner/repo` form; `-g` selects user-level installation, and `-a claude-code` restricts the target to Claude Code — other agents that discover a shared installation can use it to check prerequisites and prepare a handoff.

After installing, check three things: the skill, the Codex binary, and Codex authentication.

```bash
npx skills ls -g -a claude-code
codex --version
codex login status
```

**Option 2 · Ask your agent to install it**

Send the repository URL to Claude Code:

> Install this skill for me (Claude Code only): https://github.com/HoraceLuBFA/dual-model-answer

**Option 3 · Clone it manually**

Claude Code reads personal skills from `~/.claude/skills/`, so clone straight into it:

```bash
mkdir -p ~/.claude/skills

git clone https://github.com/HoraceLuBFA/dual-model-answer.git \
  ~/.claude/skills/dual-model-answer
```

If you prefer keeping the canonical copies of shared skills under `~/.agents/skills/`, clone there and add a symlink instead — Claude Code accepts an entry that points elsewhere and follows it:

```bash
git clone https://github.com/HoraceLuBFA/dual-model-answer.git \
  ~/.agents/skills/dual-model-answer

ln -s ~/.agents/skills/dual-model-answer \
  ~/.claude/skills/dual-model-answer
```

Verify the discovery path and the runtime dependency:

```bash
test -f ~/.claude/skills/dual-model-answer/SKILL.md && \
  test -f ~/.claude/skills/dual-model-answer/scripts/dma-lib.sh && \
  codex --version && \
  codex login status && \
  echo OK
```

## Usage

**Explicit invocation**

```text
# Inside Claude Code: slash command
/dual-model-answer Evaluate approach X versus Y for our use case
```

You never open a Codex window yourself: the orchestrator starts a fresh `codex exec` session for each step, passes material by file path, and writes the collected body to disk.

**Natural-language invocation**

```text
Use dual-model-answer on the following question with two review rounds:

How should a local-first note-taking application design its sync architecture?
Compare at least three approaches, verify the key technical claims, and state
the operating boundaries of each.
```

You may also specify the number of rounds, parent output directory, topic name, Codex model, or reasoning effort. Unless a parent directory is specified, artifacts are written to a new `dual-model-answer/` folder under the current working directory. The topic name is normally a two-to-eight-character summary of the prompt and follows the prompt language. The rigor tier is inferred from the task: research-tier answers require citations and a formatted bibliography, while general-tier answers do not require numbered citations but still need verifiable grounds for factual claims.

> ⚠️ **This is a heavyweight workflow.** The default two review rounds plus final check require about 12 model calls and produce 14 traceable files. Codex usage follows the CLI's active authentication method: ChatGPT sign-in uses the applicable subscription access, while API-key sign-in is billed at standard API rates. The skill announces the configuration before starting.

## Good Fits

Use this skill when the answer deserves additional model calls and stronger factual scrutiny:

- research, technical choices, and contested questions;
- reports, proposals, articles, and important public-facing copy;
- code interpretation, architecture analysis, and difficult knowledge work;
- content requiring systematic checks of citations, attribution, terminology, numbers, dates, or overstrong claims.

Use a more direct workflow when:

| Situation | Better fit |
|---|---|
| A document already exists and needs multi-perspective scrutiny | `cross-review` |
| The task requires planning, implementation, and code validation | `dual-model-dev` |
| An existing code diff needs review | `code-review` |
| The question is simple and low risk | A single model is usually more economical |

## Requirements and Limits

- Claude Code is the only orchestrator: the workflow depends on its ability to dispatch independent subtasks and run shell commands, while other harnesses may prepare a handoff;
- the Codex CLI must be present and authenticated locally as the second model being called; it does not need this skill installed;
- factual verification is read-only, except that PDFs needed for page checks may be downloaded to a temporary directory;
- if Claude or Codex fails, the workflow retries once and then pauses with an honest report;
- writes remain confined to the current run's output directory and temporary files;
- two models can agree and still be wrong, so consensus is a lead rather than proof;
- existing-document review, repository development, and diff review have dedicated workflows.

## Deliverables

The default run preserves the complete chain instead of keeping only the final answers:

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

One artifact per step also makes interrupted runs recoverable: lexical file order mirrors pipeline order, and the missing file pair identifies where to resume.

Start with:

1. `05 Claude answer v3.md` and `05 Codex answer v3.md` for the two independent final answers;
2. `06 Claude 终审意见.md` and `06 Codex 终审意见.md` for issues that still deserve caution;
3. `07 共识与分歧.md` for converged findings, evidence-backed rejections, unresolved disagreements, and uncorrected final-review findings.

The orchestrator writes each document's frontmatter, recording the producing model, transport, source files, review target, and version relationship. A v1 answer preserves authorial intent in its tradeoff memo. From v2 onward, each revised answer also includes revision notes that disposition every incoming finding by ID. This keeps the evidence traceable without allowing a later reviser to mistake a deliberate restraint for a defect.

Artifact filenames are fixed by `SKILL.md` and do not change with the prompt language; the final-review and consensus files keep the Chinese names shown above. Only the body text of each document follows the language of the prompt.

## Repository Layout

```text
dual-model-answer/
├── SKILL.md                    # Workflow contract, orchestration rules, and safety boundaries
├── README.md                   # Chinese documentation
├── README.en.md                # English documentation
├── references/
│   └── templates.md            # Draft, review, revision, and final-review templates
├── scripts/
│   └── dma-lib.sh              # Extraction, diff, invocation, validation, and write helpers
└── LICENSE
```

The project follows the [Agent Skills specification](https://agentskills.io/specification): `SKILL.md` contains metadata and workflow instructions, while detailed templates and executable helpers live in `references/` and `scripts/`.

The helper library also protects three operations that can otherwise fail silently. Long prompts go through stdin to avoid inline truncation. Codex completion is judged by a non-empty collected output rather than an unreliable wrapper exit code. Connectivity smoke tests inspect the session rollout instead of treating an incomplete log as evidence that no tools ran. Implementation details and measured observations remain in the comments of `scripts/dma-lib.sh`.

## Acknowledgements and License

Thanks to [Claude Code](https://code.claude.com/docs/en/overview), [OpenAI Codex](https://learn.chatgpt.com/docs/codex/cli), and the open [Agent Skills](https://agentskills.io/) ecosystem.

The skill's code, prompts, and organization are released under the [MIT License](https://opensource.org/license/mit). You may use, modify, and redistribute them subject to preservation of the copyright and license notices. See [LICENSE](./LICENSE) for the complete terms.

## Model identity and completion

Claude and Codex are workflow roles and artifact labels. Check the actual provider, model, and available invocation method before execution. If both roles use the same backend model, report that fact without claiming cross-model verification. Complete all agreed review rounds and the final check by default; stop at early convergence only when the user has chosen that mode. Count a step as complete only after its subprocess exits successfully and produces a fresh, nonempty artifact that meets the document protocol.
