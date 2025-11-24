---
description: Comprehensive plugin audit by expert subagent
argument-hint: [plugin-path]
allowed-tools: Task
---

# Plugin Audit Command

Launch an expert plugin development subagent to conduct a comprehensive audit and review of a Claude Code plugin.

## Parameters

**Arguments**: `$ARGUMENTS` (optional)

- If no argument: audit current directory
- If path provided: audit plugin at that path

## Your Task

You are launching a specialized plugin development expert to audit a Claude Code plugin.

### 1. Determine and Validate Plugin Path

```python
import os

# Parse arguments
args = "$ARGUMENTS".strip()
plugin_path = args if args else "."

# Resolve to absolute path
plugin_path = os.path.abspath(plugin_path)

# Validate path exists
if not os.path.exists(plugin_path):
    print(f"❌ Error: Path does not exist: {plugin_path}")
    print("\nPlease provide a valid plugin directory path.")
    # Stop here - don't launch expensive subagent
    return

if not os.path.isdir(plugin_path):
    print(f"❌ Error: Path is not a directory: {plugin_path}")
    # Stop here
    return
```

### 2. Load Plugin Knowledge Base

The expert subagent needs comprehensive knowledge. Read the plugin knowledge base:

```
Read ${CLAUDE_PLUGIN_ROOT}/docs/plugin-knowledge.md
```

This contains everything about:
- Plugin structure and manifests
- Commands and hooks
- Skills and subagents
- Best practices
- Security patterns
- Common pitfalls

### 3. Launch Expert Subagent

Use the Task tool to launch a specialized plugin auditor:

