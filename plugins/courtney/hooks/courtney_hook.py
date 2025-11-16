#!/usr/bin/env python3
"""
Courtney hook script for Claude Code.
This script handles all hook events and records them to the database.
"""

import sys
import json
import os

# Add the plugin root directory to the path so we can import courtney modules
# When installed as a plugin, this script is in hooks/ and courtney/ is at plugin root
plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, plugin_root)

from courtney.recorder import Recorder


def _log_to_file(log_path: str, message: str) -> None:
    """Safely log to file without raising exceptions.

    Args:
        log_path: Path to log file
        message: Message to log
    """
    try:
        with open(log_path, 'a') as log:
            log.write(message)
    except (IOError, OSError):
        # If we can't write to log, fail silently
        pass


def main():
    """Main entry point for the hook."""
    # Setup debug logging
    log_path = os.path.expanduser("~/.claude/courtney.log")

    # Verify we're running from the correct location
    plugin_root_env = os.environ.get('CLAUDE_PLUGIN_ROOT')
    if not plugin_root_env:
        _log_to_file(log_path, "WARNING: CLAUDE_PLUGIN_ROOT not set, using fallback\n\n")

    try:
        # Read hook data from stdin
        hook_data = json.load(sys.stdin)

        # Get the hook event type
        event_type = hook_data.get("hook_event_name")

        # Debug log
        _log_to_file(log_path, f"[{event_type}] {json.dumps(hook_data, indent=2)}\n\n")

        if not event_type:
            # No event type, nothing to do
            sys.exit(0)

        # Initialize recorder
        recorder = Recorder()

        # Dispatch to appropriate handler based on event type
        # Only recording user prompts and AI responses (not tool calls)
        handlers = {
            "SessionStart": recorder.handle_session_start,
            "SessionEnd": recorder.handle_session_end,
            "UserPromptSubmit": recorder.handle_user_prompt,
            "Stop": recorder.handle_stop,
            "SubagentStop": recorder.handle_subagent_stop,
        }

        handler = handlers.get(event_type)
        if handler:
            handler(hook_data)

        # Close the recorder
        recorder.close()

        # Always exit successfully (we're read-only, never block)
        sys.exit(0)

    except Exception as e:
        # Log error but don't block Claude Code
        import traceback
        error_msg = f"ERROR: {e}\n{traceback.format_exc()}\n\n"
        _log_to_file(log_path, error_msg)
        print(f"Courtney hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
