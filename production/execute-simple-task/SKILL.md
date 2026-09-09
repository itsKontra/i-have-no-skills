---
name: execute-simple-task
description: Delegate routine local development work to a low-cost Codex subagent and return only the requested result. Prefer this skill for builds, tests, factual CodeGraph analysis, command execution, Git diffs, and log inspection. Batch related mechanical commands into one delegation. Keep architecture, implementation, ambiguous debugging, security review, and design decisions in the main agent.
---

# Execute simple task

Delegate routine work to the custom Codex agent named `simple-task-worker`.

The purpose is to keep command noise, large logs, and routine inspection out of the parent thread while using a cheaper worker model.

## Workflow

1. Prefer delegation when a worker can run the request without making product or implementation decisions.
2. Combine related builds, test runs, or other mechanical checks into one task when they share a repository and reporting goal.
3. Choose one output mode from `status`, `errors`, `summary`, `analysis`, or `raw`.
4. Spawn exactly one `simple-task-worker` subagent for the task.
5. Pass only the context required to execute the task. Prefer paths, refs, commands, and explicit constraints over copied file contents or conversation history.
6. Wait for the worker result.
7. Return only the requested result. Do not redo the worker's task in the parent thread.

Do not inspect large logs, diffs, build output, or test output in the parent before delegating unless the worker cannot access the source directly.

## Delegation boundary

Delegate tasks such as:

- build one project, every project, or a solution
- run one test suite or all relevant test projects
- run a related build-and-test sequence in one worker task, such as `dotnet build` followed by `dotnet test` for all projects
- answer a factual CodeGraph question about symbols, callers, implementations, ownership, dependencies, or runtime wiring
- run a known command and report whether it succeeded
- get the git diff between two named refs
- summarize a named log file
- extract explicit errors from build, test, or runtime output

Keep the task in the parent agent when it requires:

- architecture or design decisions
- implementing or editing production code
- ambiguous debugging across several possible causes
- security analysis
- code review requiring judgment
- interpreting unclear requirements
- deciding what should be changed

If a mechanical task exposes a deeper problem, return the evidence to the parent. Do not turn the worker into a debugging agent.

## Worker prompt

Give the worker a compact prompt with these fields when they are known:

```text
Task: <one bounded action or related command group>
Working directory: <path>
Output mode: <status|errors|summary|analysis|raw>
Inputs: <paths, refs, test names, or command constraints>
Success condition: <what counts as done>
Do not: <task-specific exclusions>
```

Do not include unrelated chat history.

## Output modes

### status

Use for builds, tests, and commands where the caller mainly needs success or failure.

On success, return only:

```text
OK
```

On failure, return:

```text
FAILED
Command: <executed command>
Exit code: <code>
<exact relevant error lines>
```

Keep error text verbatim. Omit successful command noise.

### errors

Use when the caller needs failure details.

Return:

- pass or fail status
- failed test names or failed build step when available
- exact relevant error, exception, assertion, and stack-trace lines

Do not propose fixes unless explicitly requested.

### summary

Use for log inspection and other noisy read-only tasks.

Return a short factual summary followed by exact error messages that matter. Include relevant timestamps when present. Ignore repetitive informational lines.

Do not invent a root cause. If the evidence does not establish one, say that the cause is not established.

### analysis

Use for factual CodeGraph exploration. Return a compact explanation with clickable absolute file links and one-based line references. Report call paths, ownership, dependencies, or runtime wiring supported by the index. Distinguish CodeGraph output from inference and state unresolved ambiguity.

Do not review the design, recommend changes, or paste long source files unless the user explicitly requested them.

### raw

Use when the caller requests exact command output, especially git diffs.

Return stdout byte-for-byte as text as far as the agent interface permits. Do not summarize, truncate, reorder, annotate, wrap in a code fence, or add commentary.

The parent must pass the worker result through unchanged.

## Git diff rules

For a requested diff:

1. Resolve the exact refs from the user request.
2. Run the appropriate `git diff` command in the worker.
3. Use `raw` mode unless the user asked for a summary.
4. Do not read or summarize the diff in the parent.

If a ref is missing or ambiguous, report that instead of guessing another ref.

## Build and test rules

Use the repository's documented or obvious standard command. If several build systems are present and the correct command is not clear, do not guess. Return that the task is not simple enough for this skill.

Batch related build and test commands into one worker task when this avoids multiple delegations and preserves a clear result. Run them in an order that makes failures useful. For example, build before testing when the test command would otherwise repeat or obscure compilation failures. Report which command failed.

If a required command fails with a sandbox-related access or permission error, retry it with `sandbox_permissions = "require_escalated"` and a concise approval request. A sandbox denial before compilation or test execution is not a repository failure. Report `FAILED` only if escalation is denied or the escalated command also fails.

Do not edit source files to make a build or test pass.

Build tools may create normal generated output such as `bin`, `obj`, `target`, or build caches. Do not treat those as source edits.

## CodeGraph rules

Use CodeGraph before grep, file search, or broad file reads when a `.codegraph/` directory exists at the repository root. Use the CodeGraph MCP exploration tool when available, otherwise run `codegraph explore` from the repository root.

Start with one query that names the factual question and known symbols or files. Use narrow follow-up queries only when the first result leaves a material gap. If the repository has no `.codegraph/` directory, report that CodeGraph analysis is unavailable. Do not initialize an index unless the parent explicitly asks for it.

## Log rules

Give the worker the log path instead of copying the log into the parent prompt.

For large logs, tell the worker to search for error markers, exceptions, failures, timestamps, and nearby causal context before reading broad ranges.

Preserve explicit error messages exactly in the returned result.

## Worker configuration

The worker model is intentionally not configured in this skill. The main agent resolves the custom agent named `simple-task-worker` from its agent configuration.

The bundled worker profile extends `:workspace`, which keeps workspace read and write access. It also grants read access to `:home/AppData/Roaming/NuGet` for user-level NuGet configuration on Windows. Other protected paths require an escalation retry when a command needs them.

Use `scripts/install_worker.py` to install both this skill and the bundled worker profile.

User-wide installation:

```bash
python scripts/install_worker.py
```

This installs for Codex:

- `~/.agents/skills/execute-simple-task/`
- `~/.codex/agents/simple-task-worker.toml`

And for Gemini/Antigravity:

- `~/.gemini/config/skills/execute-simple-task/`
- `~/.gemini/config/agents/simple-task-worker.toml`

Project-local installation:

```bash
python scripts/install_worker.py --project
```

This installs for both:

- `.agents/skills/execute-simple-task/`
- `.codex/agents/simple-task-worker.toml` (Codex)
- `.agents/agents/simple-task-worker.toml` (Gemini/Antigravity)

Use `--force` to replace an existing installation.

Use a forced reinstall to apply worker profile updates.

Change the `model` and `model_reasoning_effort` values in the installed worker TOML to switch worker cost or capability without editing this skill.

If `simple-task-worker` is unavailable, do not silently use the parent model. Report that the worker profile needs to be installed or enabled.
