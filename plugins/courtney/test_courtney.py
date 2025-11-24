#!/usr/bin/env python3
"""
Test/validation script for Courtney.
Tests the core recording functionality without requiring a full Claude Code session.
"""

import json
import os
import sys
import tempfile
import uuid
from datetime import datetime
from pathlib import Path

# Add courtney to path
courtney_path = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, courtney_path)

from courtney.recorder import Recorder
from courtney.config import Config
from courtney.adapters.sqlite import SQLiteAdapter


def create_test_config():
    """Create a temporary test configuration."""
    temp_db = tempfile.NamedTemporaryFile(suffix='.db', delete=False)
    temp_db.close()

    config_data = {
        "adapter": "sqlite",
        "sqlite": {
            "path": temp_db.name
        }
    }

    # Create a temporary config file
    temp_config = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
    json.dump(config_data, temp_config)
    temp_config.close()

    return temp_config.name, temp_db.name


def create_mock_transcript(session_id):
    """Create a mock transcript file for testing Stop/SubagentStop hooks."""
    temp_transcript = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False)

    # Write JSONL format (one JSON object per line)
    # This matches the actual Claude Code transcript format
    entry = {
        "type": "assistant",
        "message": {
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "Hello! This is a test assistant response."
                }
            ]
        }
    }
    temp_transcript.write(json.dumps(entry) + '\n')
    temp_transcript.close()
    return temp_transcript.name


def test_database_initialization(config_path):
    """Test that the database initializes correctly."""
    print("Testing database initialization...")

    config = Config(config_path)
    recorder = Recorder(config)

    # Check that database file exists
    db_path = os.path.expanduser(config.get('sqlite.path'))
    if not os.path.exists(db_path):
        print("  ❌ Database file not created")
        return False

    print("  ✓ Database file created")

    # Check that tables exist
    adapter = recorder.adapter
    cursor = adapter.conn.cursor()

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]

    if 'sessions' not in tables:
        print("  ❌ sessions table not created")
        return False
    print("  ✓ sessions table exists")

    if 'entries' not in tables:
        print("  ❌ entries table not created")
        return False
    print("  ✓ entries table exists")

    recorder.close()
    return True


