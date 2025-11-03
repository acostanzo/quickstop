"""Base database adapter interface for Courtney."""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from datetime import datetime


class DatabaseAdapter(ABC):
    """Abstract base class for database adapters."""

    @abstractmethod
    def initialize(self) -> None:
        """Initialize the database (create tables, etc.)."""
        pass

    @abstractmethod
    def create_session(self, session_id: str, started_at: datetime, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Create a new session record.

        Args:
            session_id: Unique identifier for the session
            started_at: When the session started
            metadata: Optional metadata about the session
        """
        pass

    @abstractmethod
    def end_session(self, session_id: str, ended_at: datetime, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Update session with end time.

        Args:
            session_id: Unique identifier for the session
            ended_at: When the session ended
            metadata: Optional metadata about session end
        """
        pass

    @abstractmethod
    def add_entry(
        self,
        entry_id: str,
        session_id: str,
        timestamp: datetime,
        speaker: str,
        transcript: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """Add a new transcript entry.

        Args:
            entry_id: Unique identifier for the entry
            session_id: Session this entry belongs to
            timestamp: When the entry occurred
            speaker: Either 'user' or 'agent'
            transcript: The actual content
            metadata: Optional metadata (tool names, params, etc.)
        """
        pass

    @abstractmethod
    def close(self) -> None:
        """Close the database connection."""
        pass
