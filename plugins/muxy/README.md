# Muxy

Orchestrate complex tmux sessions with templates, worktree integration, and MCP control.

## Features

- **Session Templates**: Define reusable session configurations with windows, panes, and commands
- **Template Variables**: Use `{{worktree:branch}}`, `{{project_name}}`, `{{date}}` for dynamic paths
- **Worktree Integration**: Seamlessly work with git worktrees via Arborist plugin
- **Pane Operations**: Run commands and read output from specific panes
- **Interactive Selection**: Navigate sessions, windows, and panes with helpful context

## Installation

```bash
# From the quickstop marketplace
/plugin install muxy
```

## Quick Start

1. **Check your setup**:
   ```
   /muxy:doctor
   ```

2. **Create a template**:
   ```
   /muxy:template-create myproject
   ```

3. **Start a session**:
   ```
   /muxy:session myproject
   ```

4. **Attach to the session** (in your terminal):
   ```bash
   tmux attach-session -t myproject-dev
   ```

## Commands

| Command | Description |
|---------|-------------|
| `/muxy:doctor` | Verify tmux and environment setup |
| `/muxy:template-list` | List all available templates |
| `/muxy:template-create [name]` | Create a new session template |
| `/muxy:template-edit [name]` | Edit an existing template |
| `/muxy:template-delete [name]` | Delete a template |
| `/muxy:session [template]` | Start or attach to a session from template |
| `/muxy:kill [session]` | Kill a tmux session |
| `/muxy:pane-run [command]` | Run a command in a specific pane |
| `/muxy:pane-read` | Read output from a specific pane |

## Template Schema

Templates are JSON files stored in `~/.config/claude-code/muxy/templates/`:

```json
{
  "name": "fullstack",
  "description": "Full-stack development environment",
  "version": "1.0",
  "base_directory": "/Users/dev/projects/myapp",
  "session_name": "myapp-dev",
  "windows": [
    {
      "name": "servers",
      "description": "Development servers",
      "layout": "main-horizontal",
      "panes": [
        {
          "id": "web",
          "command": "npm run dev",
          "description": "Web server"
        },
        {
          "id": "api",
          "command": "npm run api",
          "split": "vertical",
          "size": "50%",
          "description": "API server"
        }
      ]
    },
    {
      "name": "backend",
      "description": "Backend development",
      "base_directory": "{{worktree:backend}}",
      "panes": [
        {
          "id": "shell",
          "command": null,
          "description": "Backend shell"
        }
      ]
    },
    {
      "name": "claude",
      "description": "Claude Code",
      "base_directory": "{{worktree:feature}}",
      "panes": [
        {
          "id": "claude",
          "command": "claude",
          "description": "Claude Code session"
        }
      ]
    }
  ]
}
```

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{worktree:branch}}` | Git worktree path for branch | `{{worktree:feature/auth}}` |
| `{{project_name}}` | Current directory name | `myproject` |
| `{{date}}` | Current date | `2024-01-15` |
| `{{timestamp}}` | Unix timestamp | `1705334400` |

## Layouts

Available tmux layouts for windows:

- `even-horizontal` - Panes side by side, equal width
- `even-vertical` - Panes stacked, equal height
- `main-horizontal` - One large pane on top, others below
- `main-vertical` - One large pane on left, others on right
- `tiled` - Panes in a grid

## Workflow Example

### Setting up a full-stack project

1. Create your worktrees:
   ```
   /arborist:plant backend
   /arborist:plant frontend
   /arborist:plant feature/new-feature
   ```

2. Create a template:
   ```
   /muxy:template-create fullstack
   ```
   Follow the interactive wizard to define your windows and panes.

3. Start your session:
   ```
   /muxy:session fullstack
   ```

4. In your terminal:
   ```bash
   tmux attach-session -t fullstack-dev
   ```

### Running commands in panes

```
/muxy:pane-run npm test
```

Then interactively select the pane where you want to run the command.

### Reading pane output

```
/muxy:pane-read
```

Select a pane to see its output, useful for checking logs or command results.

## Requirements

- tmux 3.0+
- macOS or Linux
- Optional: [Arborist plugin](../arborist/) for worktree integration

## Related Plugins

- **Arborist**: Git worktree management - provides `{{worktree:branch}}` resolution

## License

MIT
