# b-agents — OpenCode Rules

## OpenCode workflow

All planning and execution happen within OpenCode:
- **Planning**: clarify requirements → `@b-plan` → writes `.opencode/b-plans/*.md`
- **Execution**: reads plan file → runs `@b-execute-plan` pipeline

Plan files live in `.opencode/b-plans/*.md`. Both are written and executed entirely within OpenCode.

## Invoking the execution pipeline

When asked to execute a plan, use the `b-execute-plan` primary agent:

```
execute plan from .opencode/b-plans/<filename>.md
```

Or simply: `execute plan` — b-execute-plan will discover the plan file automatically.

## Subagents

All skills are available as subagents:

### Orchestration
| Agent | Role |
|---|---|
| `@b-execute-plan` | Full pipeline orchestrator — reads plan file, routes to subagents, tracks state |

### Execution pipeline
| Agent | Role |
|---|---|
| `@b-tdd` | TDD enforcement — Iron Law + Red-Green-Refactor per step |
| `@b-gate` | Quality gate — lint → typecheck → tests → coverage → security → clean-code |
| `@b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |
| `@b-commit` | Generate commit message and PR description text |
| `@b-debug` | Hypothesis-driven debugging — trace root cause before fixing |
| `@b-analyze` | Deep code analysis — structure, complexity, duplication |

### Planning & research
| Agent | Role |
|---|---|
| `@b-plan` | Decompose tasks into ordered steps before coding |
| `@b-docs` | Fetch live library documentation via Context7 |
| `@b-research` | Deep research — search + scrape + synthesize report |
| `@b-quick-search` | Fast single-call web lookup |
| `@b-observe` | Static observability audit — missing logs, swallowed errors |

### Utilities
| Agent | Role |
|---|---|
| `@b-news` | Daily news digest on any topic |
| `@b-sync` | Sync skills from GitHub repo |

Invoke directly for one-off tasks:
```
@b-gate
@b-debug cannot read property of undefined at line 42
@b-analyze src/services/
@b-plan add retry logic to the email queue
@b-docs how to use Prisma transactions
```

## Plan file state sections

b-execute-plan writes to these sections to bridge state between subagent calls:

| Section | Written by | Read by |
|---|---|---|
| `## Context` | b-execute-plan (after @b-analyze) | @b-tdd before each implementation step |
| `## Last Gate Failure` | b-execute-plan (when @b-gate fails) | @b-debug when auto-debug is triggered |
| `## Review Feedback` | b-execute-plan (when @b-review returns NEEDS FIXES) | @b-tdd on re-entry |

## Git safety

Never run these commands autonomously:
- `git push`, `git pull`, `git commit`, `git reset --hard`
- `git revert`, `git clean -f`, `git branch -D`

Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.

All commits are delegated to `@b-commit` — it generates message text only, never executes git.
