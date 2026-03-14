---
name: b-git-convention
description: Check and fix commit messages and branch names against conventions. Use this skill whenever the user mentions a commit message, branch name, wants to write a commit, name a branch, asks if a commit/branch is valid, or says things like "check my commit", "is this branch name ok", "write a commit for...", "what should I name this branch", or pastes something that looks like a git commit or branch name. Always trigger for any git workflow writing task.
---

# Commit Convention Checker

Checks and corrects commit messages and branch names according to the project's conventions.

## Conventions

### Commit Messages — Conventional Commits

**Format:**
```
<type>(<optional scope>): <short description>

[optional body]

[optional footer]
```

**Allowed types:**
| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `chore` | Maintenance, deps, config (no production code change) |
| `refactor` | Code restructure without behavior change |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `test` | Adding or updating tests |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `build` | Build system changes |
| `revert` | Reverting a previous commit |

**Rules:**
- Type must be lowercase
- Colon + single space after type/scope: `feat: ` not `feat:message` or `feat : message`
- Description starts lowercase (no capital first letter)
- No period at end of description
- Description is imperative mood: "add button" not "added button" or "adds button"
- Max 72 characters for the subject line
- Scope (if used) is lowercase, in parentheses: `feat(auth): add login`
- Breaking changes: add `!` after type or `BREAKING CHANGE:` in footer

**Valid examples:**
```
feat: add voicemail playback button
fix(cti): resolve callback notification timing issue
chore: update dependencies
refactor(agent): simplify call routing logic
feat!: redesign CTI agent screen (breaking change)
```

**Invalid examples:**
```
Added login button           → missing type
feat:add login button        → missing space after colon
Feat: Add login button       → type capitalized, description capitalized
feat: Add login button.      → description capitalized + trailing period
fixed the bug                → missing type, past tense
feat: added new feature      → past tense (should be imperative)
```

---

### Branch Names

**Format:**
```
<type>/<ticket-id>/<short-description>
```

**Rules:**
- Type must match one of the Conventional Commits types above
- Ticket ID format: `UPPERCASE-NUMBER` (e.g., `INT-123`, `CTI-456`)
- Short description: lowercase, hyphen-separated words, no spaces or special chars
- No trailing slashes or hyphens
- Keep description concise (2–5 words ideal)

**Valid examples:**
```
feat/INT-123/voicemail-playback
fix/CTI-456/callback-notification
chore/INT-789/update-deps
refactor/CTI-101/simplify-routing
```

**Invalid examples:**
```
feature/INT-123/voicemail-playback   → "feature" not a valid type (use "feat")
feat/int-123/voicemail-playback      → ticket ID must be uppercase
feat/INT-123/Voicemail-Playback      → description must be lowercase
fix/callback-notification            → missing ticket ID
feat/INT-123/voicemail_playback      → underscores not allowed (use hyphens)
```

---

## Workflow

### Mode 1: Input provided — Check & fix

User provides a commit message or branch name explicitly.

1. **Identify** what was given (commit, branch, or both)
2. **Validate** against the rules above
3. **Report** clearly:
   - ✅ Valid — confirm it's correct and briefly explain why
   - ❌ Invalid — list each violation with a short explanation
4. **Suggest** a corrected version (always, even if only one thing was wrong)

---

### Mode 2: No input provided — Auto-generate from conversation history

User asks to "write a commit", "tạo commit", "generate branch" etc. without providing specific text.

1. **Scan the current conversation** to understand what changes were made or discussed:
   - What problem was solved or feature was built?
   - What files, components, or systems were touched?
   - Any ticket/issue IDs mentioned (e.g., INT-123, CTI-456)?
2. **Infer the correct type** from the nature of the work (bug fix → `fix`, new feature → `feat`, etc.)
3. **Generate** both commit message and branch name
4. If a ticket ID was mentioned in conversation, use it. If not, use a placeholder like `XXX-000` and note that the user should replace it.
5. If the conversation context is too vague to generate a meaningful commit, ask one focused question: "Bạn đang làm gì trong task này?"

**Do NOT ask multiple questions** — make your best inference from context and generate immediately. The user can correct if needed.

---

## Output Format

Always structure output like this:

### For checking:
```
**Commit message:** `<input>`
Status: ✅ Valid  /  ❌ Invalid

Issues:
- [issue 1]
- [issue 2]

Suggested: `<corrected version>`
```

### For generating:
```
**Branch:** `feat/INT-123/short-description`
**Commit:** `feat: short description of change`
```

Keep responses concise. No lengthy explanations unless the user asks.