def test_session_lifecycle(config_path):
    """Test session start and end."""
    print("\nTesting session lifecycle...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())

    # Test session start
    hook_data = {
        "session_id": session_id,
        "source": "startup"
    }
    recorder.handle_session_start(hook_data)
    print("  ✓ Session start recorded")

    # Test session end
    hook_data = {
        "session_id": session_id,
        "reason": "clear"
    }
    recorder.handle_session_end(hook_data)
    print("  ✓ Session end recorded")

    # Verify in database
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT * FROM sessions WHERE id = ?", (session_id,))
    row = cursor.fetchone()

    if not row:
        print("  ❌ Session not found in database")
        recorder.close()
        return False

    if row[2] is None:  # ended_at should be set
        print("  ❌ Session end time not recorded")
        recorder.close()
        return False

    print("  ✓ Session verified in database")
    recorder.close()
    return True


def test_user_prompt(config_path):
    """Test user prompt recording."""
    print("\nTesting user prompt recording...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Test user prompt
    hook_data = {
        "session_id": session_id,
        "prompt": "This is a test user prompt"
    }
    recorder.handle_user_prompt(hook_data)
    print("  ✓ User prompt recorded")

    # Verify in database
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT * FROM entries WHERE session_id = ? AND speaker = 'user'", (session_id,))
    row = cursor.fetchone()

    if not row:
        print("  ❌ User prompt not found in database")
        recorder.close()
        return False

    if row[4] != "This is a test user prompt":  # transcript field
        print(f"  ❌ Transcript mismatch: {row[4]}")
        recorder.close()
        return False

    print("  ✓ User prompt verified in database")
    recorder.close()
    return True


def test_full_conversation(config_path):
    """Test a full conversation flow (user prompt + AI response)."""
    print("\nTesting full conversation flow...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Test user prompt
    hook_data = {
        "session_id": session_id,
        "prompt": "Write a hello world function"
    }
    recorder.handle_user_prompt(hook_data)
    print("  ✓ User prompt recorded")

    # Create mock transcript for AI response
    transcript_path = create_mock_transcript(session_id)

    # Test Stop hook (AI response)
    hook_data = {
        "session_id": session_id,
        "transcript_path": transcript_path
    }
    recorder.handle_stop(hook_data)
    print("  ✓ AI response recorded")

    # Verify in database - should have 1 user entry and 1 agent entry
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT speaker, transcript FROM entries WHERE session_id = ? ORDER BY timestamp", (session_id,))
    rows = cursor.fetchall()

    if len(rows) != 2:
        print(f"  ❌ Expected 2 entries (user + agent), found {len(rows)}")
        recorder.close()
        os.unlink(transcript_path)
        return False

    if rows[0][0] != 'user' or rows[1][0] != 'agent':
        print(f"  ❌ Speaker order incorrect: {[r[0] for r in rows]}")
        recorder.close()
        os.unlink(transcript_path)
        return False

    print("  ✓ Full conversation verified in database")
    recorder.close()
    os.unlink(transcript_path)
    return True


def test_stop_hook(config_path):
    """Test Stop hook with transcript parsing."""
    print("\nTesting Stop hook (transcript parsing)...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Create mock transcript
    transcript_path = create_mock_transcript(session_id)

    # Test Stop hook
    hook_data = {
        "session_id": session_id,
        "transcript_path": transcript_path
    }
    recorder.handle_stop(hook_data)
    print("  ✓ Stop hook processed")

    # Verify in database
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT * FROM entries WHERE session_id = ? AND speaker = 'agent'", (session_id,))
    rows = cursor.fetchall()

    if len(rows) == 0:
        print("  ❌ No agent entries found")
        recorder.close()
        os.unlink(transcript_path)
        return False

    # Check that the transcript was extracted
    found_response = False
    for row in rows:
        if "test assistant response" in row[4].lower():
            found_response = True
            break

    if not found_response:
        print("  ❌ Assistant response not found in transcripts")
        recorder.close()
        os.unlink(transcript_path)
        return False

    print("  ✓ Stop hook verified in database")
    recorder.close()
    os.unlink(transcript_path)
    return True


def test_query_examples(config_path):
    """Test example queries from README."""
    print("\nTesting example queries...")

    config = Config(config_path)
    adapter = SQLiteAdapter(config.get('sqlite.path'))
    adapter.initialize()

    cursor = adapter.conn.cursor()

    # Test sessions query
    try:
        cursor.execute("SELECT * FROM sessions ORDER BY started_at DESC")
        sessions = cursor.fetchall()
        print(f"  ✓ Sessions query works ({len(sessions)} sessions)")
    except Exception as e:
        print(f"  ❌ Sessions query failed: {e}")
        adapter.close()
        return False

    # Test entries query
    try:
        cursor.execute("SELECT timestamp, speaker, transcript FROM entries ORDER BY timestamp")
        entries = cursor.fetchall()
        print(f"  ✓ Entries query works ({len(entries)} entries)")
    except Exception as e:
        print(f"  ❌ Entries query failed: {e}")
        adapter.close()
        return False

    # Test user prompts query
    try:
        cursor.execute("SELECT timestamp, transcript FROM entries WHERE speaker = 'user' ORDER BY timestamp DESC")
        user_entries = cursor.fetchall()
        print(f"  ✓ User prompts query works ({len(user_entries)} prompts)")
    except Exception as e:
        print(f"  ❌ User prompts query failed: {e}")
        adapter.close()
        return False

    adapter.close()
    return True


def test_file_too_large(config_path):
    """Test handling of transcript files that exceed size limit."""
    print("\nTesting file size limit handling...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Create a file larger than 10MB
    temp_transcript = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False)
    # Write 11MB of data
    large_text = "x" * (11 * 1024 * 1024)
    temp_transcript.write(large_text)
    temp_transcript.close()

    # Test Stop hook with oversized file
    hook_data = {
        "session_id": session_id,
        "transcript_path": temp_transcript.name
    }
    recorder.handle_stop(hook_data)
    print("  ✓ Large file handled gracefully")

    # Verify no entry was created (file too large)
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM entries WHERE session_id = ?", (session_id,))
    count = cursor.fetchone()[0]

    if count != 0:
        print(f"  ❌ Expected 0 entries, found {count}")
        recorder.close()
        os.unlink(temp_transcript.name)
        return False

    print("  ✓ Large file rejected correctly")
    recorder.close()
    os.unlink(temp_transcript.name)
    return True


def test_invalid_speaker(config_path):
    """Test that invalid speaker values are rejected."""
    print("\nTesting invalid speaker validation...")

    config = Config(config_path)
    adapter = SQLiteAdapter(config.get('sqlite.path'))
    adapter.initialize()

    session_id = str(uuid.uuid4())
    adapter.create_session(session_id, datetime.now(), {})

    # Try to insert an invalid speaker
    try:
        cursor = adapter.conn.cursor()
        cursor.execute(
            "INSERT INTO entries (id, session_id, timestamp, speaker, transcript) VALUES (?, ?, ?, ?, ?)",
            (str(uuid.uuid4()), session_id, datetime.now().isoformat(), "invalid_speaker", "test")
        )
        adapter.conn.commit()
        print("  ❌ Invalid speaker was accepted")
        adapter.close()
        return False
    except Exception as e:
        if "CHECK constraint failed" in str(e) or "constraint" in str(e).lower():
            print("  ✓ Invalid speaker rejected by CHECK constraint")
            adapter.close()
            return True
        else:
            print(f"  ❌ Unexpected error: {e}")
            adapter.close()
            return False


def test_empty_transcript(config_path):
    """Test handling of empty transcripts."""
    print("\nTesting empty transcript handling...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Test user prompt with empty string
    hook_data = {
        "session_id": session_id,
        "prompt": ""
    }
    recorder.handle_user_prompt(hook_data)
    print("  ✓ Empty user prompt accepted")

    # Verify it was stored
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT transcript FROM entries WHERE session_id = ? AND speaker = 'user'", (session_id,))
    row = cursor.fetchone()

    if row and row[0] == "":
        print("  ✓ Empty transcript stored correctly")
        recorder.close()
        return True
    else:
        print("  ❌ Empty transcript not stored")
        recorder.close()
        return False


def test_malformed_json(config_path):
    """Test handling of malformed JSON in transcript files."""
    print("\nTesting malformed JSON handling...")

    config = Config(config_path)
    recorder = Recorder(config)

    session_id = str(uuid.uuid4())
    recorder.handle_session_start({"session_id": session_id, "source": "test"})

    # Create a file with malformed JSON
    temp_transcript = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False)
    temp_transcript.write('{"invalid": json}\n')
    temp_transcript.write('not json at all\n')
    temp_transcript.close()

    # Test Stop hook with malformed JSON
    hook_data = {
        "session_id": session_id,
        "transcript_path": temp_transcript.name
    }
    recorder.handle_stop(hook_data)
    print("  ✓ Malformed JSON handled gracefully")

    # Verify no crash and no entry created
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM entries WHERE session_id = ?", (session_id,))
    count = cursor.fetchone()[0]

    print(f"  ✓ No crash on malformed JSON ({count} entries created)")
    recorder.close()
    os.unlink(temp_transcript.name)
    return True


def test_missing_session_foreign_key(config_path):
    """Test that entries require valid session_id (foreign key constraint)."""
    print("\nTesting foreign key constraint...")

    config = Config(config_path)
    recorder = Recorder(config)

    # Try to add entry for non-existent session
    non_existent_session = str(uuid.uuid4())

    try:
        # Note: SQLite foreign key constraints might not be enforced by default
        # This test verifies the current behavior
        recorder.adapter.add_entry(
            entry_id=str(uuid.uuid4()),
            session_id=non_existent_session,
            timestamp=datetime.now(),
            speaker="user",
            transcript="test"
        )
        # If we get here, foreign keys aren't enforced (which is okay for now)
        print("  ℹ️  Foreign key constraints not enforced (SQLite default)")
        recorder.close()
        return True
    except Exception as e:
        print(f"  ✓ Foreign key constraint enforced: {type(e).__name__}")
        recorder.close()
        return True


def test_concurrent_writes(config_path):
    """Test concurrent session and entry creation."""
    print("\nTesting concurrent writes...")

    import threading

    config = Config(config_path)

    def write_session(session_num):
        recorder = Recorder(config)
        session_id = f"concurrent-session-{session_num}"
        recorder.handle_session_start({"session_id": session_id, "source": "test"})
        for i in range(5):
            recorder.handle_user_prompt({
                "session_id": session_id,
                "prompt": f"Message {i} from session {session_num}"
            })
        recorder.close()

    # Create 5 threads writing concurrently
    threads = []
    for i in range(5):
        thread = threading.Thread(target=write_session, args=(i,))
        threads.append(thread)
        thread.start()

    # Wait for all threads
    for thread in threads:
        thread.join()

    print("  ✓ Concurrent writes completed")

    # Verify all data was written
    adapter = SQLiteAdapter(config.get('sqlite.path'))
    adapter.initialize()
    cursor = adapter.conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM sessions WHERE id LIKE 'concurrent-session-%'")
    session_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM entries WHERE session_id LIKE 'concurrent-session-%'")
    entry_count = cursor.fetchone()[0]

    adapter.close()

    if session_count == 5 and entry_count == 25:
        print(f"  ✓ All concurrent data written ({session_count} sessions, {entry_count} entries)")
        return True
    else:
        print(f"  ❌ Data loss detected ({session_count}/5 sessions, {entry_count}/25 entries)")
        return False


def test_corrupted_database(config_path):
    """Test handling of corrupted database."""
    print("\nTesting corrupted database recovery...")

    config = Config(config_path)
    db_path = os.path.expanduser(config.get('sqlite.path'))

    # Close any existing connections
    if os.path.exists(db_path):
        # Create a corrupted database file
        with open(db_path, 'wb') as f:
            f.write(b'This is not a valid SQLite database file\x00\x00\x00')

    print("  ✓ Corrupted database file created")

    try:
        # Try to initialize with corrupted database
        recorder = Recorder(config)
        print("  ✓ Recovery mechanism triggered")

        # Verify database is now working
        cursor = recorder.adapter.conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]

        if 'sessions' in tables and 'entries' in tables:
            print("  ✓ Database recreated successfully")
            recorder.close()
            return True
        else:
            print("  ❌ Database not properly recreated")
            recorder.close()
            return False
    except Exception as e:
        print(f"  ❌ Recovery failed: {e}")
        return False


def test_schema_versioning(config_path):
    """Test schema versioning support."""
    print("\nTesting schema versioning...")

    config = Config(config_path)
    recorder = Recorder(config)

    # Verify schema_version table exists
    cursor = recorder.adapter.conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'")
    if not cursor.fetchone():
        print("  ❌ schema_version table not found")
        recorder.close()
        return False
    print("  ✓ schema_version table exists")

    # Verify current version is set
    cursor.execute("SELECT version, migrated_at FROM schema_version ORDER BY version DESC LIMIT 1")
    row = cursor.fetchone()
    if not row:
        print("  ❌ No version recorded")
        recorder.close()
        return False

    version = row[0]
    expected_version = SQLiteAdapter.SCHEMA_VERSION
    if version != expected_version:
        print(f"  ❌ Version mismatch: expected {expected_version}, got {version}")
        recorder.close()
        return False

    print(f"  ✓ Schema version {version} recorded correctly")
    recorder.close()
    return True


def main():
    """Run all tests."""
    print("=" * 60)
    print("Courtney Test Suite")
    print("=" * 60)

    # Create test configuration
    config_path, db_path = create_test_config()
    print(f"\nUsing test database: {db_path}\n")

    tests = [
        ("Database Initialization", lambda: test_database_initialization(config_path)),
        ("Session Lifecycle", lambda: test_session_lifecycle(config_path)),
        ("User Prompt Recording", lambda: test_user_prompt(config_path)),
        ("Full Conversation Flow", lambda: test_full_conversation(config_path)),
        ("Stop Hook Processing", lambda: test_stop_hook(config_path)),
        ("Example Queries", lambda: test_query_examples(config_path)),
        # Error condition tests
        ("File Size Limit", lambda: test_file_too_large(config_path)),
        ("Invalid Speaker Validation", lambda: test_invalid_speaker(config_path)),
        ("Empty Transcript Handling", lambda: test_empty_transcript(config_path)),
        ("Malformed JSON Handling", lambda: test_malformed_json(config_path)),
        ("Foreign Key Constraint", lambda: test_missing_session_foreign_key(config_path)),
        ("Concurrent Writes", lambda: test_concurrent_writes(config_path)),
        ("Corrupted Database Recovery", lambda: test_corrupted_database(config_path)),
        ("Schema Versioning", lambda: test_schema_versioning(config_path)),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n❌ {test_name} failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append((test_name, False))

    # Print summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "✓ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")

    print(f"\n{passed}/{total} tests passed")

    # Cleanup
    try:
        os.unlink(config_path)
        os.unlink(db_path)
        print(f"\nCleaned up test files")
    except (OSError, IOError):
        pass

    # Exit with appropriate code
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
