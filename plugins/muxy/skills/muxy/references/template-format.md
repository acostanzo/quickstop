# Template YAML Format

Templates are stored in `~/.config/muxy/templates/` as YAML files.

## Schema

```yaml
name: template-name
description: Brief description of what this template is for
variables:
  variable_name: "Description shown when asking user for value"
windows:
  - name: Window Name
    layout: horizontal | vertical  # optional, default: single pane
    panes:
      - path: /absolute/path or ${variable}
        command: optional startup command
```

## Fields

### Top-Level

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Template identifier (kebab-case recommended) |
| `description` | Yes | Human-readable purpose |
| `variables` | No | Map of variable names to descriptions |
| `windows` | Yes | List of window definitions |

### Window

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Window title in tmux |
| `layout` | No | `horizontal` (stacked) or `vertical` (side-by-side). Omit for single pane. |
| `panes` | Yes | List of pane definitions |

### Pane

| Field | Required | Description |
|-------|----------|-------------|
| `path` | Yes | Working directory. Can use `${variable}` syntax. |
| `command` | No | Command to run on pane creation |

## Variable Syntax

Use `${variable_name}` in `path` or `command` fields:

```yaml
variables:
  project_dir: "Project root directory"
  notes_dir: "Notes directory"
windows:
  - name: Code
    panes:
      - path: ${project_dir}
        command: vim .
```

### Built-in Inference

These variables are automatically inferred when possible:

| Variable | Inference |
|----------|-----------|
| `${project_dir}` | Current working directory, or detected from prompt |
| `${notes_dir}` | `~/notes` if exists, else `~/Documents/notes`, else prompt user |

Unknown variables prompt the user for values.

## Layout Translation

Template layout values map to tmux split directions:

| Template Value | tmux Split | Visual Result |
|----------------|------------|---------------|
| (omitted) | none | Single pane |
| `vertical` | `-h` (horizontal split) | Panes side-by-side |
| `horizontal` | `-v` (vertical split) | Panes stacked |

Note: tmux naming is inverted. A "horizontal split" creates panes arranged horizontally (side-by-side). The template uses intuitive names.

## Example Templates

### Rails Development

```yaml
name: rails
description: Standard Rails development environment
variables:
  project_dir: "Rails project root"
windows:
  - name: Server
    panes:
      - path: ${project_dir}
        command: bin/rails server
  - name: Console
    layout: horizontal
    panes:
      - path: ${project_dir}
        command: bin/rails console
      - path: ${project_dir}
  - name: Code
    panes:
      - path: ${project_dir}
```

### Web Development

```yaml
name: web-dev
description: Frontend development with hot reload
variables:
  project_dir: "Project directory"
windows:
  - name: Dev Server
    panes:
      - path: ${project_dir}
        command: npm run dev
  - name: Build
    panes:
      - path: ${project_dir}
  - name: Editor
    layout: vertical
    panes:
      - path: ${project_dir}
      - path: ${project_dir}/src
```

### Claude Agent Workspace

```yaml
name: agent
description: Claude Code with supporting terminals
variables:
  project_dir: "Working directory"
windows:
  - name: Agent
    layout: horizontal
    panes:
      - path: ${project_dir}
        command: claude
      - path: ${project_dir}
  - name: Shell
    panes:
      - path: ${project_dir}
```

## Creating Templates Programmatically

When saving a session as a template:

1. Take the confirmed session structure
2. Identify paths that should become variables:
   - Repeated paths → `${project_dir}`
   - Paths containing project name → `${project_dir}`
   - Notes/docs paths → `${notes_dir}`
3. Generate variable descriptions
4. Write YAML to `~/.config/muxy/templates/{name}.yaml`

## File Operations

### Reading Templates

```bash
# List available templates
ls ~/.config/muxy/templates/*.yaml

# Read specific template
cat ~/.config/muxy/templates/rails.yaml
```

### Ensuring Directory Exists

```bash
mkdir -p ~/.config/muxy/templates
```
