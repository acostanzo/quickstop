---
name: checkpoint
description: Capture documentation for work done in the current session
allowed-tools:
  - Task
  - Read
  - Glob
---

# Documentation Checkpoint

The user wants to capture documentation for work done in the current session. This is typically invoked:
- Before running `/clear`
- At the end of a work session
- When switching to a different feature or task

## Your Task

1. **Analyze the conversation** - Review the current session to identify:
   - Features implemented or significantly modified
   - Architecture decisions made
   - Components that were changed

2. **Determine documentation needs** - Is documentation warranted?
   - **Yes**: New features, architecture decisions, significant component changes
   - **No**: Bug fixes only, simple refactoring, just reading/exploring code

3. **Dispatch appropriate Sentinels**:
   - For feature work → dispatch `guilty-spark:sentinel-feature`
   - For architecture changes → dispatch `guilty-spark:sentinel-architecture`
   - For both → dispatch both (feature first, then architecture)

4. **Run in background** - Always dispatch with `run_in_background: true` so the user can continue

## Example Task Tool Parameters

- `description`: "Document session work"
- `subagent_type`: "guilty-spark:sentinel-feature"
- `prompt`: "Document the following work from this session: [summary of work]. Check existing docs and update or create as needed."
- `run_in_background`: true

## Output

After dispatching (or if no documentation needed):
- Confirm what was dispatched
- Or explain why no documentation was needed

Keep the response brief - the user invoked this to quickly capture docs, not for a lengthy discussion.
