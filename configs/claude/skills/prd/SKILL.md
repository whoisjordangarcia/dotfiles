---
name: prd
description: "Generate a PRD and output tasks/prd.json for Ralph autonomous execution. Use when planning a feature or starting a new project. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
user-invocable: true
---

# PRD Generator

Create a Product Requirements Document and output it as `tasks/prd.json` ready for Ralph to execute.

---

## The Job

1. Receive a feature description from the user
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate user stories based on answers
4. Save to `tasks/prd.json`
5. Create/reset `tasks/progress.txt`

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only

3. What is the scope?
   A. Minimal viable version
   B. Full-featured implementation
   C. Just the backend/API
   D. Just the UI
```

This lets users respond with "1A, 2C, 3B" for quick iteration. Remember to indent the options.

---

## Step 2: Story Sizing

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Claude instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Step 3: Story Ordering

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Step 4: Acceptance Criteria

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

### Always include as final criterion:
```
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

For stories that change UI, also include:
```
"Verify in browser using dev-browser skill"
```

---

## Output Format

Write `tasks/prd.json`:

```json
{
  "project": "[Project Name]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

Also create/reset `tasks/progress.txt`:

```
# Ralph Progress Log
Started: [current date/time]
---
```

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false`
5. **Always add**: "Typecheck passes" to every story's acceptance criteria
6. **UI stories**: Add "Verify in browser using dev-browser skill"

---

## Example

**Input:** "Add task priority system"

**Output `tasks/prd.json`:**

```json
{
  "project": "TaskApp",
  "description": "Task Priority System - Track and filter tasks by priority level",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add priority field to tasks table",
      "description": "As a developer, I need to store task priority so it persists across sessions.",
      "acceptanceCriteria": [
        "Add priority column: 'high' | 'medium' | 'low' (default 'medium')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Display priority badge on task cards",
      "description": "As a user, I want to see task priority at a glance.",
      "acceptanceCriteria": [
        "Each task card shows colored priority badge (red=high, yellow=medium, gray=low)",
        "Priority visible without hovering or clicking",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 2,
      "passes": false
    },
    {
      "id": "US-003",
      "title": "Add priority selector to task edit",
      "description": "As a user, I want to change a task's priority when editing it.",
      "acceptanceCriteria": [
        "Priority dropdown in task edit modal",
        "Saves immediately on selection change",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 3,
      "passes": false
    },
    {
      "id": "US-004",
      "title": "Filter tasks by priority",
      "description": "As a user, I want to filter the task list to see only high-priority items.",
      "acceptanceCriteria": [
        "Filter dropdown: All | High | Medium | Low",
        "Filter persists in URL params",
        "Empty state when no tasks match",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 4,
      "passes": false
    }
  ]
}
```

---

## Checklist Before Saving

- [ ] Asked clarifying questions with lettered options
- [ ] Incorporated user's answers
- [ ] User stories are small (one context window each)
- [ ] Stories ordered by dependency (schema → backend → UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill"
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] Saved to `tasks/prd.json`
- [ ] Created/reset `tasks/progress.txt`
