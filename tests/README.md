# HiClaw Integration Tests

Automated integration test suite that validates all 10 POC acceptance cases.

## Architecture

Tests simulate human interaction by calling the Matrix API directly, then verify system responses and side effects:

```
Test Script                     HiClaw System
    │                               │
    ├── Matrix API: send message ──>│ Manager Agent processes
    │                               │ (creates Worker, assigns task, etc.)
    ├── poll Matrix API for reply <─│
    ├── verify reply content        │
    ├── verify Higress Console ────>│ (Consumer created? Route updated?)
    ├── verify MinIO files ────────>│ (SOUL.md written? task/spec.md?)
    └── PASS / FAIL                 │
```

## Test Cases

| Test | POC Case | Description |
|------|----------|-------------|
| test-01 | Case 1 | Manager boot, all services healthy, IM login |
| test-02 | Case 2 | Create Worker Alice via Matrix conversation |
| test-03 | Case 3 | Assign task, Worker completes |
| test-04 | Case 4 | Human intervenes with supplementary instructions |
| test-05 | Case 5 | Heartbeat triggers Manager inquiry |
| test-06 | Case 6 | Create Bob, collaborative task |
| test-07 | Case 7 | Credential smooth rotation |
| test-08 | Case 8 | GitHub operations via MCP Server |
| test-09 | Case 9 | Multi-Worker GitHub collaboration |
| test-10 | Case 10 | MCP permission dynamic revoke/restore |
| project-collaboration | Feature | Multi-round git project: developer + reviewer + tester |

## Project Collaboration Test

The `project-collaboration/` directory contains a long-running end-to-end test for the project management skill. It is **opt-in** due to its long runtime (up to 1 hour).

See `project-collaboration/README.md` for details.

### Run the project collaboration test

```bash
# Standalone
./tests/project-collaboration/run-test.sh

# As part of run-all-tests.sh
./tests/run-all-tests.sh --include-project-test
```

## Running Tests

### Full Suite

```bash
./tests/run-all-tests.sh
```

### Specific Tests

```bash
./tests/run-all-tests.sh --test-filter "01 02 03"
```

### Skip Image Build

```bash
./tests/run-all-tests.sh --skip-build
```

## Required Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `HICLAW_LLM_API_KEY` | Yes | LLM API key for Agent behavior |
| `HICLAW_GITHUB_TOKEN` | No | GitHub PAT for tests 08-10 |

## Helper Libraries

- `lib/test-helpers.sh`: Assertions, lifecycle, logging, Docker helpers
- `lib/matrix-client.sh`: Matrix API wrapper (register, login, send/read messages)
- `lib/higress-client.sh`: Higress Console API wrapper (consumers, routes, MCP)
- `lib/minio-client.sh`: MinIO verification (file existence, content, listing)
