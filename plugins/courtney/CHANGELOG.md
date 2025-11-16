# Changelog

All notable changes to Courtney will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-11-16

### Added
- **Schema Versioning**: Added database schema versioning support for safe future migrations
  - New `schema_version` table tracks database schema version
  - Automatic migration framework for future schema changes
  - Current schema version: 1
- **Comprehensive Error Condition Tests**: Added 7 new test cases covering edge cases
  - File size limit handling
  - Invalid speaker validation
  - Empty transcript handling
  - Malformed JSON handling
  - Foreign key constraint verification
  - Concurrent write testing
  - Corrupted database recovery

### Changed
- **Improved Exception Handling**: Replaced bare `except:` clauses with specific exception types
  - `recorder.py`: Now catches only `(IOError, OSError)` in `_log_error()`
  - `courtney_hook.py`: Now catches only `(IOError, OSError)` in `_log_to_file()`
  - `sqlite.py`: Now catches only `(OSError, IOError)` in database corruption recovery
- **Better Logging**: Replaced `print()` with proper logging in `config.py`
  - Now uses Python's `logging` module for configuration warnings
  - More appropriate for hook/daemon context

### Fixed
- Configuration loading no longer outputs to stdout (uses logging instead)
- Exception handling is now more precise and won't mask programming errors

### Technical Details
- Test suite expanded from 6 to 14 tests (133% increase)
- All tests passing (14/14)
- Backward compatible with existing databases

## [1.0.0] - 2025-11-03

### Added
- Initial release of Courtney
- Records Claude Code conversations to SQLite database
- Session lifecycle tracking (start/end)
- Full transcript recording for:
  - User prompts (no truncation)
  - AI responses (no truncation)
  - Subagent reports (no truncation)
- SQLite adapter with:
  - Thread-safe operations
  - WAL mode for better concurrency
  - Automatic corruption detection and recovery
  - Parameterized queries (SQL injection prevention)
  - File size validation (10MB limit)
  - Path validation and security checks
- `/courtney:readback` command for viewing transcripts
- Comprehensive test suite
- Plugin system integration
- Security features:
  - SQL injection prevention via parameterized queries
  - File size limits
  - Path validation
  - Speaker validation via CHECK constraints
- Documentation:
  - README with installation and usage instructions
  - CLAUDE.md with project guidelines
  - Example SQL queries
  - Database schema documentation

### Security
- All database operations use parameterized queries
- Transcript file paths are validated before reading
- Maximum file size enforced (10MB)
- Speaker types validated via database CHECK constraint

[1.0.1]: https://github.com/acostanzo/quickstop/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/acostanzo/quickstop/releases/tag/v1.0.0
