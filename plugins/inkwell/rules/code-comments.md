---
name: code-comments
description: "Enforces meaningful code comments — prohibits obvious comments, encourages intent-revealing annotations."
globs: "*.ts,*.tsx,*.js,*.jsx,*.py,*.go,*.rs,*.java,*.rb"
---

# Code Comments

## Rules

1. **No narration comments.** Do not add comments that restate what the code already says. If the code is `user.save()`, a comment `// save the user` adds nothing. Delete it.

2. **Explain why, not what.** Comments exist to capture intent, constraints, trade-offs, or non-obvious context that the code cannot express on its own. Good: `// Retry up to 3 times — upstream API has transient 503s during deploys`. Bad: `// retry logic`.

3. **No section-separator comments.** Do not add comments like `// --- Helper Functions ---` or `// ===== Config =====` to visually divide code. Use file structure and naming instead.

4. **Keep TODOs actionable.** Every `TODO` must describe what needs to happen and why. Include enough context that someone unfamiliar with the history can act on it. Bad: `// TODO: fix this`. Good: `// TODO: replace polling with WebSocket — polling adds 2s latency on dashboard load`.

5. **No commented-out code.** Dead code belongs in version control history, not in the source file. Remove commented-out blocks instead of leaving them "just in case."

6. **Docstrings for public APIs only.** Add docstrings or JSDoc to exported functions, classes, and modules that other developers consume. Internal helpers rarely need them — if the name and signature aren't enough, consider renaming.

7. **Update comments when code changes.** A stale comment is worse than no comment. When modifying code, check adjacent comments and update or remove them if they no longer apply.
