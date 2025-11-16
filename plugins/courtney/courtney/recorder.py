"""Core recording logic for Courtney."""

import json
import os
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from enum import Enum

from .config import Config
from .adapters.base import DatabaseAdapter
from .adapters.sqlite import SQLiteAdapter


class Speaker(str, Enum):
    """Valid speaker types for transcript entries."""
    USER = "user"
    AGENT = "agent"
    SUBAGENT = "subagent"


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

    def _log_error(self, message: str, **kwargs: Any) -> None:
        """Log error to courtney.log file.

        Args:
            message: Error message to log
            **kwargs: Additional context to log
        """
        log_path = os.path.expanduser("~/.claude/courtney.log")
        try:
            with open(log_path, 'a') as log:
                log.write(f"[ERROR] {message}\n")
                for key, value in kwargs.items():
                    log.write(f"  {key}: {value}\n")
                log.write("\n")
        except (IOError, OSError):
            # Truly silent - can't even log
            pass

    def handle_session_start(self, hook_data: Dict[str, Any]) -> None:
        """Handle SessionStart hook.

        Args:
            hook_data: The hook input data from Claude Code
        """
        session_id = hook_data.get("session_id")
        source = hook_data.get("source", "unknown")

        self.adapter.create_session(
            session_id=session_id,
            started_at=datetime.now(timezone.utc),
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
            ended_at=datetime.now(timezone.utc),
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
            timestamp=datetime.now(timezone.utc),
            speaker=Speaker.USER.value,
            transcript=prompt
        )

    def _parse_and_record_transcript(
        self,
        hook_data: Dict[str, Any],
        speaker: Speaker
    ) -> None:
        """Parse transcript file and record the last assistant text.

        Validates the transcript path, checks file size, and extracts the last
        assistant message with text content from the JSONL transcript file.

        Args:
            hook_data: Hook data containing transcript_path and session_id
            speaker: Either Speaker.AGENT or Speaker.SUBAGENT
        """
        session_id = hook_data.get("session_id")
        transcript_path = hook_data.get("transcript_path")

        if not transcript_path:
            return

        try:
            # Validate path
            transcript_path = os.path.abspath(transcript_path)

            # Check it's a real file
            if not os.path.isfile(transcript_path):
                self._log_error(
                    "Transcript path is not a file",
                    transcript_path=transcript_path,
                    session_id=session_id
                )
                return

            # Check file extension
            if not transcript_path.endswith(('.json', '.jsonl')):
                self._log_error(
                    "Transcript file has unexpected extension",
                    transcript_path=transcript_path,
                    session_id=session_id
                )
                return

            # Check file size (max 10MB)
            MAX_TRANSCRIPT_SIZE = 10 * 1024 * 1024
            file_size = os.path.getsize(transcript_path)
            if file_size > MAX_TRANSCRIPT_SIZE:
                self._log_error(
                    "Transcript file too large",
                    transcript_path=transcript_path,
                    file_size=file_size,
                    max_size=MAX_TRANSCRIPT_SIZE,
                    session_id=session_id
                )
                return

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
                    timestamp=datetime.now(timezone.utc),
                    speaker=speaker.value,
                    transcript=last_text
                )

        except (IOError, json.JSONDecodeError) as e:
            # Log error but don't break Claude's operation
            self._log_error(
                f"Failed to parse transcript: {e}",
                transcript_path=transcript_path,
                session_id=session_id,
                speaker=speaker.value
            )

    def handle_stop(self, hook_data: Dict[str, Any]) -> None:
        """Handle Stop hook - records the assistant's full text response.

        Args:
            hook_data: The hook input data from Claude Code
        """
        self._parse_and_record_transcript(hook_data, Speaker.AGENT)

    def handle_subagent_stop(self, hook_data: Dict[str, Any]) -> None:
        """Handle SubagentStop hook - records the subagent's full final report.

        Args:
            hook_data: The hook input data from Claude Code
        """
        self._parse_and_record_transcript(hook_data, Speaker.SUBAGENT)

    def close(self) -> None:
        """Close the recorder and database connection."""
        self.adapter.close()
