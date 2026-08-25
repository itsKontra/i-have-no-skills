# i-have-no-skills

Skills for Codex agents.

## Available skills

### `codegraph-analysis`

Delegates a focused CodeGraph exploration to a worker agent. Use it to trace code paths, locate implementations, and map how files and symbols connect. It gathers factual context only and leaves design decisions and edits to the main agent.

Location: [`production/codegraph-analysis`](production/codegraph-analysis/)

### `execute-simple-task`

Delegates one small, mechanical repository task to a worker agent. It is for jobs such as running a build or test, collecting a Git diff, checking a command, or summarizing a log. It is not for implementation, review, or ambiguous debugging.

Location: [`production/execute-simple-task`](production/execute-simple-task/)

### `unslop`

Removes common AI writing habits and replaces them with plain, specific prose.

Source: [cursor/plugins unslop skill](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop)

Local copy: [`external/unslop`](external/unslop/)

## External skills

Install skills from [mattpocock/skills](https://github.com/mattpocock/skills):

```sh
npx skills@latest add mattpocock/skills
```
