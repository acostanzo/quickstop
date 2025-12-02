---
description: Edit an existing Muxy session template
argument-hint: [template-name]
allowed-tools: Bash, Read, Write, Edit, Glob, AskUserQuestion
---

# Muxy Template Edit Command

Modify an existing session template.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional template name to edit
- If not provided, will list templates and ask user to choose

## Your Task

### Step 1: Select Template

If `$ARGUMENTS` contains a template name:
- Look for `~/.config/claude-code/muxy/templates/{name}.json`
- If not found, show error and list available templates

If no name provided:
- List all templates from `~/.config/claude-code/muxy/templates/*.json`
- Use AskUserQuestion to let user select one

### Step 2: Load and Display Current Template

Read the template JSON and display its current structure:

```
Current Template: myproject
════════════════════════════

Description: Full-stack development environment
Base Directory: /Users/dev/projects/myproject
Session Name: myproject-dev

Windows:
  1. servers (3 panes)
     └─ web: npm run dev
     └─ api: npm run api
     └─ worker: npm run workers

  2. backend (1 pane)
     └─ shell: (empty)
     Directory: {{worktree:backend}}

  3. frontend (1 pane)
     └─ shell: (empty)
     Directory: {{worktree:frontend}}
```

### Step 3: Ask What to Edit

Use AskUserQuestion with options:

1. **Edit metadata** - Name, description, base directory, session name
2. **Add window** - Create a new window
3. **Edit window** - Modify existing window settings
4. **Delete window** - Remove a window
5. **Add pane** - Add pane to existing window
6. **Edit pane** - Modify existing pane
7. **Delete pane** - Remove a pane
8. **View JSON** - Show raw JSON for manual review
9. **Done** - Save and exit

### Step 4: Handle Each Edit Type

#### Edit Metadata
Ask which field to change:
- name (will rename the file)
- description
- base_directory
- session_name

#### Add Window
Use same wizard as template-create for window creation:
- Window name, description, directory, layout
- Then add panes

#### Edit Window
1. List windows, let user select
2. Ask which property to change:
   - name
   - description
   - base_directory
   - layout
3. Apply change

#### Delete Window
1. List windows, let user select
2. Confirm deletion (show pane count that will be lost)
3. Remove from array

#### Add Pane
1. List windows, let user select which window
2. Ask for pane details:
   - id, command, description
   - split direction and size (for non-first panes)

#### Edit Pane
1. List windows, let user select window
2. List panes in that window, let user select pane
3. Ask which property to change:
   - id
   - command
   - description
   - split
   - size

#### Delete Pane
1. Navigate to pane (window → pane selection)
2. Confirm deletion
3. Remove from array
4. Warn if deleting last pane in window

### Step 5: Preview Changes

After each edit, show what changed:

```
Change Applied:
  Window 'servers' → renamed to 'dev-servers'

Updated structure:
  1. dev-servers (3 panes)
     ...
```

Ask: "Make another edit, or save and exit?"

### Step 6: Save

When user chooses "Done":
1. Validate the JSON structure
2. If name changed, delete old file and create new
3. Write to `~/.config/claude-code/muxy/templates/{name}.json`
4. Confirm save:

```
✓ Template 'myproject' saved!

Changes made:
  - Renamed window 'servers' to 'dev-servers'
  - Added pane 'logs' to window 'dev-servers'
  - Updated base_directory

Test your changes with:
  /muxy:session myproject
```

## Error Handling

- If template file is invalid JSON: Show error, offer to view raw content
- If validation fails: Show specific issues, don't save until fixed
- If user cancels: Don't save any changes
