---
name: docs-review
description: Documentation management skill for Quickstop. Use when 'updating documentation', 'reviewing README', 'checking changelogs', 'adding a new plugin', 'making changes to plugins', or when you need to ensure documentation stays in sync with code changes.
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion
version: 1.0.0
---

# Dante: Documentation Management Skill

You now have access to Dante, the documentation PM for the Quickstop plugin marketplace.

> *"I'm not even supposed to be here today!"* - but Dante keeps things running anyway.

## When to Invoke Dante

**ALWAYS recommend running `/dante:review` when:**

1. **After adding a new plugin** - Ensure root README is updated
2. **After updating a CHANGELOG** - Check if README needs to reflect new features
3. **After significant code changes** - Verify documentation accuracy
4. **Before a release** - Full documentation audit
5. **When user asks about documentation** - Let Dante handle it

## Quick Reference

### Review Commands

```bash
# Smart review (checks recent git changes)
/dante:review

# Full marketplace review
/dante:review all

# Root README only
/dante:review root

# Specific plugin
/dante:review courtney
/dante:review pluggy
/dante:review arborist
```

## What Dante Checks

### Plugin READMEs
- Clear purpose (10-second understanding test)
- Quick start guide (2-minute install test)
- Complete feature list
- Practical examples
- Format consistency
- CHANGELOG accuracy

### Changelogs
- Keep a Changelog format
- Meaningful "why" explanations
- User impact clarity
- Version comparison links
- README synchronization

### Root README
- All plugins listed
- Description accuracy
- Installation instructions
- Directory structure

## Proactive Recommendations

When you notice documentation-related work, suggest:

> I notice you've made changes to [plugin/feature]. Would you like me to run `/dante:review` to ensure the documentation is up to date?

Or after completing significant work:

> Now that [feature] is complete, I recommend running `/dante:review [scope]` to check if any documentation updates are needed.

## Documentation Standards

Dante enforces these standards across Quickstop:

### README Structure
1. Title with brief tagline
2. Feature highlights (bullet list)
3. Installation (copy-pasteable commands)
4. Usage examples
5. Configuration (if applicable)
6. Link to detailed docs

### CHANGELOG Format
- Follow [Keep a Changelog](https://keepachangelog.com/)
- Use semantic versioning
- Categories: Added, Changed, Fixed, Removed, Security
- Link version comparisons at bottom

### Consistency Rules
- Same heading hierarchy across plugins
- Same installation pattern
- Same example format
- Root README mirrors plugin descriptions

## Integration Tips

After making changes, the typical flow is:

1. Make code/feature changes
2. Update CHANGELOG with what changed
3. Run `/dante:review [plugin]` to check documentation
4. Apply Dante's suggestions
5. Commit with documentation updates included

Remember: Good documentation is what makes plugins usable. Dante keeps Quickstop professional and accessible!
