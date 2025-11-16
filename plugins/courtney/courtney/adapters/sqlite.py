"""SQLite database adapter for Courtney."""

import sqlite3
import json
import os
from typing import Optional, Dict, Any
from datetime import datetime
from pathlib import Path

from .base import DatabaseAdapter


class DatabaseCorruptedError(Exception):
    """Raised when database is corrupted."""
    pass


class SQLiteAdapter(DatabaseAdapter):
    """SQLite implementation of the database adapter."""

    # Current schema version - increment this when making schema changes
    SCHEMA_VERSION = 1

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
        try:
            # Enable thread-safe mode and better concurrency
            self.conn = sqlite3.connect(
                self.db_path,
                check_same_thread=False,  # Allow multi-thread access
                timeout=10.0  # Wait up to 10s for locks
            )

            # Enable WAL mode for better concurrency
            self.conn.execute("PRAGMA journal_mode=WAL")

            # Check database integrity
            cursor = self.conn.cursor()
            cursor.execute("PRAGMA integrity_check")
            result = cursor.fetchone()
            if result[0] != 'ok':
                # Database is corrupted, backup and recreate
                backup_path = f"{self.db_path}.corrupted.{datetime.now().timestamp()}"
                self.conn.close()
                os.rename(self.db_path, backup_path)
                self.conn = sqlite3.connect(
                    self.db_path,
                    check_same_thread=False,
                    timeout=10.0
                )
                self.conn.execute("PRAGMA journal_mode=WAL")
                cursor = self.conn.cursor()

        except sqlite3.DatabaseError:
            # Can't even check, database is severely corrupted
            if self.conn:
                self.conn.close()
            backup_path = f"{self.db_path}.corrupted.{datetime.now().timestamp()}"
            try:
                os.rename(self.db_path, backup_path)
            except (OSError, IOError):
                # Couldn't rename corrupted file, proceeding anyway
                pass
            self.conn = sqlite3.connect(
                self.db_path,
                check_same_thread=False,
                timeout=10.0
            )
            self.conn.execute("PRAGMA journal_mode=WAL")
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

        # Create entries table with speaker validation
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                timestamp TIMESTAMP NOT NULL,
                speaker TEXT NOT NULL CHECK(speaker IN ('user', 'agent', 'subagent')),
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

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_entries_speaker
            ON entries(speaker)
        """)

        # Create schema version table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER PRIMARY KEY,
                migrated_at TIMESTAMP NOT NULL
            )
        """)

        self.conn.commit()

        # Check and update schema version
        self._check_and_migrate_schema(cursor)

    def create_session(self, session_id: str, started_at: datetime, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Create a new session record."""
        if not self.conn:
            raise RuntimeError("Database not initialized. Call initialize() first.")

        cursor = self.conn.cursor()
        try:
            cursor.execute(
                "INSERT INTO sessions (id, started_at, metadata) VALUES (?, ?, ?)",
                (session_id, started_at.isoformat(), json.dumps(metadata) if metadata else None)
            )
            self.conn.commit()
        except sqlite3.IntegrityError:
            # Session already exists, update it instead
            cursor.execute(
                "UPDATE sessions SET started_at = ?, metadata = ? WHERE id = ?",
                (started_at.isoformat(), json.dumps(metadata) if metadata else None, session_id)
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

    def _check_and_migrate_schema(self, cursor: sqlite3.Cursor) -> None:
        """Check schema version and run migrations if needed.

        Args:
            cursor: Database cursor to use for queries
        """
        # Get current schema version
        cursor.execute("SELECT version FROM schema_version ORDER BY version DESC LIMIT 1")
        row = cursor.fetchone()
        current_version = row[0] if row else 0

        # If we're already at the latest version, nothing to do
        if current_version >= self.SCHEMA_VERSION:
            return

        # Run migrations from current_version to SCHEMA_VERSION
        for version in range(current_version + 1, self.SCHEMA_VERSION + 1):
            self._migrate_to_version(cursor, version)

        self.conn.commit()

    def _migrate_to_version(self, cursor: sqlite3.Cursor, version: int) -> None:
        """Migrate database to a specific schema version.

        Args:
            cursor: Database cursor to use for queries
            version: Target schema version
        """
        if version == 1:
            # Version 1 is the initial schema - already created
            # Just record the version
            cursor.execute(
                "INSERT OR REPLACE INTO schema_version (version, migrated_at) VALUES (?, ?)",
                (version, datetime.now().isoformat())
            )
        # Future migrations would go here:
        # elif version == 2:
        #     # Add new column, table, etc.
        #     cursor.execute("ALTER TABLE ...")
        #     cursor.execute(
        #         "INSERT OR REPLACE INTO schema_version (version, migrated_at) VALUES (?, ?)",
        #         (version, datetime.now().isoformat())
        #     )

    def close(self) -> None:
        """Close the database connection."""
        if self.conn:
            self.conn.close()
            self.conn = None
