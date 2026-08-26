---
name: execute-simple-task
description: Delegate small, mechanical local development tasks to a low-cost Codex subagent and return only the requested result. Use for bounded shell or repository work such as building a project, running tests, collecting a git diff, checking command status, or summarizing a log file when the task needs little judgment. Do not use for architecture, implementation, ambiguous debugging, security review, design decisions, or other work that needs substantial reasoning.
---

# Execute simple task

Delegate one bounded task to the custom Codex agent named `simple-task-worker`.

The purpose is to keep command noise, large logs, and routine inspection out of the parent thread while using a cheaper worker model.

## Workflow

1. Confirm the request is mechanical and has a clear success condition.
2. Choose one output mode from `status`, `errors`, `summary`, or `raw`.
3. Spawn exactly one `simple-task-worker` subagent for the task.
4. Pass only the context required to execute the task. Prefer paths, refs, commands, and explicit constraints over copied file contents or conversation history.
5. Wait for the worker result.
6. Return only the requested result. Do not redo the worker's task in the parent thread.

Do not inspect large logs, diffs, build output, or test output in the parent before delegating unless the worker cannot access the source directly.

## Delegation boundary

Delegate tasks such as:

- build the current project
- run a specified unit test suite
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
Task: <one bounded action>
Working directory: <path>
Output mode: <status|errors|summary|raw>
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

Do not edit source files to make a build or test pass.

Build tools may create normal generated output such as `bin`, `obj`, `target`, or build caches. Do not treat those as source edits.

## Log rules

Give the worker the log path instead of copying the log into the parent prompt.

For large logs, tell the worker to search for error markers, exceptions, failures, timestamps, and nearby causal context before reading broad ranges.

Preserve explicit error messages exactly in the returned result.

## Worker configuration

The worker model is intentionally not configured in this skill. The main agent resolves the custom agent named `simple-task-worker` from its agent configuration.

The bundled worker uses a permission profile that keeps workspace write access and grants read access to the full filesystem. Build tools need to read SDK, package-manager, and user-level configuration outside the repository.

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
