# Subagents — when asks stack up

- **When unaddressed asks queue faster than they complete** — roughly 3+ outstanding, or new ones arriving mid-task — stop, review the queue, and dispatch subagents instead of grinding through serially. Genuinely trivial edits stay inline.
- **Check file overlap before parallelising.** Group asks by the files they touch: disjoint sets run in parallel (one message, multiple tool calls), overlapping sets run sequentially. Say which you chose and why.
- **Give each subagent the full brief** — it starts with no context: worktree path, where the code lives, test framework and location, comment conventions, no ticket numbers in comments, the exact verify commands, and an explicit "do not commit, do not disturb other uncommitted work".
- **Require evidence.** Each subagent runs the type-check and tests and pastes real output. Relay what matters — I never see their report.
