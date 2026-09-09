[CmdletBinding(DefaultParameterSetName = 'Read')]
param(
  [Parameter(Mandatory)]
  [string]$EnvFile,

  [Parameter(Mandatory)]
  [string]$BranchName,

  [Parameter(Mandatory, ParameterSetName = 'Add')]
  [Parameter(Mandatory, ParameterSetName = 'Reply')]
  [Parameter(Mandatory, ParameterSetName = 'Edit')]
  [string]$Comment,

  [Parameter(Mandatory, ParameterSetName = 'Reply')]
  [Parameter(Mandatory, ParameterSetName = 'Edit')]
  [Parameter(Mandatory, ParameterSetName = 'Resolve')]
  [Parameter(Mandatory, ParameterSetName = 'Delete')]
  [int]$ThreadId,

  [Parameter(Mandatory, ParameterSetName = 'Reply')]
  [Parameter(Mandatory, ParameterSetName = 'Edit')]
  [Parameter(Mandatory, ParameterSetName = 'Delete')]
  [int]$CommentId,

  [Parameter(Mandatory, ParameterSetName = 'Reply')]
  [switch]$Reply,

  [Parameter(Mandatory, ParameterSetName = 'Edit')]
  [switch]$Edit,

  [Parameter(Mandatory, ParameterSetName = 'Resolve')]
  [switch]$Resolve,

  [Parameter(Mandatory, ParameterSetName = 'Delete')]
  [switch]$Delete,

  [Parameter(ParameterSetName = 'Read')]
  [switch]$Raw,

  [Parameter(ParameterSetName = 'Read')]
  [switch]$All
)

<#
.SYNOPSIS
Reads, adds, replies to, edits, resolves, and deletes Azure DevOps pull request comments.

.DESCRIPTION
The environment file must contain the Azure DevOps connection values:

  AZURE_DEVOPS_ORGANIZATION=contoso
  AZURE_DEVOPS_PROJECT=WebApp
  AZURE_DEVOPS_REPOSITORY=api-service
  AZURE_DEVOPS_PAT=your-personal-access-token

The aliases Organization, Project, Repository, Token, and AZDO_PAT are also accepted.
Use a token with Code (Read & write) permission for mutations, or Code (Read) to
list comments.

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -All

Shows active comments by default. Use -All to include resolved, closed, and other
non-active comment threads.

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -Comment 'Comment added by AzureDevOpsPullRequestComments.ps1'

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -ThreadId 123 -CommentId 1 -Reply -Comment 'Reply to comment 1'

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -ThreadId 123 -CommentId 1 -Edit -Comment 'Replacement text'

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -ThreadId 123 -Resolve

.EXAMPLE
.\AzureDevOpsPullRequestComments.ps1 -EnvFile .\azure.env `
  -BranchName feature/fix-validation `
  -ThreadId 123 -CommentId 1 -Delete
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EnvironmentValue {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string[]]$Names
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Environment file '$Path' does not exist."
  }

  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmedLine = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#') -or $trimmedLine.StartsWith(';') -or $trimmedLine -match '^=+.*=+$') {
      continue
    }

    if ($trimmedLine -notmatch '^\s*(?:export\s+)?(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:=|:)\s*(?<value>.*)\s*$') {
      throw "Environment file '$Path' has an invalid entry: '$line'"
    }

    $value = $Matches.value.Trim()
    if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    $values[$Matches.name] = $value
  }

  foreach ($name in $Names) {
    if (-not [string]::IsNullOrWhiteSpace($values[$name])) {
      return $values[$name]
    }
  }

  throw "Environment file '$Path' must define one of: $($Names -join ', ')."
}

