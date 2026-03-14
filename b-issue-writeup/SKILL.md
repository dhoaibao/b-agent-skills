---
name: b-issue-writeup
description: Generate concise, structured PR or task descriptions for developers. Use this skill whenever the user wants to write a PR description, task description, issue writeup, or ticket summary — even if they just say "help me write this up", "tao description cho cai nay", "viet PR desc", or paste code/errors/ticket content and ask for a writeup. Trigger this skill any time the user needs to communicate a technical change or problem clearly to their team.
---

# b-issue-writeup

Generate a concise, structured description for PRs or tasks that helps teammates (especially team leads) understand the issue at a glance.

## Output Structure

Always use this exact structure — no more, no fewer sections:

```
## Problem
[What went wrong + root cause in 1–3 sentences]

## Solution
[How it was fixed + why this approach, in 1–3 sentences]

## Scope & Testing
[Affected environments + what was tested, as short bullets]

Ticket: [link or N/A]
```

## Rules

- **Language**: Match the user's language (Vietnamese or English). If the final writeup should be in English (common for PRs), write it in English unless told otherwise.
- **Tone**: Professional, concise, developer-friendly. No fluff.
- **Length**: Keep each section tight — 1 to 3 sentences max. Bullet points only in Scope & Testing.
- **Problem**: Combine symptom + root cause in one block. Do not split into two sections.
- **Solution**: Mention the approach and briefly why it was chosen if relevant.
- **Scope & Testing**: Extract from conversation if mentioned. If partially available, fill what you can and ask only for what's missing (e.g., "Which environments are affected?" or "Did you test on Beta?"). Never ask for info that's already clear from context.
- **Ticket**: Include if provided, otherwise write `N/A`.

## Input Types

Handle any of the following inputs and extract relevant info:

- **Conversation context** (most common): User has already debugged and fixed the issue in this conversation. Read the full conversation history to extract: what the problem was, what was tried, what the final fix was, and any mentioned environments or ticket links. Do NOT ask the user to re-explain anything that's already in the conversation.
- **Plain description**: User explains the task or bug in their own words
- **Code / error paste**: Infer the problem and fix from the code context
- **Ticket content**: Extract and reframe into the structure above
- **Mixed**: Combine all available info

When triggered at the end of a conversation, always prefer extracting from conversation history first before asking for any clarification.

## Example

**Input:**
> Audio streams from the voicemail API don't have Content-Length header so browser shows Infinity duration and progress bar breaks. Fixed by falling back to API duration when audio.duration is invalid. Only happens in Dev.

**Output:**
```
## Problem
Audio streams from the voicemail API lack a `Content-Length` header, causing the browser to report an invalid duration (Infinity) and the progress bar to behave incorrectly.

## Solution
Fall back to the voicemail API duration when `audio.duration` is invalid (Infinity or NaN) to calculate playback progress correctly.

## Scope & Testing
- Affected: Dev only (Beta & Prod unaffected)
- Verified progress bar renders correctly in Dev

Ticket: N/A
```
