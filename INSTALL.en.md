# dual-model-answer installation guide

Source repository: https://github.com/HoraceLuBFA/dual-model-answer
Detail page: https://www.lumenghe.com/en/skills/dual-model-answer/
Release metadata: https://www.lumenghe.com/skills/dual-model-answer/release.json
Current package and checksum: https://www.lumenghe.com/en/skills/dual-model-answer/install.txt

Use the detail page or release metadata to select the version, source commit, ZIP URL, and SHA-256. Record these values together before downloading. Follow this guide within the user's authorization and preserve existing installations and local changes.

## Before installation

1. Identify the operating system, coding agent, and host; read the README and prerequisites. Only Claude Code may orchestrate this skill. Check that the local Codex CLI is installed and authenticated with codex --version and codex login status. Codex does not need this skill installed. Do not start sign-in automatically or run a complete multi-model task just to verify installation.
2. Inspect ~/.agents/skills/dual-model-answer and same-named host entries without modifying them, including files, directories, symlinks, and broken symlinks. If an installation exists, report its version and local changes. Back it up and let the user choose how to merge or replace it; never silently overwrite, delete, or reset it. Do not alter unrelated host settings, other skills, or existing authentication.
3. Download the complete ZIP from the HTTPS download URL in the selected release metadata into a temporary working directory. Compute its SHA-256 and compare it exactly with the current site release information. Stop if the digest is missing, still a template placeholder, or different. The README also provides GitHub installation routes; use the route selected for this installation.

## Extract and install

4. Inspect ZIP member paths before extraction. Require a single dual-model-answer/ root directory; reject absolute paths, .. traversal, and links that would write outside the destination. The complete package must contain dual-model-answer/SKILL.md, README.md, README.en.md, LICENSE, and the original supporting scripts and references. Do not download SKILL.md alone.
5. Extract into a temporary directory and inspect the file list. Preserve relative structure and executable permissions; do not install an extra dual-model-answer/dual-model-answer/ nesting level. After confirming that the target does not exist, place the complete dual-model-answer/ folder at ~/.agents/skills/dual-model-answer/. Existing instructions and scripts refer to this canonical shared path, so do not relocate it casually.
6. Configure discovery for the actual host. Codex reads personal skills from ~/.agents/skills; Claude Code reads personal entries from ~/.claude/skills. Only when ~/.claude/skills/dual-model-answer does not exist and is not a broken symlink, create a symlink pointing to ~/.agents/skills/dual-model-answer. Inspect and report existing entries instead of replacing them. Follow current official documentation for other hosts; do not claim every agent automatically scans the shared directory.

## Verify and report

7. Check that SKILL.md and the required scripts and references are readable, with the necessary executable permissions. Confirm discovery through the host's skill list, an explicit invocation, or a new session. Distinguish files installed, skill discovered, dependencies ready, and a real task accepted; report only the checks actually performed. Do not start a complete dual-model run to verify installation.
8. Report the installation directory, source version and commit, downloaded checksum, discovery result, missing dependencies, and any backup location retained for an existing installation. Do not expose authentication values. Leave any interactive sign-in to the user.

Discovery references:
- Official OpenAI documentation: https://learn.chatgpt.com/docs/build-skills
- Claude Code documentation: https://code.claude.com/docs/en/skills
