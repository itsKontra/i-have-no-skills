---
name: codegraph-analysis
description: >-
  Delegate factual CodeGraph exploration when the main agent needs to understand
  an existing codebase: trace request, data, or control flow; locate ownership
  and implementations; map dependencies or runtime wiring; or explain how
  symbols and files connect. Use for cross-file discovery that supports
  explanations, planning, implementation, or diagnosis. Keep interpretation
  and code changes in the main agent.
---

# CodeGraph analysis

Delegate one bounded code-understanding question to the custom agent named `codegraph-analysis-worker`.

The worker reconstructs existing behavior. It does not review the code, judge the design, propose improvements, or edit source files.

## When to delegate

Use this skill when the main agent needs factual, cross-file context such as:

- tracing a request, event, callback, or data transformation through the repository
- finding where an interface is implemented and how runtime wiring selects it
- identifying callers, callees, dependencies, ownership, or project boundaries
- explaining how named symbols, files, or modules connect
- gathering structural evidence before the main agent plans a change or diagnoses a failure

Handle a lookup directly when the answer is already in context or only requires reading one known file. Keep implementation, design decisions, code review, security analysis, root-cause judgment, and recommendations in the main agent.

## Workflow

1. Form one concrete exploration question. Include named endpoints or symbols when known.
2. Spawn exactly one `codegraph-analysis-worker` with `fork_context: false`. Do not pass message history.
3. Give it only the repository root, the exploration question, relevant symbol or file anchors, and any explicit output request.
4. Wait for its result. Reuse the same worker for a closely related follow-up instead of spawning another one.
5. Use the returned evidence in the main task. Do not repeat the exploration unless the worker reports stale, missing, or ambiguous index data.

## Worker prompt

Use a compact prompt with these fields when known:

```text
Task: <one factual codebase question>
Repository root: <absolute path>
Anchors: <symbols, files, projects, or endpoints>
Requested detail: <summary, call path, ownership map, or other factual result>
Full files requested: <none by default, or exact files explicitly requested by the user>
Constraints: <relevant repository instructions>
```

Do not copy the conversation, earlier answers, assumptions, or proposed conclusions into the prompt.

## Output contract

The worker should return a compact explanation backed by clickable absolute file links with one-based line references, for example:

```markdown
[Driver.cs:20](/absolute/path/Driver.cs:20)
```

Prefer line references and short excerpts over pasted source. Include full file content only when the user explicitly asks for it, and then only for files important to the answer.

Treat the worker output as structural evidence. The main agent remains responsible for conclusions outside that boundary.

## Agent configuration

The main agent resolves the `codegraph-analysis-worker` profile from its agent configuration. Change `model` or `model_reasoning_effort` in the installed TOML to configure capability and cost. The bundled default is Luna with high reasoning.

Use `scripts/install_worker.py` to install the skill and bundled worker profile. Run it without arguments for user-wide installation, or pass `--project` to install into the current repository. Use `--force` to replace an existing installation.

If `codegraph-analysis-worker` is unavailable, report that the worker profile must be installed or enabled. Do not silently substitute a history-forking agent.
