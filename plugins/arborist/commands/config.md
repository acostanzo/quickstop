# Arborist Config

Show the current worktree's configuration file links (symlinks and copies).

## Instructions

1. Find the manifest file location:
   ```bash
   git rev-parse --git-dir
   ```
   The manifest is at `<git-dir>/arborist-config`

2. Read and display the manifest if it exists. Show:
   - Source worktree path
   - Created timestamp
   - List of links with their type (symlink or copy) and status (valid/broken/missing)

3. For each link, check its current status:
   - **Valid**: Target exists and points to source (for symlinks) or file exists (for copies)
   - **Broken**: Symlink exists but target is missing
   - **Missing**: Entry in manifest but file doesn't exist

4. Format output as a clear table or list showing:
   ```
   Arborist Config for: <worktree-name>
   Source: <source-worktree-path>
   Created: <timestamp>

   Links (N total):
     [symlink] .env -> ../main/.env (valid)
     [symlink] .vscode/settings.json -> ../../main/.vscode/settings.json (valid)
     [copy] seed_data.db (valid)
     [symlink] config/local.yml -> ../../main/config/local.yml (broken)
   ```

5. If no manifest exists, inform the user:
   ```
   No arborist config found for this worktree.
   Use "link my config files" to set up configuration sharing.
   ```

6. If not in a git repository or worktree, inform the user.
