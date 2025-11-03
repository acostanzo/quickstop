# GitHub Repository Rename Guide

This repository needs to be renamed on GitHub to match the new marketplace structure.

## Rename Steps

### 1. On GitHub

1. Go to https://github.com/acostanzo/Courtney/settings
2. Scroll down to "Repository name"
3. Change from `Courtney` to `quickstop`
4. Click "Rename"

GitHub will automatically set up redirects from the old name.

### 2. Update Your Local Clone

After renaming on GitHub, update your local repository:

```bash
# Navigate to your local repo
cd /path/to/Courtney

# Update the remote URL
git remote set-url origin https://github.com/acostanzo/quickstop.git

# Verify the change
git remote -v

# Optional: Rename your local directory
cd ..
mv Courtney quickstop
cd quickstop
```

### 3. Verification

After renaming, verify everything works:

```bash
# Pull to confirm connection
git pull

# Check remote
git remote -v
# Should show: https://github.com/acostanzo/quickstop.git
```

## What Gets Updated Automatically

- All existing clone URLs will redirect
- All existing links to the repo will redirect
- Pull requests and issues remain intact
- GitHub Pages (if any) will update

## What Needs Manual Update

The following have already been updated in this commit:

- ✅ Installation commands in READMEs
- ✅ Clone commands in documentation
- ✅ plugin.json repository URL
- ✅ All marketplace references

## After Rename

Once renamed, users will install with:

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install courtney@quickstop
```

## Rollback (If Needed)

If you need to rollback:
1. Go to Settings
2. Change name back to `Courtney`
3. Run `git remote set-url origin https://github.com/acostanzo/Courtney.git` locally

---

**Note**: This file can be deleted after the rename is complete.
