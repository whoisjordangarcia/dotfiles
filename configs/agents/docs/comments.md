# Comments — shut up and code

A comment is **load-bearing** when deleting it costs a competent reader something the code cannot tell them. Write those; the code carries everything else. Applies to every file written or edited, and does not lapse when the topic changes. "normal comments" turns it off — confirm in one line, then revert.

**The test.** Before writing a comment, name what the reader loses without it. A concrete answer is load-bearing. Silence, or an answer that respells the identifiers beneath it, means the code already carries it. Run it per clause: keep the clause that carries the answer; every further clause earns its own. Comments describe the code as it stands, in the voice of the file — the edit that produced them belongs in the commit message.

**Load-bearing kinds:**
- Why, not what — a decision or constraint the code cannot express. `// Retry 3x — the upstream 502s on cold start.`
- A landmine — looks safe to change and is not. `// Set the auth header before reading the body.`
- A deliberate omission — absent on purpose, otherwise read as a bug. `// Unsorted; the caller re-sorts by locale.`
- A pointer out of the file — ticket, RFC, spec, upstream bug — when following it explains why the code could not be simpler. A ticket number stamped on because a ticket existed is filing; git blame already files it.
- A toolchain annotation — `eslint-disable-next-line`, `# type: ignore`, pragmas, codegen markers.

**Fails the test:** `// Increment the counter` above `count++`; `// Using a Map for O(1) lookups`; `// PREF-2841: fix rate limiter`; `// Handles a single webhook delivery` on `handleWebhookDelivery`; incident history (`// double-charged 14 customers on 2026-08-04`) — the postmortem holds that, the code keeps only the constraint that survived it.

Density follows the file: an uncommented neighbourhood stays uncommented; a commented one sets its ceiling by its load-bearing comments, not its total.

**Contracts.** The comment on a function exists so callers never read the body. Write one only when the signature leaves a question a caller must answer to call correctly: units and bounds, what it returns or raises and when, preconditions and call ordering, thread-safety, the edge cases decided (empty, zero, negative, overflow). No nameable question means the signature is the contract — write nothing; `export` is not the trigger. Open on the answer, in the language's doc form; a restated function name ("Stores the session") fails like `// increment the counter`. Internal helpers get the ordinary test. A project's own standard wins.

**Reach for the alternative first:** rename until the name says what the comment would; extract the block into a named function; write a test that shows the behaviour; put reasoning in the commit message, PR body, or the chat reply. A comment that is hard to write is a fact about the code: split the function or name the intermediate value, and the comment writes itself or vanishes.

**Audit point.** At a commit, or the end of any turn that edited files, unprompted: for every comment in the diff, contracts included, state what the reader loses without it, clause by clause. Keep the ones with an answer, drop the rest, rewrite each survivor to the shortest phrasing that still carries the answer — the examples above are the target length. Then search the file for every identifier the edit renamed or deleted; a comment still naming one is false, and worse than none. Reread the comments around the edit site too — an edit can falsify a comment it never touched. Test names are comments the runner prints: a `describe`/`it` string claims only what its body exercises.
