# GitHub Operations via MCP

## Overview

This skill allows you to perform GitHub operations (manage repos, branches, files, PRs, issues) using the centralized MCP Server hosted by the Higress AI Gateway. You do NOT need a GitHub token -- the Manager has configured the MCP Server with the required credentials.

## How to Call GitHub Tools

Use `mcporter` CLI to call MCP Server tools. mcporter communicates with the Higress MCP Server endpoint via SSE transport.

### Basic Syntax

```bash
mcporter --transport http \
  --server-url "http://<AI_GATEWAY_HOST>:8080/mcp/mcp-github" \
  --header "Authorization=Bearer <YOUR_GATEWAY_KEY>" \
  call <TOOL_NAME> '<JSON_ARGUMENTS>'
```

The server URL and gateway key are configured in your `mcporter-servers.json` file. Use:

```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call <TOOL_NAME> '<JSON_ARGUMENTS>'
```

### Output

mcporter returns JSON output. Parse with `jq` for clean results.

## Available Tools

### Repository Operations

#### get_repo
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call get_repo '{"owner": "higress-group", "repo": "hiclaw"}'
```

#### list_repos
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call list_repos '{"owner": "higress-group"}'
```

#### create_repo
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call create_repo '{"name": "new-repo", "description": "A new repository", "private": false}'
```

### File Operations

#### get_file_contents
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call get_file_contents '{"owner": "higress-group", "repo": "hiclaw", "path": "README.md"}'
```

#### create_or_update_file
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call create_or_update_file '{
    "owner": "higress-group",
    "repo": "hiclaw",
    "path": "docs/new-file.md",
    "content": "# New File\nContent here...",
    "message": "Add new documentation file",
    "branch": "feature-branch"
  }'
```

#### push_files
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call push_files '{
    "owner": "higress-group",
    "repo": "hiclaw",
    "branch": "feature-branch",
    "message": "Add multiple files",
    "files": [
      {"path": "file1.md", "content": "Content 1"},
      {"path": "file2.md", "content": "Content 2"}
    ]
  }'
```

### Branch Operations

#### create_branch
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call create_branch '{"owner": "higress-group", "repo": "hiclaw", "branch": "feature-xyz", "from_branch": "main"}'
```

#### list_branches
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call list_branches '{"owner": "higress-group", "repo": "hiclaw"}'
```

### Pull Request Operations

#### create_pull_request
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call create_pull_request '{
    "owner": "higress-group",
    "repo": "hiclaw",
    "title": "Add new feature",
    "body": "This PR adds...",
    "head": "feature-branch",
    "base": "main"
  }'
```

#### list_pull_requests
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call list_pull_requests '{"owner": "higress-group", "repo": "hiclaw", "state": "open"}'
```

#### get_pull_request
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call get_pull_request '{"owner": "higress-group", "repo": "hiclaw", "pull_number": 1}'
```

### Issue Operations

#### create_issue
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call create_issue '{"owner": "higress-group", "repo": "hiclaw", "title": "Bug report", "body": "Description..."}'
```

#### list_issues
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call list_issues '{"owner": "higress-group", "repo": "hiclaw", "state": "open"}'
```

#### add_issue_comment
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call add_issue_comment '{"owner": "higress-group", "repo": "hiclaw", "issue_number": 1, "body": "Comment text"}'
```

### Search Operations

#### search_code
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call search_code '{"query": "function handleAuth", "owner": "higress-group"}'
```

#### search_repos
```bash
mcporter --config "${MCPORTER_CONFIG}" \
  call search_repos '{"query": "hiclaw language:go"}'
```

## Important Notes

- **Transport**: Use `--transport sse` (not stdio)
- **Auth**: SSE endpoint always returns 200 initially; auth check happens on `POST /message`
- **Rate limits**: GitHub API rate limits apply. If you get 403 responses, wait and retry
- **Permissions**: Your MCP access is controlled by the Manager. If you get 403 from the MCP Server, the Manager may need to re-authorize your access