function Get-OptionalPropertyValue {
  param(
    [AllowNull()] [object]$Object,
    [Parameter(Mandatory)] [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) {
    return $property.Value
  }

  return $null
}

$token = Get-EnvironmentValue -Path $EnvFile -Names @('AZURE_DEVOPS_PAT', 'AZDO_PAT', 'Token')
$organization = [uri]::EscapeDataString((Get-EnvironmentValue -Path $EnvFile -Names @('AZURE_DEVOPS_ORGANIZATION', 'Organization')))
$project = [uri]::EscapeDataString((Get-EnvironmentValue -Path $EnvFile -Names @('AZURE_DEVOPS_PROJECT', 'Project')))
$repository = [uri]::EscapeDataString((Get-EnvironmentValue -Path $EnvFile -Names @('AZURE_DEVOPS_REPOSITORY', 'Repository')))
$branch = $BranchName.Trim()
if ($branch.StartsWith('refs/heads/', [System.StringComparison]::OrdinalIgnoreCase)) {
  $branch = $branch.Substring('refs/heads/'.Length)
}
if ([string]::IsNullOrWhiteSpace($branch)) {
  throw 'BranchName must name a branch, for example feature/fix-validation.'
}

$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$token"))
$headers = @{ Authorization = "Basic $basicAuth"; Accept = 'application/json' }
$pullRequestsUri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullrequests?searchCriteria.sourceRefName=$([uri]::EscapeDataString("refs/heads/$branch"))&searchCriteria.status=active&api-version=7.1"
$pullRequests = Invoke-RestMethod -Method Get -Uri $pullRequestsUri -Headers $headers
$activePullRequests = @($pullRequests.value | Where-Object { $null -ne $_ })
if ($activePullRequests.Count -eq 0) {
  throw "No active pull request was found for branch '$branch'."
}
if ($activePullRequests.Count -gt 1) {
  $pullRequestIds = $activePullRequests.pullRequestId -join ', '
  throw "Found $($activePullRequests.Count) active pull requests for branch '$branch': $pullRequestIds. Use a branch with exactly one active pull request."
}

$pullRequestId = $activePullRequests[0].pullRequestId
$threadsUri = "https://dev.azure.com/$organization/$project/_apis/git/repositories/$repository/pullRequests/$pullRequestId/threads"
$uri = "${threadsUri}?api-version=7.1"
$threadUri = "$threadsUri/$ThreadId"
$commentUri = "$threadUri/comments/$CommentId"
$commentUriWithApiVersion = "${commentUri}?api-version=7.1"
$threadCommentsUri = "$threadUri/comments?api-version=7.1"

switch ($PSCmdlet.ParameterSetName) {
  'Add' {
    $body = @{
      comments = @(@{
        parentCommentId = 0
        content = $Comment
        commentType = 1
      })
      status = 1
    } | ConvertTo-Json -Depth 4

    $createdThread = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body
    $createdComment = $createdThread.comments | Select-Object -First 1
    [pscustomobject]@{
      Action = 'Added'
      ThreadId = $createdThread.id
      CommentId = $createdComment.id
      Author = $createdComment.author.displayName
      Content = $createdComment.content
      PublishedDate = $createdComment.publishedDate
    }
    return
  }

  'Reply' {
    $body = @{
      parentCommentId = $CommentId
      content = $Comment
      commentType = 1
    } | ConvertTo-Json
    $replyResponse = Invoke-RestMethod -Method Post -Uri $threadCommentsUri -Headers $headers -ContentType 'application/json' -Body $body
    [pscustomobject]@{
      Action = 'Replied'
      ThreadId = $ThreadId
      CommentId = $replyResponse.id
      ParentCommentId = $replyResponse.parentCommentId
      Content = $replyResponse.content
      PublishedDate = $replyResponse.publishedDate
    }
    return
  }

  'Edit' {
    $body = @{ content = $Comment } | ConvertTo-Json
    $updatedComment = Invoke-RestMethod -Method Patch -Uri $commentUriWithApiVersion -Headers $headers -ContentType 'application/json' -Body $body
    [pscustomobject]@{
      Action = 'Edited'
      ThreadId = $ThreadId
      CommentId = $updatedComment.id
      Content = $updatedComment.content
      LastUpdatedDate = $updatedComment.lastUpdatedDate
    }
    return
  }

  'Resolve' {
    $resolvedThread = Invoke-RestMethod -Method Patch -Uri "${threadUri}?api-version=7.1" -Headers $headers -ContentType 'application/json' -Body (@{ status = 'fixed' } | ConvertTo-Json)
    [pscustomobject]@{
      Action = 'Resolved'
      ThreadId = $resolvedThread.id
      Status = $resolvedThread.status
    }
    return
  }

  'Delete' {
    Invoke-RestMethod -Method Delete -Uri $commentUriWithApiVersion -Headers $headers | Out-Null
    [pscustomobject]@{
      Action = 'Deleted'
      ThreadId = $ThreadId
      CommentId = $CommentId
    }
    return
  }
}

$threads = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
$displayThreads = @($threads.value | Where-Object {
  $threadStatus = Get-OptionalPropertyValue -Object $_ -Name 'status'
  $All -or $threadStatus -eq 'active' -or $threadStatus -eq 1
})
if ($Raw) {
  [pscustomobject]@{ count = $displayThreads.Count; value = $displayThreads } | ConvertTo-Json -Depth 20
  return
}

$displayThreads | ForEach-Object {
  $thread = $_
  $threadStatus = Get-OptionalPropertyValue -Object $thread -Name 'status'
  $thread.comments | ForEach-Object {
    $commentAuthor = Get-OptionalPropertyValue -Object $_ -Name 'author'
    [pscustomobject]@{
      ThreadId = Get-OptionalPropertyValue -Object $thread -Name 'id'
      Status = $threadStatus
      CommentId = Get-OptionalPropertyValue -Object $_ -Name 'id'
      Author = Get-OptionalPropertyValue -Object $commentAuthor -Name 'displayName'
      PublishedDate = Get-OptionalPropertyValue -Object $_ -Name 'publishedDate'
      Content = Get-OptionalPropertyValue -Object $_ -Name 'content'
    }
  }
} | Format-Table -Wrap -AutoSize
