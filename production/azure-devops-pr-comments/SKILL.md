---
name: azure-devops-pr-comments
description: Read and manage comment threads on the active Azure DevOps pull request for a branch. Use when a user wants to list, add, reply to, edit, resolve, or delete Azure DevOps PR comments. Do not use for GitHub or other pull request providers.
---

# Azure DevOps PR comments

Use the bundled PowerShell script to work with comment threads on the single active pull request whose source branch matches the requested branch.

## Credentials

Ask for the path to a local environment file if the user has not supplied one. Never ask the user to paste a personal access token into chat, place a token in the skill, or print the environment file.

The file may use either `NAME=value` or `Name: value` entries. It must define:

```text
AZURE_DEVOPS_ORGANIZATION=contoso
AZURE_DEVOPS_PROJECT=WebApp
AZURE_DEVOPS_REPOSITORY=api-service
AZURE_DEVOPS_PAT=your-personal-access-token
```

The script also accepts `Organization`, `Project`, `Repository`, `Token`, and `AZDO_PAT`. Listing needs Azure DevOps Code (Read) permission. Mutations need Code (Read & write).

## Run the script

Invoke `scripts/AzureDevOpsPullRequestComments.ps1` with `-EnvFile` and `-BranchName`. A branch may be written as `feature/name` or `refs/heads/feature/name`.

List active comments:

```powershell
& scripts/AzureDevOpsPullRequestComments.ps1 -EnvFile <path> -BranchName <branch>
```

Use `-All` to include inactive threads and `-Raw` to return JSON.

The mutation switches are:

- Add a thread with `-Comment <text>`.
- Reply with `-ThreadId <id> -CommentId <id> -Reply -Comment <text>`.
- Edit with `-ThreadId <id> -CommentId <id> -Edit -Comment <text>`.
- Resolve with `-ThreadId <id> -Resolve`.
- Delete with `-ThreadId <id> -CommentId <id> -Delete`.

Perform a mutation only when the user explicitly requests that action. Before editing, resolving, or deleting, use the read operation to identify the exact thread and comment unless the user already supplied those IDs. Do not infer a destructive action from a general request to manage or clean up comments.

The script stops if the branch has no active pull request or more than one active pull request. Report that result instead of guessing another branch or pull request.

## Output

Return the affected thread and comment IDs plus the action result. Do not expose authorization headers, token values, or the environment file contents.
