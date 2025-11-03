"""SQLite database adapter for Courtney."""

import sqlite3
import json
import os
from typing import Optional, Dict, Any
from datetime import datetime
from pathlib import Path

from .base import DatabaseAdapter


class SQLiteAdapter(DatabaseAdapter):
    """SQLite implementation of the database adapter."""

    def __init__(self, db_path: str):
        """Initialize SQLite adapter.

        Args:
            db_path: Path to the SQLite database file
        """
        # Expand user home directory and ensure parent directory exists
        self.db_path = os.path.expanduser(db_path)
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)

        self.conn: Optional[sqlite3.Connection] = None

    def initialize(self) -> None:
        """Initialize the database (create tables if they don't exist)."""
        self.conn = sqlite3.connect(self.db_path)
        cursor = self.conn.cursor()

        # Create sessions table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                started_at TIMESTAMP NOT NULL,
                ended_at TIMESTAMP,
                metadata TEXT
            )
        """)

        # Create entries table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                timestamp TIMESTAMP NOT NULL,
                speaker TEXT NOT NULL,
                transcript TEXT NOT NULL,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
        """)

        # Create indices for better query performance
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_entries_session_id
            ON entries(session_id)
        """)

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_entries_timestamp
            ON entries(timestamp)
        """)

        self.conn.commit()

    def create_session(self, session_id: str, started_at: datetime, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Create a new session record."""
        if not self.conn:
            raise RuntimeError("Database not initialized. Call initialize() first.")

        cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO sessions (id, started_at, metadata) VALUES (?, ?, ?)",
            (session_id, started_at.isoformat(), json.dumps(metadata) if metadata else None)
        )
        self.conn.commit()

    def end_session(self, session_id: str, ended_at: datetime, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Update session with end time."""
        if not self.conn:
            raise RuntimeError("Database not initialized. Call initialize() first.")

        cursor = self.conn.cursor()

        # Merge metadata if it exists
        if metadata:
            cursor.execute("SELECT metadata FROM sessions WHERE id = ?", (session_id,))
            row = cursor.fetchone()
            if row and row[0]:
                existing_metadata = json.loads(row[0])
                existing_metadata.update(metadata)
                metadata = existing_metadata

        cursor.execute(
            "UPDATE sessions SET ended_at = ?, metadata = ? WHERE id = ?",
            (ended_at.isoformat(), json.dumps(metadata) if metadata else None, session_id)
        )
        self.conn.commit()

    def add_entry(
        self,
        entry_id: str,
        session_id: str,
        timestamp: datetime,
        speaker: str,
        transcript: str
    ) -> None:
        """Add a new transcript entry."""
        if not self.conn:
            raise RuntimeError("Database not initialized. Call initialize() first.")

        cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO entries (id, session_id, timestamp, speaker, transcript) VALUES (?, ?, ?, ?, ?)",
            (entry_id, session_id, timestamp.isoformat(), speaker, transcript)
        )
        self.conn.commit()

    def close(self) -> None:
        """Close the database connection."""
        if self.conn:
            self.conn.close()
            self.conn = None