```
Launch a Task with subagent_type="general-purpose" with this prompt:

---

You are an expert Claude Code plugin developer conducting a comprehensive audit.

# Plugin Knowledge

[Insert full content from plugin-knowledge.md here]

# Your Task

Audit the plugin at: {plugin_path}

Conduct a thorough review covering:

## 1. 2025 Schema Compliance (STRICT - REQUIRED)

Use the "2025 Schema Compliance Checklist" from plugin-knowledge.md to validate:

### Plugin Manifest (plugin.json)
- REQUIRED: `name` (lowercase, alphanumeric, hyphens/underscores)
- REQUIRED: `version` (semantic versioning x.y.z)
- REQUIRED: `description` (descriptive text)
- REQUIRED: `author` object with `name` field
- REQUIRED: `author.email` field
- REQUIRED: `repository` (full URL)
- REQUIRED: `keywords` array
- REQUIRED: `license` identifier

### Commands Schema
- Frontmatter: `description`, `argument-hint`, `allowed-tools`
- Uses `$ARGUMENTS` for parameters
- Uses `${CLAUDE_PLUGIN_ROOT}` for paths

### Skills Schema (2025 - STRICT)
If skills present:
- Directory structure: `skills/skill-name/SKILL.md`
- `name`: lowercase, numbers, hyphens only, max 64 chars
- `description`: max 1024 chars, includes trigger phrases
- `allowed-tools`: present (strongly recommended)
- `version`: present (strongly recommended)

### Agents Schema
If agents present:
- `name` and `description` fields required
- `allowed-tools` recommended

### Hooks Schema
If hooks present:
- Valid event types only
- Scripts are executable with shebang
- Always exit 0 (never block)
- Read JSON from stdin properly

**Report schema compliance as:**
- ✅ COMPLIANT: All required fields present
- ⚠️ PARTIALLY COMPLIANT: Missing recommended fields
- ❌ NON-COMPLIANT: Missing required fields

## 2. Structure & Configuration
- Verify directory structure matches standards
- Check for README, CLAUDE.md, CHANGELOG.md

## 3. Code Quality
- Check for Python/JS code organization
- Look for security vulnerabilities:
  - SQL injection (use parameterized queries)
  - Path traversal (validate paths)
  - Code injection (sanitize inputs)
- Review error handling (specific exceptions, not bare except)
- Check for proper logging

## 4. Testing
- Look for test files
- Assess test coverage
- Check if tests are comprehensive
- Verify tests are executable and pass

## 5. Documentation
- README quality and completeness
- Usage examples
- Installation instructions
- CLAUDE.md for AI assistant guidelines (recommended)

## 6. Best Practices
- Compare against patterns from Courtney, Pluggy
- Check for common pitfalls
- Verify follows Claude Code conventions

## 7. Security & Performance
- File size limits
- Resource management
- Concurrent access handling
- Database best practices (if applicable)

# Output Format

Provide a detailed audit report with:

## Executive Summary
- Overall assessment (Production Ready / Needs Work / Major Issues)
- **2025 Schema Compliance**: ✅ COMPLIANT / ⚠️ PARTIALLY COMPLIANT / ❌ NON-COMPLIANT
- Key strengths (3-5 bullet points)
- Critical issues (if any)

## 2025 Schema Compliance Report

### Plugin Manifest
- [ ] name (required)
- [ ] version (required)
- [ ] description (required)
- [ ] author.name (required)
- [ ] author.email (required)
- [ ] repository (required)
- [ ] keywords (required)
- [ ] license (required)

**Compliance**: ✅ COMPLIANT / ⚠️ PARTIALLY COMPLIANT / ❌ NON-COMPLIANT

### Commands (if present)
- [ ] All commands have description
- [ ] All commands have argument-hint
- [ ] All commands have allowed-tools
- [ ] Commands use $ARGUMENTS properly
- [ ] Commands use ${CLAUDE_PLUGIN_ROOT} for paths

**Compliance**: ✅ COMPLIANT / ⚠️ PARTIALLY COMPLIANT / ❌ NON-COMPLIANT / N/A

### Skills (if present)
- [ ] Directory structure: skills/skill-name/SKILL.md
- [ ] name field (lowercase, numbers, hyphens, max 64 chars)
- [ ] description field (max 1024 chars, has trigger phrases)
- [ ] allowed-tools field present
- [ ] version field present

**Compliance**: ✅ COMPLIANT / ⚠️ PARTIALLY COMPLIANT / ❌ NON-COMPLIANT / N/A

### Overall Schema Compliance Score
[X/10] - Based on adherence to 2025 schema requirements

## Detailed Findings

### ✅ Strengths
[List what the plugin does well]

### ⚠️ Issues Found

#### Critical (Must Fix)
[Issues that prevent production use, including schema violations]

#### Important (Should Fix)
[Issues that impact quality/security, including missing recommended fields]

#### Minor (Nice to Have)
[Suggestions for improvement]

## Specific Recommendations

For each issue, provide:
1. What the problem is
2. Why it matters
3. How to fix it (with code examples if applicable)

## Best Practices Checklist

- [ ] Manifest complete with all recommended fields
- [ ] Semantic versioning used
- [ ] Commands have clear frontmatter
- [ ] Hooks never block (always exit 0)
- [ ] Security: No injection vulnerabilities
- [ ] Error handling: Specific exceptions
- [ ] Tests present and comprehensive
- [ ] Documentation clear with examples
- [ ] README has installation instructions

## Score

Rate the plugin on a scale of 1-10 for production readiness.

## Next Steps

Suggest 3-5 concrete next actions to improve the plugin.

---

Be thorough, specific, and helpful. Provide code examples for fixes where appropriate.
```

### 4. Present Results

When the subagent returns:

1. Show the complete audit report
2. Offer to help fix any critical issues
3. Ask if the user wants to address specific findings

## Example Output

```
🔍 Launching plugin audit expert...

[Subagent conducts thorough review]

📋 AUDIT REPORT
═══════════════════════════════════

## Executive Summary

Overall Assessment: **Needs Work** (7/10)

Key Strengths:
✓ Well-structured with proper manifest
✓ Good documentation and examples
✓ Comprehensive test coverage

Critical Issues:
❌ Hook script has bare exception handler
❌ Missing SQL injection protection

[Full detailed report follows...]

Would you like help addressing any of these findings?
```

## Notes

- The audit is comprehensive and may take a minute
- The subagent has full context on plugin best practices
- The report is actionable with specific recommendations
- This is much more thorough than simple validation
