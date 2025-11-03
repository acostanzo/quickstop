"""Core recording logic for Courtney."""

import json
import uuid
from datetime import datetime
from typing import Dict, Any, Optional

from .config import Config
from .adapters.base import DatabaseAdapter
from .adapters.sqlite import SQLiteAdapter


class Recorder:
    """Main recorder class that handles all transcript recording."""

    def __init__(self, config: Optional[Config] = None):
        """Initialize the recorder.

        Args:
            config: Configuration object. If None, uses default config.
        """
        self.config = config or Config()
        self.adapter = self._create_adapter()
        self.adapter.initialize()

    def _create_adapter(self) -> DatabaseAdapter:
        """Create the appropriate database adapter based on config."""
        adapter_type = self.config.get_adapter_type()
        adapter_config = self.config.get_adapter_config()

        if adapter_type == "sqlite":
            db_path = adapter_config.get("path", "~/.claude/courtney.db")
            return SQLiteAdapter(db_path)
        else:
            raise ValueError(f"Unknown adapter type: {adapter_type}")

    def handle_session_start(self, hook_data: Dict[str, Any]) -> None:
        """Handle SessionStart hook.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        source = hook_data.get("source", "unknown")

        self.adapter.create_session(
            session_id=session_id,
            started_at=datetime.now(),
            metadata={"source": source}
        )

    def handle_session_end(self, hook_data: Dict[str, Any]) -> None:
        """Handle SessionEnd hook.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        reason = hook_data.get("reason", "unknown")

        self.adapter.end_session(
            session_id=session_id,
            ended_at=datetime.now(),
            metadata={"reason": reason}
        )

    def handle_user_prompt(self, hook_data: Dict[str, Any]) -> None:
        """Handle UserPromptSubmit hook - records full user input.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        prompt = hook_data.get("prompt", "")

        # Store full user prompt with no truncation
        self.adapter.add_entry(
            entry_id=str(uuid.uuid4()),
            session_id=session_id,
            timestamp=datetime.now(),
            speaker="user",
            transcript=prompt
        )

    def handle_stop(self, hook_data: Dict[str, Any]) -> None:
        """Handle Stop hook - records the assistant's full text response.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        transcript_path = hook_data.get("transcript_path")

        if not transcript_path:
            return

        try:
            # Read the JSONL transcript file (one JSON object per line)
            # Find the last assistant message with text content
            last_text = None

            with open(transcript_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        entry = json.loads(line)

                        # Look for assistant messages with text content
                        if entry.get("type") == "assistant":
                            message = entry.get("message", {})
                            if message.get("role") == "assistant":
                                content = message.get("content", [])
                                if isinstance(content, list):
                                    for item in content:
                                        if isinstance(item, dict) and item.get("type") == "text":
                                            text = item.get("text", "")
                                            if text.strip():
                                                last_text = text
                    except json.JSONDecodeError:
                        continue

            # Record the last text we found
            if last_text:
                self.adapter.add_entry(
                    entry_id=str(uuid.uuid4()),
                    session_id=session_id,
                    timestamp=datetime.now(),
                    speaker="agent",
                    transcript=last_text
                )

        except (IOError, json.JSONDecodeError) as e:
            # Silently fail - we don't want to break Claude's operation
            pass

    def handle_subagent_stop(self, hook_data: Dict[str, Any]) -> None:
        """Handle SubagentStop hook - records the subagent's full final report.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        transcript_path = hook_data.get("transcript_path")

        if not transcript_path:
            return

        try:
            # Read the JSONL transcript file (one JSON object per line)
            # Find the last assistant message with text content
            last_text = None

            with open(transcript_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        entry = json.loads(line)

                        # Look for assistant messages with text content
                        if entry.get("type") == "assistant":
                            message = entry.get("message", {})
                            if message.get("role") == "assistant":
                                content = message.get("content", [])
                                if isinstance(content, list):
                                    for item in content:
                                        if isinstance(item, dict) and item.get("type") == "text":
                                            text = item.get("text", "")
                                            if text.strip():
                                                last_text = text
                    except json.JSONDecodeError:
                        continue

            # Record the last text we found
            if last_text:
                self.adapter.add_entry(
                    entry_id=str(uuid.uuid4()),
                    session_id=session_id,
                    timestamp=datetime.now(),
                    speaker="subagent",
                    transcript=last_text
                )

        except (IOError, json.JSONDecodeError) as e:
            # Silently fail
            pass

    def close(self) -> None:
        """Close the recorder and database connection."""
        self.adapter.close()
