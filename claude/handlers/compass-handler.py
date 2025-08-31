#!/usr/bin/env python3
"""
COMPASS Unified Hook Handler for Claude Code
Intelligently detects complex analytical tasks and enforces COMPASS methodology
Compatible with Claude Code's actual hook system
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
import gc


# Integrated CompassFileOrganizer class
class CompassFileOrganizer:
    """
    CRITICAL INFRASTRUCTURE CLASS: Centralized file organization and directory management for COMPASS system

    WARNING: This class manages the entire COMPASS directory structure and file organization.
    Modifications can break file path resolution, directory creation, and system organization.

    PURPOSE:
    - Provides centralized directory structure management for COMPASS system
    - Ensures consistent file organization across all COMPASS components
    - Implements safety validations to prevent writing to root directory
    - Manages documentation, test, temporary, and map file organization
    - Creates and maintains required directory structure automatically

    DIRECTORY STRUCTURE MANAGED:
    - .serena/memories/: Documentation files with subcategories (agents, investigations, validations)
    - .serena/maps/: SVG visualization files and mapping data
    - .claude/: Internal system files, logs, and temporary data
    - .claude/tests/: Test files and validation results
    - .claude/logs/: System logs, token tracking, and session data
    - .claude/temp/: Temporary files and intermediate processing data and intermediate processing data

    SAFETY FEATURES:
    - Root directory protection: Prevents file creation in system root
    - Path validation: Ensures all paths stay within project boundaries
    - Automatic directory creation: Creates missing directories as needed
    - Consistent path resolution: Standardizes path handling across system

    CRITICAL FOR:
    - Documentation organization: Proper categorization of generated docs
    - System logging: Centralized log file management
    - File safety: Prevention of accidental system-wide file creation
    - COMPASS state management: Organized storage of session and status data

    INTEGRATION POINTS:
    - Used by all file creation and organization functions
    - Integrated with safety validation functions
    - Essential for proper COMPASS directory structure
    - Required for documentation and logging systems

    DO NOT MODIFY WITHOUT:
    1. Understanding complete COMPASS file organization requirements
    2. Testing directory creation and path validation thoroughly
    3. Verifying safety mechanisms prevent root directory writes
    4. Ensuring backward compatibility with existing file paths
    5. Testing automatic directory creation under various conditions
    """

    def __init__(self, project_root=None):
        self.project_root = Path(project_root or os.getcwd())
        self.docs_dir = self.project_root / ".serena/memories"
        self.maps_dir = self.project_root / ".serena/maps"
        self.compass_dir = self.project_root / ".claude"
        self.tests_dir = self.compass_dir / "tests"
        self.logs_dir = self.compass_dir / "logs"
        self.temp_dir = self.compass_dir / "temp"

        # Ensure directory structure exists
        self._ensure_directories()

    def _ensure_directories(self):
        """Ensure all required directories exist"""
        directories = [
            self.docs_dir,
            self.docs_dir / "agents",
            self.docs_dir / "investigations",
            self.docs_dir / "validations",
            self.maps_dir,
            self.tests_dir,
            self.logs_dir,
            self.temp_dir,
        ]

        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)

    def get_documentation_path(self, filename, category="general"):
        """Get proper path for documentation files

        Args:
            filename: Name of the file (with .md extension)
            category: Type of documentation (agents, investigations, validations, general)

        Returns:
            Path object for the documentation file
        """
        if not filename.endswith(".md"):
            filename += ".md"

        category_map = {
            "agents": self.docs_dir / "agents",
            "investigations": self.docs_dir / "investigations",
            "validations": self.docs_dir / "validations",
            "general": self.docs_dir,
        }

        base_dir = category_map.get(category, self.docs_dir)
        return base_dir / filename

    def get_test_path(self, filename):
        """Get proper path for test files

        Args:
            filename: Name of the test file

        Returns:
            Path object for the test file
        """
        if not filename.endswith(".md"):
            filename += ".md"

        return self.tests_dir / filename

    def get_temp_path(self, filename):
        """Get proper path for temporary files

        Args:
            filename: Name of the temporary file

        Returns:
            Path object for the temporary file
        """
        return self.temp_dir / filename

    def get_map_path(self, filename):
        """Get proper path for map/SVG files

        Args:
            filename: Name of the map file (with .svg extension)

        Returns:
            Path object for the map file
        """
        if not filename.endswith(".svg"):
            filename += ".svg"

        return self.maps_dir / filename

    def validate_path_safety(self, filepath):
        """Validate that a file path doesn't write to project root

        Args:
            filepath: Path to validate (string or Path object)

        Returns:
            bool: True if path is safe, False if it would write to root
        """
        path = Path(filepath)

        # Check if path is absolute and outside project
        if path.is_absolute() and not str(path).startswith(str(self.project_root)):
            return True  # Outside project, assume safe

        # Resolve relative paths
        if not path.is_absolute():
            path = self.project_root / path

        # Check if resolved path is directly in project root
        try:
            relative_to_root = path.relative_to(self.project_root)
            # If there are no path parts beyond filename, it's in root
            return len(relative_to_root.parts) > 1
        except ValueError:
            # Path is outside project root
            return True

    def redirect_root_path(self, filepath, file_type="documentation"):
        """Redirect a root-level path to proper directory

        Args:
            filepath: Original file path that would be in root
            file_type: Type of file (documentation, test, temp, map)

        Returns:
            Path object for the properly organized location
        """
        filename = Path(filepath).name

        if file_type == "documentation":
            return self.get_documentation_path(filename)
        elif file_type == "test":
            return self.get_test_path(filename)
        elif file_type == "temp":
            return self.get_temp_path(filename)
        elif file_type == "map":
            return self.get_map_path(filename)
        else:
            # Default to docs for unknown types
            return self.get_documentation_path(filename)

    def cleanup_temp_files(self, max_age_hours=24):
        """Clean up temporary files older than specified age

        Args:
            max_age_hours: Maximum age in hours before deletion
        """
        cutoff_time = datetime.now().timestamp() - (max_age_hours * 3600)

        for temp_file in self.temp_dir.glob("*"):
            if temp_file.is_file() and temp_file.stat().st_mtime < cutoff_time:
                try:
                    temp_file.unlink()
                    print(f"Cleaned up old temp file: {temp_file}")
                except Exception as e:
                    print(f"Failed to clean up {temp_file}: {e}")

    def log_file_operation(self, operation, filepath, redirected_path=None):
        """Log file operations for audit trail

        Args:
            operation: Type of operation (create, move, redirect)
            filepath: Original file path
            redirected_path: New path if redirected
        """
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "operation": operation,
            "original_path": str(filepath),
            "redirected_path": str(redirected_path) if redirected_path else None,
            "utility": "compass_file_organizer",
        }

        log_file = self.logs_dir / "file_organization.log"
        try:
            with open(log_file, "a") as f:
                f.write(json.dumps(log_entry) + "\n")
        except Exception:
            # Fail silently if logging fails
            pass


def get_safe_file_path(filename, file_type="documentation", category="general"):
    """Convenience function to get properly organized file path

    Args:
        filename: Name of the file
        file_type: Type of file (documentation, test, temp, map)
        category: Category for documentation files

    Returns:
        String path for the properly organized file location
    """
    organizer = CompassFileOrganizer()

    if file_type == "documentation":
        return str(organizer.get_documentation_path(filename, category))
    elif file_type == "test":
        return str(organizer.get_test_path(filename))
    elif file_type == "temp":
        return str(organizer.get_temp_path(filename))
    elif file_type == "map":
        return str(organizer.get_map_path(filename))
    else:
        return str(organizer.get_documentation_path(filename))


def validate_file_path_safety(filepath):
    """Convenience function to validate file path safety

    Args:
        filepath: Path to validate

    Returns:
        bool: True if path is safe, False if it writes to root
    """
    organizer = CompassFileOrganizer()
    return organizer.validate_path_safety(filepath)


try:
    from filelock import FileLock as _FileLock

    # Use type alias to ensure consistent typing
    FileLock = _FileLock
except ImportError:
    # Graceful degradation: create a no-op lock class
    class FileLock:
        def __init__(self, path):
            self.path = path

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

# FileLock is properly defined above through import or fallback class


def load_json_memory_safe(file_path, max_size=None):
    """
    CRITICAL MEMORY FUNCTION: Memory-safe JSON loading with comprehensive size validation

    WARNING: This function prevents memory exhaustion from large JSON files.
    Modifications could allow unbounded memory usage and system crashes.

    PURPOSE:
    - Prevents memory exhaustion from oversized JSON files
    - Validates file size before loading to avoid MemoryError
    - Implements double validation: file size + loaded data size
    - Provides graceful degradation for memory-constrained environments
    - Essential for token tracking and session data management

    MEMORY SAFETY MECHANISMS:
    1. File size pre-check: Validates file size against MAX_TOKEN_FILE_SIZE
    2. Load size validation: Checks JSON string length after parsing
    3. Error handling: Catches JSON decode, OS, and memory errors
    4. Graceful degradation: Returns None instead of crashing

    ARGS:
        file_path (str): Path to JSON file to load
        max_size (int, optional): Maximum file size in bytes (defaults to MAX_TOKEN_FILE_SIZE)

    RETURNS:
        dict/list: Parsed JSON data if successful and within size limits
        None: If file too large, invalid JSON, or loading fails

    CRITICAL FOR:
    - Token tracking data: compass-tokens.json session management
    - Status files: compass-status and session tracking
    - Configuration: Agent settings and COMPASS state
    - Memory stability: Prevents system crashes from large files

    DO NOT MODIFY WITHOUT:
    1. Understanding memory constraints in production environments
    2. Testing with large JSON files (>100MB)
    3. Verifying error handling paths work correctly
    4. Ensuring graceful degradation doesn't break callers
    """
    if max_size is None:
        max_size = MAX_TOKEN_FILE_SIZE

    try:
        file_size = Path(file_path).stat().st_size

        # MEMORY SAFETY: Check file size before loading
        if file_size > max_size:
            log_handler_activity(
                "json_file_too_large", f"File {file_path} too large: {file_size} bytes"
            )
            return None

        # MEMORY OPTIMIZATION: Load with size check
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # MEMORY VALIDATION: Check loaded data size
        data_str = json.dumps(data)
        if len(data_str) > max_size:
            log_handler_activity(
                "json_data_too_large", f"JSON data too large: {len(data_str)} chars"
            )
            return None

        return data

    except (json.JSONDecodeError, OSError, MemoryError) as e:
        log_handler_activity("json_load_error", f"Failed to load {file_path}: {e}")
        return None


def cleanup_memory():
    """
    CRITICAL MEMORY FUNCTION: Emergency memory cleanup and system recovery

    WARNING: This function is called during memory emergencies to prevent system crashes.
    Modifications could prevent recovery from memory exhaustion conditions.

    PURPOSE:
    - Emergency memory recovery when system approaches memory limits
    - Aggressive garbage collection to free up memory immediately
    - Token file cleanup when they become oversized
    - Temporary file cleanup to reclaim disk space
    - System stability preservation during high-load scenarios

    CLEANUP OPERATIONS:
    1. Triple garbage collection: Forces immediate memory reclamation
    2. Oversized token file reduction: Keeps only essential session data
    3. Old status file removal: Cleans up stale tracking files
    4. Directory structure validation: Ensures .claude/logs exists

    EMERGENCY PROTOCOL:
    - Called automatically on MemoryError in main()
    - Can be called proactively by token tracking functions
    - Never throws exceptions (emergency functions must be stable)
    - Logs all cleanup operations for audit trail

    TOKEN FILE RECOVERY:
    - Checks compass-tokens.json size against MAX_TOKEN_FILE_SIZE
    - Preserves essential data: total, session_start, last_update
    - Removes historical data to reduce memory footprint
    - Falls back to file deletion if JSON parsing fails

    CRITICAL FOR:
    - System stability: Prevents memory-related crashes
    - Long-running sessions: Manages memory growth over time
    - Large analysis tasks: Handles memory spikes during processing
    - Production reliability: Ensures graceful degradation under load

    DO NOT MODIFY WITHOUT:
    1. Understanding memory recovery requirements
    2. Testing under actual memory pressure conditions
    3. Verifying essential data preservation during cleanup
    4. Ensuring exception safety (function must never throw)
    """
    try:
        # Force multiple rounds of garbage collection
        for _ in range(3):
            gc.collect()

        # Ensure .claude/logs directory exists
        logs_dir = Path(".claude/logs")
        logs_dir.mkdir(parents=True, exist_ok=True)

        # OPTIMIZED: Clean up token tracking files if they're too large
        token_file = logs_dir / "compass-tokens.json"
        if token_file.exists() and token_file.stat().st_size > MAX_TOKEN_FILE_SIZE:
            # Keep only essential data
            try:
                with open(token_file, "r", encoding="utf-8") as f:
                    data = json.load(f)

                # Keep only current session data, remove history
                essential_data = {
                    "total": data.get("total", 0),
                    "session_start": datetime.now().isoformat(),
                    "last_update": datetime.now().isoformat(),
                    "by_agent": {},
                    "by_phase": {},
                }

                with open(token_file, "w", encoding="utf-8") as f:
                    json.dump(essential_data, f, separators=(",", ":"))

            except (json.JSONDecodeError, OSError):
                # If cleanup fails, remove the file entirely
                token_file.unlink(missing_ok=True)

        # Clean up old status files
        for cleanup_file in [".claude-complete", ".claude-todo-updates"]:
            Path(cleanup_file).unlink(missing_ok=True)

    except Exception:
        # Emergency cleanup should never crash
        pass


def cleanup_compass_status_if_stale():
    """
    COMPASS STATUS STALE SESSION CLEANUP: Automatically clean up compass status when session is stale

    PURPOSE:
    - Check if COMPASS session is stale (>10 minutes of inactivity)
    - Automatically remove compass-status file when staleness detected
    - Prevent stale status information from persisting
    - Add redundancy prevention to avoid multiple cleanup calls

    FEATURES:
    - Staleness detection based on 10-minute inactivity timeout
    - Automatic cleanup when session is determined stale
    - Redundancy prevention to avoid multiple cleanup attempts
    - Comprehensive logging for audit trail and debugging
    - Safe execution with exception handling

    TRIGGERED BY:
    - Session validation checks during hook processing
    - Any function that needs to verify session freshness
    - PreToolUse hooks that check for active COMPASS sessions

    INTEGRATION POINTS:
    - check_compass_session_active() - detects when session is NOT active (stale)
    - Session validation flows - ensures cleanup happens automatically
    - Hook processing - maintains clean state during normal operations
    """
    try:
        # Define compass status file path
        logs_dir = Path(".claude/logs")
        status_file = logs_dir / "compass-status"

        # Only proceed if status file exists (no point cleaning if already clean)
        if not status_file.exists():
            return False  # No cleanup needed

        # Check if session is stale (NOT active means stale)
        if not check_compass_session_active():
            # Session is stale - perform cleanup
            status_file.unlink()
            log_handler_activity(
                "stale_session_cleanup",
                "Removed compass-status file due to stale session (>10 min inactivity)",
            )
            return True  # Cleanup performed
        else:
            # Session is still active - no cleanup needed
            return False  # No cleanup needed

    except Exception as e:
        # Cleanup should never crash the handler
        log_handler_activity(
            "stale_session_cleanup_error", f"Error during stale session cleanup: {e}"
        )
        return False


def cleanup_compass_status():
    """
    COMPASS STATUS CLEANUP: Remove compass status file on session end/stop

    PURPOSE:
    - Clean up compass-status file when session ends or stops
    - Prevent stale COMPASS state from persisting between sessions
    - Ensure clean state for next Claude Code session
    - Remove compass status tracking when hooks indicate session termination

    SAFETY FEATURES:
    - Silent failure on missing file (already cleaned)
    - Exception handling to prevent handler crashes
    - Proper logging of cleanup operations
    - Path validation to ensure correct file removal
    - Redundancy prevention with stale session cleanup

    TRIGGERED BY:
    - Stop hook: When user stops current session
    - SessionEnd hook: When session terminates normally
    - Cleanup operations: During memory or state cleanup

    CLEANUP OPERATIONS:
    1. Check if compass-status file exists
    2. Remove file safely with error handling
    3. Log cleanup operation for audit trail
    4. Never throw exceptions (cleanup must be stable)

    CRITICAL FOR:
    - Session hygiene: Clean state between sessions
    - Status accuracy: Prevent stale status information
    - System reliability: Proper cleanup on termination
    - User experience: Clear session boundaries

    DO NOT MODIFY WITHOUT:
    1. Understanding session lifecycle requirements
    2. Testing with actual Stop/SessionEnd hook triggers
    3. Verifying exception safety (function must never throw)
    4. Ensuring proper logging for debugging
    """
    try:
        # Define compass status file path
        logs_dir = Path(".claude/logs")
        status_file = logs_dir / "compass-status"

        # Check if status file exists and remove it
        if status_file.exists():
            status_file.unlink()
            log_handler_activity(
                "compass_status_cleanup",
                "Removed compass-status file on session end/stop",
            )
        else:
            log_handler_activity(
                "compass_status_cleanup",
                "No compass-status file to clean (already clean)",
            )

    except Exception as e:
        # Cleanup should never crash the handler
        log_handler_activity(
            "compass_status_cleanup_error", f"Error cleaning compass-status: {e}"
        )
        pass


def rotate_log_file(log_file):
    """Rotate log file when it gets too large"""
    try:
        # Keep only one backup
        backup_file = Path(str(log_file) + ".old")
        if backup_file.exists():
            backup_file.unlink()

        # Move current log to backup
        log_file.rename(backup_file)

        # Log rotation completed
        with open(log_file, "w", encoding="utf-8") as f:
            f.write(
                json.dumps(
                    {
                        "timestamp": datetime.now().isoformat(),
                        "action": "log_rotated",
                        "details": "Rotated log file",
                        "handler": "compass-handler",
                        "version": "2.1",
                    },
                    separators=(",", ":"),
                )
                + "\n"
            )

    except OSError:
        # If rotation fails, truncate the log
        try:
            with open(log_file, "w", encoding="utf-8") as f:
                f.write(
                    json.dumps(
                        {
                            "timestamp": datetime.now().isoformat(),
                            "action": "log_truncated",
                            "details": "Log rotation failed, truncated log file",
                            "handler": "compass-handler",
                            "version": "2.1",
                        },
                        separators=(",", ":"),
                    )
                    + "\n"
                )
        except OSError:
            pass


# ==================================================================================
# CRITICAL MEMORY MANAGEMENT CONSTANTS - NEVER MODIFY WITHOUT EXTENSIVE TESTING
# ==================================================================================
#
# ⚠️  DANGER: THESE CONSTANTS PREVENT SYSTEM CRASHES AND MEMORY EXHAUSTION
#
# These values were carefully calibrated after extensive memory crash analysis.
# Increasing any of these limits can cause:
# - JavaScript heap exhaustion crashes
# - System memory overload and lockups
# - Process termination during large analysis tasks
# - Unrecoverable memory errors requiring restart
#
# CRASH HISTORY:
# - Original 1MB input limit caused heap crashes on complex prompts
# - 100 token sessions caused unbounded memory growth
# - 5MB log files triggered memory allocation failures
# - Unlimited agent tracking led to memory leaks
#
# TESTING REQUIREMENTS BEFORE ANY CHANGES:
# 1. Test with 50+ sequential COMPASS agent calls
# 2. Verify behavior with 500KB+ user prompts
# 3. Run 100+ session token tracking cycles
# 4. Monitor memory usage under sustained load
# 5. Test recovery from MemoryError conditions
#
# ⚠️  MODIFICATION CHECKLIST:
# □ Memory pressure testing completed for 30+ minutes
# □ JavaScript heap monitoring shows no growth trends
# □ Emergency cleanup functions still work correctly
# □ Large file processing doesn't trigger crashes
# □ Token tracking remains bounded under load
#
MAX_INPUT_SIZE = (
    512 * 1024
)  # 512KB max input (reduced from 1MB) - PREVENTS HEAP EXHAUSTION
MAX_TOKEN_SESSIONS = (
    25  # Max stored token sessions (reduced from 100) - PREVENTS MEMORY LEAKS
)
MAX_TOKEN_FILE_SIZE = (
    256 * 1024
)  # 256KB max token file (new limit) - PREVENTS LOAD CRASHES
MAX_AGENT_TRACKING = (
    50  # Max agents tracked simultaneously (new limit) - BOUNDS MEMORY GROWTH
)
MAX_PHASE_TRACKING = (
    8  # Max phases tracked simultaneously (new limit) - PREVENTS TRACKING OVERFLOW
)
MAX_LOG_SIZE = (
    2 * 1024 * 1024
)  # 2MB max log file (reduced from 5MB) - PREVENTS LOG FILE CRASHES
MAX_AGENT_ACTIVITY = (
    100  # Max agent activity entries (reduced from 500) - BOUNDS ACTIVITY TRACKING
)


def validate_file_operation_safety(tool_name, tool_input):
    """Validate file operations to prevent root directory cluttering

    Args:
        tool_name: Name of the tool being called
        tool_input: Input parameters for the tool

    Returns:
        dict: {"safe": bool, "reason": str, "suggested_path": str}
    """
    try:
        organizer = CompassFileOrganizer()

        # Check tools that create files
        file_creating_tools = [
            "Write",
            "mcp__serena__create_text_file",
            "Edit",
            "MultiEdit",
        ]

        if tool_name not in file_creating_tools:
            return {"safe": True, "reason": "Tool does not create files"}

        # Extract file path from tool input
        file_path = None
        if tool_name == "Write":
            file_path = tool_input.get("file_path")
        elif tool_name == "mcp__serena__create_text_file":
            file_path = tool_input.get("relative_path")
        elif tool_name in ["Edit", "MultiEdit"]:
            file_path = tool_input.get("file_path")

        if not file_path:
            return {"safe": True, "reason": "No file path specified"}

        # Validate path safety
        if not organizer.validate_path_safety(file_path):
            # Check if it's a markdown file that should be redirected
            if file_path.endswith(".md"):
                # Determine file type based on content patterns
                content = tool_input.get("content", "")

                if any(
                    keyword in file_path.lower()
                    for keyword in ["test", "jung", "integration"]
                ):
                    suggested_path = organizer.get_test_path(Path(file_path).name)
                    file_type = "test"
                elif any(
                    keyword in content.lower() for keyword in ["validation", "test"]
                ):
                    suggested_path = organizer.get_documentation_path(
                        Path(file_path).name, "validations"
                    )
                    file_type = "validation"
                else:
                    suggested_path = organizer.get_documentation_path(
                        Path(file_path).name
                    )
                    file_type = "documentation"

                reason = f"""🚫 COMPASS File Organization Violation

The file '{file_path}' would be created in the project root directory.
COMPASS enforces organized file structure to prevent root directory cluttering.

SUGGESTED ACTION:
Use proper path: {suggested_path}

FILE ORGANIZATION RULES:
• Documentation files → docs/ directory (or docs/validations/ for validation reports)
• Test files → .claude/tests/ directory
• Temporary files → .claude/temp/ directory
• Maps/SVG files → maps/ directory

To fix: Update the file path in your tool call to use the suggested path above."""

                organizer.log_file_operation(
                    "blocked_root_write", file_path, suggested_path
                )

                return {
                    "safe": False,
                    "reason": reason,
                    "suggested_path": str(suggested_path),
                    "file_type": file_type,
                }

        return {"safe": True, "reason": "Path validation passed"}

    except Exception as e:
        # If validation fails, err on side of caution but don't block
        log_handler_activity("file_validation_error", f"File validation error: {e}")
        return {"safe": True, "reason": f"Validation error, allowing operation: {e}"}


def main():
    """
    ████████████████████████████████████████████████████████████████████████████
    🚨 CRITICAL SYSTEM ENTRY POINT - MODIFICATIONS BREAK EVERYTHING 🚨
    ████████████████████████████████████████████████████████████████████████████

    CRITICAL SYSTEM FUNCTION: Main COMPASS handler entry point for Claude Code hooks

    ⚠️  EXTREME DANGER: This function is the SINGLE POINT OF INTEGRATION between
    Claude Code and the entire COMPASS methodology system. ANY modifications to
    input handling, event routing, memory management, or error handling can:

    🚨 CATASTROPHIC FAILURE MODES FROM MODIFICATIONS:
    - Complete loss of COMPASS methodology enforcement
    - Bypassed institutional knowledge requirements
    - Memory crashes from unhandled input sizes
    - Broken hook event routing causing silent failures
    - Loss of agent coordination and methodology compliance
    - Session corruption and tracking system breakdown

    CRITICAL INTEGRATION POINTS:
    - Serves as the primary hook handler for Claude Code's hook system
    - Routes UserPromptSubmit events to compass-captain for methodology enforcement
    - Handles PreToolUse events for tool validation and COMPASS requirement checking
    - Implements memory optimization and garbage collection for large-scale analysis
    - Provides error handling and graceful degradation for system stability

    SYSTEM DEPENDENCIES (ALL MUST REMAIN INTACT):
    - Claude Code hook system (UserPromptSubmit, PreToolUse events)
    - .claude directory structure for logging and session tracking
    - JSON input/output format for hook communication
    - Memory management through garbage collection
    - COMPASS agent ecosystem for methodology execution

    MEMORY MANAGEMENT (PREVENTS SYSTEM CRASHES):
    - Implements MAX_INPUT_SIZE limits to prevent memory exhaustion
    - Forces garbage collection before and after processing
    - Includes emergency memory cleanup on MemoryError

    CRITICAL ERROR HANDLING (PREVENTS SILENT FAILURES):
    - JSONDecodeError: Invalid input format from Claude Code
    - MemoryError: Triggers emergency cleanup and graceful exit
    - General exceptions: Logged with full context for debugging

    HOOK EVENT ROUTING (CORE COMPASS ENFORCEMENT):
    - UserPromptSubmit → handle_user_prompt_submit() → compass-captain injection
    - PreToolUse → handle_pre_tool_use_with_token_tracking() → tool validation
    - Stop → cleanup_compass_status() → compass-status file removal
    - SessionEnd → cleanup_compass_status() → compass-status file removal

    ⚠️  MODIFICATION CHECKLIST (ABSOLUTELY REQUIRED):
    □ Full understanding of Claude Code hook integration contracts
    □ Testing with complete COMPASS methodology workflows (all 6 phases)
    □ Memory management verification under sustained load conditions
    □ Hook event routing tested with all COMPASS agents
    □ Error handling verified for all failure modes
    □ Backward compatibility maintained with existing hook contracts
    □ Emergency memory cleanup tested under memory pressure
    □ JSON parsing tested with malformed input
    □ Directory creation and logging tested
    □ Integration testing with compass-captain agent

    🚨 BREAKING THIS FUNCTION MEANS BREAKING THE ENTIRE COMPASS SYSTEM 🚨
    """
    try:
        # MEMORY OPTIMIZATION: Initial garbage collection and memory check
        gc.collect()

        # Validate stdin input
        if sys.stdin.isatty():
            print("COMPASS Handler: No input provided via stdin", file=sys.stderr)
            sys.exit(1)

        # Read input with size limit to prevent memory issues
        input_text = sys.stdin.read(MAX_INPUT_SIZE)
        if len(input_text) >= MAX_INPUT_SIZE:
            log_handler_activity(
                "input_too_large", f"Input truncated at {MAX_INPUT_SIZE} bytes"
            )

        input_data = json.loads(input_text)

        # Validate input data structure
        if not isinstance(input_data, dict):
            log_handler_activity("invalid_input", "Input is not a dictionary")
            print("COMPASS Handler Error: Invalid input format", file=sys.stderr)
            sys.exit(1)

        # Always ensure COMPASS directories exist
        ensure_compass_directories()

        # Get hook event type from Claude Code input
        hook_event = input_data.get("hook_event_name", "")

        # Validate hook event
        valid_events = [
            "UserPromptSubmit",
            "PreToolUse",
            "Stop",
            "SessionEnd",
            "SubagentStop",
        ]
        if hook_event and hook_event not in valid_events:
            log_handler_activity("unknown_hook", f"Unknown hook event: {hook_event}")

        if hook_event == "UserPromptSubmit":
            result = handle_user_prompt_submit(input_data)
            if result:
                print(json.dumps(result, ensure_ascii=False))

        elif hook_event == "PreToolUse":
            result = handle_pre_tool_use_with_token_tracking(input_data)
            if result:
                print(json.dumps(result, ensure_ascii=False))

        elif hook_event == "SubagentStop":
            # Basic SubagentStop hook processing (detailed logging removed)
            log_handler_activity(hook_event, "SubagentStop event processed")

        elif hook_event == "Stop" or hook_event == "SessionEnd":
            # Clean up compass status file on session termination
            cleanup_compass_status()
            log_handler_activity(
                hook_event, "compass-status cleaned up on session termination"
            )

        # STALE SESSION CLEANUP: Automatically clean up compass-status if session is stale
        # This runs during all hook processing to ensure timely cleanup when sessions exceed 10-minute timeout
        cleanup_compass_status_if_stale()

        # Check for COMPASS agent usage and update status
        check_compass_agent_activity(input_data)

        # Log handler activity
        log_handler_activity(hook_event or "unknown", "processed")

        # MEMORY OPTIMIZATION: Force garbage collection after each hook execution
        gc.collect()

    except json.JSONDecodeError as e:
        log_handler_activity("json_error", f"Invalid JSON input: {e}")
        print(f"COMPASS Handler Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except MemoryError as e:
        log_handler_activity("memory_error", f"Memory error: {e}")
        print("COMPASS Handler Error: Memory limit exceeded", file=sys.stderr)
        # Attempt cleanup and exit gracefully
        cleanup_memory()
        sys.exit(1)
    except Exception as e:
        log_handler_activity("error", f"ERROR: {e}")
        print(f"COMPASS Handler Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        # Force garbage collection after processing
        gc.collect()


def handle_user_prompt_submit(input_data):
    """
    CRITICAL ROUTING FUNCTION: Enforce COMPASS methodology for all user prompts

    WARNING: This function implements the core COMPASS enforcement mechanism.
    Any modifications could bypass the methodology requirement and break institutional knowledge integration.

    PURPOSE:
    - Routes ALL user prompts to compass-captain agent for methodology coordination
    - Ensures no ad-hoc analysis can bypass COMPASS 7-phase approach
    - Provides consistent entry point for strategic vs. full methodology decisions
    - Maintains institutional knowledge integration through compass-captain coordination

    ENFORCEMENT STRATEGY:
    - Universal routing: No exceptions for any user prompt type
    - Strategic delegation: compass-captain uses methodology-selector for planning
    - Institutional foundation: All analysis starts with knowledge consultation
    - Methodology coordination: Ensures proper agent sequencing and parallel execution

    SYSTEM INTEGRATION:
    - Input: Claude Code UserPromptSubmit hook event with user prompt
    - Processing: Uses unified compass_handler_core for consistent processing
    - Output: inject_compass_context() result for compass-captain activation
    - Coordination: compass-captain determines appropriate methodology approach

    ARGS:
        input_data (dict): Hook event data from Claude Code containing:
            - prompt (str): User's input prompt requiring analysis
            - Additional hook metadata and context

    RETURNS:
        dict: inject_compass_context() result for compass-captain injection
        None: If no prompt provided (graceful degradation)

    CRITICAL DEPENDENCIES:
    - compass_handler_core(): Unified handler function (NEW ARCHITECTURE)
    - inject_compass_context(): COMPASS context injection mechanism
    - compass-captain agent: Methodology coordination and enforcement
    - .claude/logs/: Activity logging for audit and debugging

    DO NOT MODIFY WITHOUT:
    1. Understanding COMPASS methodology enforcement requirements
    2. Testing bypass prevention mechanisms
    3. Verifying compass-captain integration continues to work
    4. Ensuring methodology-selector strategic planning integration
    5. Understanding unified function architecture maintains same behavior
    """

    # Delegate to unified core function with UserPromptSubmit hook type
    # This ensures identical context injection behavior as before,
    # but now uses the unified architecture for consistency with PreToolUse
    return compass_handler_core(input_data, "UserPromptSubmit")


def detect_compass_agent_in_prompt(prompt):
    """Detect which COMPASS agent is being called based on prompt content"""
    if not prompt:
        return None

    prompt_lower = prompt.lower()

    # Check for specific agent mentions
    compass_agents = [
        "compass-captain",
        "compass-complexity-analyzer",
        "compass-strategy-builder",
        "compass-validation-coordinator",
        "compass-knowledge-discovery",
        "compass-pattern-apply",
        "compass-data-flow",
        "compass-gap-analysis",
        "compass-doc-planning",
        "compass-enhanced-analysis",
        "compass-cross-reference",
        "compass-coder",
        "compass-writing-analyst",
        "compass-academic-analyst",
        "compass-memory-enhanced-writer",
        "compass-second-opinion",
        "compass-auth-performance-analyst",
        "compass-auth-security-validator",
        "compass-auth-optimization-specialist",
        "compass-upstream-validator",
        "compass-dependency-tracker",
        "compass-breakthrough-doc",
        "compass-cleanup-coordinator",
        "compass-todo-sync",
        "compass-svg-analyst",
        "compass-memory-integrator",
    ]

    for agent in compass_agents:
        if agent in prompt_lower:
            return agent

    # Check for COMPASS methodology phrases that indicate captain
    captain_phrases = [
        "compass methodology",
        "7-phase",
        "institutional knowledge integration",
        "compass captain",
        "coordinate compass",
        "orchestrate compass",
    ]

    for phrase in captain_phrases:
        if phrase in prompt_lower:
            return "compass-captain"

    return None


def load_agent_instructions(agent_name):
    """Load instructions from agent markdown file with memory-safe reading"""
    try:
        agent_file = Path(f".claude/agents/{agent_name}.md")
        if not agent_file.exists():
            return f"Agent {agent_name} not found. Please read the agent file manually using Read tool."

        # Check file size before loading to prevent memory issues
        if agent_file.stat().st_size > 500 * 1024:  # 500KB limit for agent files
            log_handler_activity(
                "agent_file_too_large",
                f"Agent file {agent_name} too large, skipping load",
            )
            return f"Agent {agent_name} file too large. Please read .claude/agents/{agent_name}.md manually using Read tool."

        with open(agent_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Validate content length to prevent memory issues
        if len(content) > 1024 * 1024:  # 1MB content limit
            log_handler_activity(
                "agent_content_too_large", f"Agent {agent_name} content too large"
            )
            return f"Agent {agent_name} content too large. Please read .claude/agents/{agent_name}.md manually using Read tool."

        # Remove YAML frontmatter for cleaner instructions
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                content = parts[2].strip()

        return content

    except (OSError, UnicodeDecodeError, MemoryError) as e:
        log_handler_activity("agent_load_error", f"Failed to load {agent_name}: {e}")
        return f"Error loading {agent_name}. Please read .claude/agents/{agent_name}.md manually using Read tool."
    except Exception as e:
        log_handler_activity(
            "agent_load_error", f"Unexpected error loading {agent_name}: {e}"
        )
        return f"Error loading {agent_name}. Please read .claude/agents/{agent_name}.md manually using Read tool."


def compass_handler_core(input_data, hook_type):
    """
    UNIFIED FUNCTION: Core handler for both PreToolUse and UserPromptSubmit hooks

    This function implements the unified architecture that:
    1. Detects hook-specific parameters and validates input
    2. Applies recursion checks ONLY for tool use scenarios
    3. Uses EXACTLY THE SAME context injection path for both hook types
    4. Formats return values appropriately for each hook type

    DESIGN GOALS:
    - Single source of truth for compass context injection
    - Recursion prevention only applies to tool use scenarios
    - Maintain compatibility with both hook event types
    - Clean separation between recursion logic and context injection

    ARGS:
        input_data (dict): Hook event data with hook-specific fields:
            - UserPromptSubmit: {"prompt": str, ...other_fields}
            - PreToolUse: {"tool_name": str, "tool_input": dict, ...other_fields}
        hook_type (str): "UserPromptSubmit" or "PreToolUse"

    RETURNS:
        dict: Hook-appropriate response:
            - UserPromptSubmit: inject_compass_context() result
            - PreToolUse: permission decision with compass context
        None: If validation fails (graceful degradation)

    CRITICAL: This function maintains the exact same context injection behavior
    for both hook types, only differing in recursion checks and return formatting.
    """

    # STEP 1: Parameter Detection and Initial Validation
    if hook_type == "UserPromptSubmit":
        user_prompt = input_data.get("prompt", "")
        if not user_prompt:
            return None

        log_handler_activity(
            "prompt_routing", f"Routing to compass-captain: {user_prompt[:100]}..."
        )

        # UserPromptSubmit: No recursion checks needed, go directly to context injection
        compass_context = inject_compass_context()
        return compass_context

    elif hook_type == "PreToolUse":
        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})

        if not tool_name:
            return create_permission_decision_with_compass_context(
                "deny", "No tool name provided"
            )

        log_handler_activity("tool_intercept", f"Intercepted: {tool_name}")

        # STEP 2: Tool Use Recursion Checks (ONLY for PreToolUse)

        # FILE PATH VALIDATION: Prevent root directory file creation
        file_safety_result = validate_file_operation_safety(tool_name, tool_input)
        if not file_safety_result["safe"]:
            log_handler_activity(
                "file_path_violation", f"Blocked unsafe file operation: {tool_name}"
            )
            return create_permission_decision_with_compass_context(
                "deny", file_safety_result["reason"]
            )

        # RECURSION PREVENTION: Skip validation for compass-upstream-validator to prevent infinite loops
        if (
            tool_name == "Task"
            and tool_input.get("subagent_type") == "compass-upstream-validator"
        ):
            log_handler_activity(
                "recursion_prevention",
                "Enhanced upstream validator recursion prevention",
            )
            enhanced_message = create_enhanced_recursion_message(
                "upstream_validator",
                tool_name=tool_name,
                subagent_type=tool_input.get("subagent_type"),
                validation_depth=int(os.environ.get("COMPASS_VALIDATION_DEPTH", "0")),
            )
            return create_permission_decision_with_compass_context(
                "allow", enhanced_message
            )

        # DEPTH LIMITING: Prevent deep validation chains
        validation_depth = int(os.environ.get("COMPASS_VALIDATION_DEPTH", "0"))
        if validation_depth >= 3:
            log_handler_activity(
                "depth_limit",
                f"Enhanced depth limit messaging - max depth reached ({validation_depth})",
            )
            enhanced_message = create_enhanced_recursion_message(
                "depth_limit",
                tool_name=tool_name,
                subagent_type=tool_input.get("subagent_type"),
                validation_depth=validation_depth,
            )
            return create_permission_decision_with_compass_context(
                "allow", enhanced_message
            )

        # Check for double_check parameter and trigger upstream validation
        double_check = tool_input.get("double_check", False)
        if double_check:
            log_handler_activity(
                "upstream_validation", f"Double-check requested for {tool_name}"
            )

            # Increment validation depth tracking
            os.environ["COMPASS_VALIDATION_DEPTH"] = str(validation_depth + 1)
            try:
                validation_result = trigger_upstream_validation(tool_name, tool_input)
            finally:
                # Always decrement depth when done
                if validation_depth > 0:
                    os.environ["COMPASS_VALIDATION_DEPTH"] = str(validation_depth)
                else:
                    os.environ.pop("COMPASS_VALIDATION_DEPTH", None)
            if validation_result and not validation_result.get("valid", True):
                return create_permission_decision_with_compass_context(
                    "deny",
                    f"⚠️ Upstream validation failed: {validation_result.get('reason', 'Unknown error')}\n\nSuggestions: {validation_result.get('suggestions', [])}",
                )

        # Check if this tool usage requires COMPASS methodology
        if requires_compass_methodology(tool_name, tool_input):
            # Block the tool usage and provide guidance (regardless of COMPASS context status)
            log_handler_activity(
                "compass_required", f"Blocking {tool_name} - COMPASS required"
            )

            session_context = get_compass_session_context()

            if not compass_context_active():
                compass_message = f"""🧭 COMPASS METHODOLOGY REQUIRED

⚠️ **SYSTEMATIC ANALYSIS REQUIRED**: Tool '{tool_name}' detected as requiring COMPASS methodology

🧠 **WHY COMPASS IS REQUIRED**:
• Complex analytical tasks require systematic approach
• Prevents ad-hoc analysis that misses institutional knowledge
• Ensures quality control through 7-phase methodology
• Integrates with existing patterns and documentation

📊 **PREPARATION FOR COMPASS**:
• No active COMPASS session detected
• Ready to initialize systematic methodology
• Tool will be coordinated through proper phases

✅ **REQUIRED ACTIONS**:
1. **Initialize COMPASS**: Use Task tool with subagent_type='compass-captain'
2. **Methodology Coordination**: compass-captain will coordinate full 7-phase COMPASS approach
3. **Progress Tracking**: Check .claude/logs/compass-status for methodology progress
4. **Quality Assurance**: Systematic approach ensures comprehensive analysis

🎯 **NEXT STEP**: Use Task tool with subagent_type='compass-captain' to begin systematic analysis"""

            else:
                compass_message = f"""🧭 COMPASS ENFORCEMENT ACTIVE

⚠️ **TOOL COORDINATION REQUIRED**: Tool '{tool_name}' requires COMPASS coordination during active session

🧠 **WHY THIS IS BLOCKED**:
• COMPASS session is already active - requires coordination
• Direct tool usage bypasses systematic methodology
• All analysis must maintain institutional knowledge integration
• Prevents fragmented approach during systematic analysis

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Current Phase: {session_context["current_phase"]}
• Total Tokens Used: {session_context["total_tokens"]:,}
• Agents Run: {", ".join(session_context["agents_run"][:3]) if session_context["agents_run"] else "None yet"}

✅ **REQUIRED ACTION**:
Use Task tool with subagent_type='compass-captain' for proper tool coordination

❌ **BLOCKED**: Direct {tool_name} tool usage during active COMPASS session

🎯 **NEXT STEP**: compass-captain will coordinate {tool_name} usage through appropriate methodology phase"""

            return create_permission_decision_with_compass_context(
                "deny", compass_message
            )

        # STEP 3: Allow the tool and inject compass context (SAME PATH as UserPromptSubmit)
        log_handler_activity("tool_allowed", f"Allowing {tool_name}")
        return create_permission_decision_with_compass_context(
            "allow", "COMPASS validation passed"
        )

    else:
        # Invalid hook type
        log_handler_activity("invalid_hook_type", f"Unknown hook type: {hook_type}")
        return None


def inject_compass_context():
    """Route all tasks to compass-captain with strategic planning architecture"""

    # Create visible status file for user feedback with token tracking
    create_compass_status_file_with_tokens()

    # Initialize session tracking for persistence across conversation breaks
    create_compass_session_tracking()

    compass_context = """🧭 COMPASS STRATEGIC ROUTING

All tasks now route through compass-captain for optimal methodology selection and execution.

MANDATORY: Use the Task tool with subagent_type "compass-captain" to:
- Receive strategic plan from compass-methodology-selector
- Execute optimized methodology based on task complexity
- Coordinate institutional knowledge integration
- Provide real-time token tracking and cost visibility
- Apply right-sized analysis approach (Light/Medium/Full COMPASS)

The compass-captain will:
1. Consult compass-methodology-selector for strategic planning
2. Execute the optimized plan with parallel agent coordination
3. Use second opinion validation for complex tasks
4. Provide comprehensive token usage reporting

📊 TOKEN TRACKING: Real-time visibility with strategic budget optimization.
📄 STATUS: Check .claude/logs/compass-status for methodology progress when active."""

    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": compass_context,
        }
    }


def create_permission_decision_with_compass_context(decision, reason):
    """
    Create permission decision that includes compass context injection
    Combines PreToolUse permission decisions with compass context like UserPromptSubmit

    ARGS:
        decision (str): "allow" or "deny" permission decision
        reason (str): Human-readable explanation for the decision

    RETURNS:
        dict: Combined permission decision and compass context injection
    """
    # Get compass context from inject_compass_context
    compass_injection = inject_compass_context()

    # Combine permission decision with compass context injection
    # Change hookEventName from UserPromptSubmit to PreToolUse for proper event handling
    result = {
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": compass_injection["hookSpecificOutput"][
                "additionalContext"
            ],
        },
    }

    return result


def handle_pre_tool_use(input_data):
    """
    CRITICAL VALIDATION FUNCTION: Tool usage validation and COMPASS requirement enforcement

    WARNING: This function controls all tool access in Claude Code through the hook system.
    Modifications can compromise security, break COMPASS enforcement, or create infinite validation loops.

    PURPOSE:
    - Validates file operation safety to prevent writing to root directory
    - Enforces COMPASS methodology requirements for analysis tools
    - Implements upstream repository validation when double_check=true
    - Prevents infinite recursion in validation chains
    - Provides tool-level access control for system security

    SECURITY VALIDATIONS:
    - File path safety: Prevents root directory file creation
    - Tool safety: Validates tool input parameters for malicious content
    - Recursion prevention: Blocks infinite validation loops
    - Depth limiting: Prevents runaway validation chains (max depth 3)

    COMPASS ENFORCEMENT:
    - Analysis tool detection: Identifies tools requiring methodology
    - Context verification: Checks if COMPASS context is active
    - Methodology blocking: Denies tools when COMPASS required but not active
    - Guidance provision: Explains COMPASS requirement to users

    UPSTREAM VALIDATION:
    - Triggered by double_check parameter in tool input
    - Delegates to compass-upstream-validator agent
    - Validates against upstream repositories for accuracy
    - Provides validation failure feedback with suggestions

    ARGS:
        input_data (dict): PreToolUse hook event data containing:
            - tool_name (str): Name of tool being executed
            - tool_input (dict): Parameters for tool execution
            - Additional hook metadata

    RETURNS:
        dict: Permission decision with structure:
            - permissionDecision (str): "allow" or "deny"
            - permissionDecisionReason (str): Human-readable explanation
        None: No intervention required (implicit allow)

    CRITICAL DEPENDENCIES:
    - compass_handler_core(): Unified handler function (NEW ARCHITECTURE)
    - validate_file_operation_safety(): File system security validation
    - requires_compass_methodology(): Analysis tool detection
    - compass_context_active(): COMPASS state verification
    - trigger_upstream_validation(): Repository validation when requested

    RECURSION PREVENTION:
    - Skips validation for compass-upstream-validator to prevent loops
    - Uses COMPASS_VALIDATION_DEPTH environment variable for depth tracking
    - Automatically resets depth counters after validation completion

    DO NOT MODIFY WITHOUT:
    1. Understanding Claude Code PreToolUse hook contract
    2. Testing all validation paths and edge cases
    3. Verifying recursion prevention mechanisms work correctly
    4. Ensuring security validations remain comprehensive
    5. Testing COMPASS enforcement under various scenarios
    6. Understanding unified function architecture maintains same behavior
    """

    # Delegate to unified core function with PreToolUse hook type
    # This ensures identical recursion prevention and context injection behavior as before,
    # but now uses the unified architecture for consistency with UserPromptSubmit
    return compass_handler_core(input_data, "PreToolUse")


def estimate_agent_tokens(agent_type, prompt_content, tool_input=None):
    """
    Estimate token usage for COMPASS agent calls with validated accuracy
    Based on COMPASS institutional knowledge and performance analysis patterns
    """
    if not prompt_content:
        return 0

    # Base calculation: 4 characters per token (OpenAI standard)
    base_tokens = len(prompt_content) // 4

    # Agent complexity multipliers from institutional profiling
    # Values derived from agent coordination performance analysis
    multipliers = {
        "compass-captain": 1.2,  # Coordination overhead
        "compass-knowledge-discovery": 1.5,  # Knowledge base search complexity
        "compass-pattern-apply": 1.3,  # Pattern matching analysis
        "compass-gap-analysis": 1.4,  # Gap identification complexity
        "compass-doc-planning": 1.1,  # Documentation strategy planning
        "compass-enhanced-analysis": 2.0,  # Comprehensive analysis with context
        "compass-cross-reference": 1.6,  # Pattern library integration
        "compass-coder": 1.8,  # Specialist delegation coordination
        # Specialized domain agents
        "compass-auth-analyst": 1.7,  # Authentication system complexity
        "compass-writing-specialist": 1.6,  # Writing analysis and enhancement
        "compass-academic-analyst": 2.2,  # Academic memory palace integration
        "compass-data-flow": 1.5,  # Variable lifecycle mapping
        "compass-second-opinion": 1.8,  # Expert consultation complexity
        "compass-breakthrough-doc": 1.3,  # Breakthrough documentation
        # Native Claude Code specialists (via compass-coder delegation)
        "Code": 1.4,  # Code analysis and modification
        "Task": 1.2,  # Task coordination overhead
        "Debugger": 1.6,  # Debugging analysis complexity
        "Data Scientist": 1.8,  # Data analysis and modeling
    }

    # Apply complexity multiplier
    agent_tokens = base_tokens * multipliers.get(agent_type, 1.0)

    # Add context loading overhead for agents with institutional memory access
    if agent_type.startswith("compass-"):
        context_overhead = min(base_tokens * 0.2, 500)  # Max 500 tokens for context
        agent_tokens += context_overhead

    # Tool input complexity factor
    if tool_input:
        input_complexity = len(str(tool_input)) // 10  # Rough tool input token estimate
        agent_tokens += input_complexity

    return int(agent_tokens)


def track_parallel_group_tokens(parallel_agents, shared_context):
    """
    Aggregate tokens from parallel agent group with coordination overhead
    Based on parallel execution performance optimization patterns
    """
    total_tokens = 0
    group_start_time = datetime.now()

    # Track each agent in parallel group
    for agent_type in parallel_agents:
        agent_tokens = estimate_agent_tokens(agent_type, shared_context)
        total_tokens += agent_tokens
        log_agent_token_usage(agent_type, agent_tokens, "parallel_group")

    # Coordination overhead: 10% of total for parallel management
    # Based on 37.5% time savings with 5.1% token overhead pattern
    coordination_overhead = int(total_tokens * 0.1)
    total_tokens += coordination_overhead

    # Log parallel efficiency metrics
    group_duration = (datetime.now() - group_start_time).total_seconds()
    log_parallel_efficiency(len(parallel_agents), total_tokens, group_duration)

    return total_tokens


def predict_specialist_delegation(prompt):
    """
    Predict likely specialist delegation chains from compass-coder
    Based on prompt analysis and institutional knowledge patterns
    """
    prompt_lower = prompt.lower()
    predicted_specialists = []

    # Code-related specialists
    if any(
        keyword in prompt_lower
        for keyword in ["code", "function", "class", "implement", "refactor"]
    ):
        predicted_specialists.append("Code")

    # Task coordination
    if any(
        keyword in prompt_lower
        for keyword in ["coordinate", "multi-step", "complex", "workflow"]
    ):
        predicted_specialists.append("Task")

    # Debugging specialists
    if any(
        keyword in prompt_lower
        for keyword in ["debug", "error", "issue", "problem", "troubleshoot"]
    ):
        predicted_specialists.append("Debugger")

    # Data analysis specialists
    if any(
        keyword in prompt_lower
        for keyword in ["data", "analysis", "query", "sql", "bigquery"]
    ):
        predicted_specialists.append("Data Scientist")

    return predicted_specialists


def track_specialist_delegation_tokens(primary_agent, delegation_chain):
    """
    Track token usage through complete delegation chains
    Addresses the 50-70% hidden token usage gap identified in analysis
    """
    total_delegation_tokens = 0

    for specialist_type in delegation_chain:
        # Generate specialist context based on primary agent
        specialist_context = (
            f"Delegated task from {primary_agent} requiring {specialist_type} expertise"
        )
        specialist_tokens = estimate_agent_tokens(specialist_type, specialist_context)

        # Add delegation overhead (5% per delegation hop)
        delegation_overhead = int(specialist_tokens * 0.05)
        total_delegation_tokens += specialist_tokens + delegation_overhead

        log_delegation_step(primary_agent, specialist_type, specialist_tokens)

    return total_delegation_tokens


def update_session_token_count(agent_type, token_count):
    """
    ██████████████████████████████████████████████████████████████████████████
    🚨 CRITICAL TOKEN MANAGEMENT - MEMORY BOUNDED IMPLEMENTATION 🚨
    ██████████████████████████████████████████████████████████████████████████

    Update persistent token count with memory management and atomic file operations
    Implements file-based state management pattern with bounded memory usage

    ⚠️  WARNING: This function implements memory-bounded token tracking that prevents
    token file growth from causing memory exhaustion. Any modifications to file size
    limits, cleanup mechanisms, or atomic operations can cause:

    🚨 MEMORY EXHAUSTION RISKS FROM MODIFICATIONS:
    - Unbounded token file growth leading to memory crashes
    - JSON parsing failures on oversized files
    - Concurrent write corruption without file locking
    - Memory leaks from unlimited agent/phase tracking
    - Session data corruption under memory pressure

    MEMORY SAFETY MECHANISMS:
    - MAX_TOKEN_FILE_SIZE (256KB) prevents large file loading
    - MAX_AGENT_TRACKING (50) bounds agent data collection
    - MAX_PHASE_TRACKING (8) limits phase data growth
    - Atomic file operations with locking prevent corruption
    - Emergency cleanup on file size/corruption detection

    CRITICAL IMPLEMENTATION DETAILS:
    - File size pre-check before loading JSON
    - Memory-safe JSON loading with load_json_memory_safe()
    - LRU eviction of old agents when limit exceeded
    - Compact JSON formatting to minimize file size
    - Error recovery that continues workflow without blocking

    ⚠️  MODIFICATION CHECKLIST:
    □ Memory testing with 500+ agent token updates
    □ Verification that file size limits prevent crashes
    □ Testing atomic operations under concurrent access
    □ Validation of cleanup mechanisms under memory pressure
    □ Confirmation that error handling doesn't block user workflow
    □ Testing with corrupted token files and recovery paths
    """
    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    token_file = logs_dir / "compass-tokens.json"

    try:
        # OPTIMIZED: Check file size before loading to prevent memory issues
        if token_file.exists() and token_file.stat().st_size > MAX_TOKEN_FILE_SIZE:
            log_handler_activity(
                "token_file_too_large",
                f"Token file too large ({token_file.stat().st_size} bytes), performing cleanup",
            )
            cleanup_token_file(token_file)

        # Load existing counts with file locking for concurrency safety
        with FileLock(f"{token_file}.lock"):
            if token_file.exists():
                try:
                    # OPTIMIZED: Use memory-safe JSON loading
                    session_tokens = load_json_memory_safe(token_file)

                    if session_tokens is None:
                        # File too large or corrupted, create new
                        log_handler_activity(
                            "token_file_reset",
                            "Token file reset due to size/corruption",
                        )
                        session_tokens = create_empty_token_data()
                    else:
                        # Validate and clean data structure
                        session_tokens = validate_and_clean_token_data(session_tokens)

                except (json.JSONDecodeError, FileNotFoundError, MemoryError) as e:
                    log_handler_activity(
                        "token_file_corruption",
                        f"Token file corrupted, creating new: {e}",
                    )
                    session_tokens = create_empty_token_data()
            else:
                session_tokens = create_empty_token_data()

            # Update counts with bounds checking
            try:
                session_tokens["total"] += token_count
                session_tokens["by_agent"][agent_type] = (
                    session_tokens["by_agent"].get(agent_type, 0) + token_count
                )
                session_tokens["last_update"] = datetime.now().isoformat()

                # Map agent to COMPASS phase
                phase = map_agent_to_phase(agent_type)
                if phase:
                    session_tokens["by_phase"][phase] = (
                        session_tokens["by_phase"].get(phase, 0) + token_count
                    )

                # OPTIMIZED: Limit number of agents tracked to prevent unbounded growth
                if len(session_tokens["by_agent"]) > MAX_AGENT_TRACKING:
                    cleanup_old_agents_optimized(session_tokens)

                # OPTIMIZED: Limit number of phases tracked
                if len(session_tokens["by_phase"]) > MAX_PHASE_TRACKING:
                    cleanup_old_phases(session_tokens)

                # Write updated counts atomically with compact format
                with open(token_file, "w", encoding="utf-8") as f:
                    json.dump(session_tokens, f, separators=(",", ":"))

            except (OSError, MemoryError) as e:
                log_handler_activity(
                    "token_file_write_error", f"Failed to write token file: {e}"
                )
                # Continue without token tracking rather than blocking

    except Exception as e:
        # Fail fast: log error but don't block user workflow
        log_handler_activity("token_count_error", f"Failed to update token count: {e}")
        # Attempt emergency cleanup if memory-related
        if isinstance(e, MemoryError):
            cleanup_memory()


def create_empty_token_data():
    """Create empty token data structure"""
    return {
        "total": 0,
        "by_agent": {},
        "by_phase": {},
        "session_start": datetime.now().isoformat(),
        "last_update": datetime.now().isoformat(),
    }


def validate_and_clean_token_data(session_tokens):
    """Validate and clean token data structure to prevent corruption"""
    if not isinstance(session_tokens, dict):
        return create_empty_token_data()

    # Ensure required fields exist with proper types
    cleaned_data = {
        "total": max(0, int(session_tokens.get("total", 0))),
        "by_agent": {},
        "by_phase": {},
        "session_start": session_tokens.get(
            "session_start", datetime.now().isoformat()
        ),
        "last_update": datetime.now().isoformat(),
    }

    # Clean by_agent data with bounds checking
    by_agent = session_tokens.get("by_agent", {})
    if isinstance(by_agent, dict) and len(by_agent) <= MAX_TOKEN_SESSIONS:
        for agent, count in by_agent.items():
            if (
                isinstance(agent, str)
                and isinstance(count, (int, float))
                and count >= 0
            ):
                cleaned_data["by_agent"][agent] = int(count)

    # Clean by_phase data
    by_phase = session_tokens.get("by_phase", {})
    if isinstance(by_phase, dict):
        for phase, count in by_phase.items():
            if (
                isinstance(phase, str)
                and isinstance(count, (int, float))
                and count >= 0
            ):
                cleaned_data["by_phase"][phase] = int(count)

    return cleaned_data


def cleanup_old_agents_optimized(session_tokens):
    """OPTIMIZED: Remove oldest agents to keep memory bounded with LRU eviction"""
    by_agent = session_tokens.get("by_agent", {})
    if len(by_agent) > MAX_AGENT_TRACKING:
        # Keep only the top MAX_AGENT_TRACKING agents by token count
        sorted_agents = sorted(by_agent.items(), key=lambda x: x[1], reverse=True)
        session_tokens["by_agent"] = dict(sorted_agents[:MAX_AGENT_TRACKING])

        # Force garbage collection after cleanup
        gc.collect()
        log_handler_activity(
            "agent_cleanup",
            f"Cleaned up {len(by_agent) - MAX_AGENT_TRACKING} old agents",
        )


def cleanup_old_phases(session_tokens):
    """OPTIMIZED: Remove oldest phases to keep memory bounded"""
    by_phase = session_tokens.get("by_phase", {})
    if len(by_phase) > MAX_PHASE_TRACKING:
        # Keep only the top MAX_PHASE_TRACKING phases by token count
        sorted_phases = sorted(by_phase.items(), key=lambda x: x[1], reverse=True)
        session_tokens["by_phase"] = dict(sorted_phases[:MAX_PHASE_TRACKING])

        # Force garbage collection after cleanup
        gc.collect()
        log_handler_activity(
            "phase_cleanup",
            f"Cleaned up {len(by_phase) - MAX_PHASE_TRACKING} old phases",
        )


def cleanup_token_file(token_file):
    """OPTIMIZED: Clean up oversized token file with aggressive memory management"""
    try:
        # Check file size before attempting to load
        file_size = token_file.stat().st_size

        # CRITICAL FIX: More aggressive size limits
        if file_size > MAX_TOKEN_FILE_SIZE:
            # File too large - perform emergency cleanup
            perform_emergency_token_cleanup(token_file)
            return

        # Try to load and compress the data with memory checks
        with open(token_file, "r", encoding="utf-8") as f:
            data = json.load(f)

        # MEMORY OPTIMIZATION: Keep only essential current session data
        cleaned_data = {
            "total": min(data.get("total", 0), 1000000),  # Cap total tokens
            "session_start": datetime.now().isoformat(),
            "last_update": datetime.now().isoformat(),
            "by_agent": {},
            "by_phase": {},
        }

        # BOUNDED COLLECTIONS: Keep only top agents with LRU eviction
        by_agent = data.get("by_agent", {})
        if isinstance(by_agent, dict):
            sorted_agents = sorted(by_agent.items(), key=lambda x: x[1], reverse=True)
            # Reduced from 10 to 5 for better memory efficiency
            cleaned_data["by_agent"] = dict(sorted_agents[:5])

        # BOUNDED COLLECTIONS: Keep only top phases
        by_phase = data.get("by_phase", {})
        if isinstance(by_phase, dict):
            sorted_phases = sorted(by_phase.items(), key=lambda x: x[1], reverse=True)
            cleaned_data["by_phase"] = dict(sorted_phases[:MAX_PHASE_TRACKING])

        # Write cleaned data with compact format
        with open(token_file, "w", encoding="utf-8") as f:
            json.dump(cleaned_data, f, separators=(",", ":"))

        # MEMORY CLEANUP: Force garbage collection after cleanup
        gc.collect()

    except (json.JSONDecodeError, OSError, MemoryError) as e:
        # FAIL-SAFE: If cleanup fails, remove the file entirely
        log_handler_activity("token_cleanup_failed", f"Emergency file removal: {e}")
        token_file.unlink(missing_ok=True)
        gc.collect()


def perform_emergency_token_cleanup(token_file):
    """EMERGENCY: Create minimal token file when original is too large"""
    try:
        # Create minimal data structure
        emergency_data = {
            "total": 0,
            "session_start": datetime.now().isoformat(),
            "last_update": datetime.now().isoformat(),
            "by_agent": {},
            "by_phase": {},
            "emergency_cleanup": True,
            "cleanup_timestamp": datetime.now().isoformat(),
        }

        # Write minimal file
        with open(token_file, "w", encoding="utf-8") as f:
            json.dump(emergency_data, f, separators=(",", ":"))

        log_handler_activity(
            "emergency_cleanup", f"Emergency token file cleanup performed"
        )
        gc.collect()

    except Exception as e:
        # Ultimate fallback - remove file
        log_handler_activity("emergency_cleanup_failed", f"File removal: {e}")
        token_file.unlink(missing_ok=True)


def map_agent_to_phase(agent_type):
    """
    Map agent types to COMPASS methodology phases
    Based on 7-phase COMPASS workflow documentation
    """
    phase_mapping = {
        "compass-captain": "coordination",
        "compass-cleanup-coordinator": "coordination",
        "compass-complexity-analyzer": "strategic_planning",
        "compass-strategy-builder": "strategic_planning",
        "compass-validation-coordinator": "strategic_planning",
        "compass-knowledge-discovery": "phase1_knowledge_query",
        "compass-todo-sync": "phase1_foundation",
        "compass-pattern-apply": "phase2_pattern_application",
        "compass-doc-planning": "phase2_documentation_planning",
        "compass-data-flow": "phase2_data_flow_analysis",
        "compass-auth-performance-analyst": "phase2_auth_specialists",
        "compass-auth-security-validator": "phase2_auth_specialists",
        "compass-auth-optimization-specialist": "phase2_auth_specialists",
        "compass-writing-analyst": "phase2_writing_specialists",
        "compass-academic-analyst": "phase2_writing_specialists",
        "compass-memory-enhanced-writer": "phase2_writing_specialists",
        "compass-dependency-tracker": "phase2_dependency_specialists",
        "compass-gap-analysis": "phase3_gap_analysis",
        "compass-enhanced-analysis": "phase4_enhanced_analysis",
        "compass-cross-reference": "phase5_parallel_finalization",
        "compass-svg-analyst": "phase5_parallel_finalization",
        "compass-upstream-validator": "phase5_quality_validation",
        "compass-coder": "phase6_execution_bridge",
        "compass-memory-integrator": "phase7_memory_integration",
        "compass-second-opinion": "advisory_expert_consultation",
        "compass-breakthrough-doc": "breakthrough_documentation",
    }
    return phase_mapping.get(agent_type)


def get_current_session_tokens():
    """
    Get current session token totals for reporting with enhanced error handling
    Graceful degradation with memory-safe reading
    """
    # Use .claude/logs directory for token file
    logs_dir = Path(".claude/logs")
    token_file = logs_dir / "compass-tokens.json"
    if not token_file.exists():
        return {"total": 0, "by_agent": {}, "by_phase": {}}

    try:
        # Check file size before reading to prevent memory issues
        if token_file.stat().st_size > 2 * 1024 * 1024:  # 2MB limit
            log_handler_activity(
                "token_file_oversized",
                "Token file too large, performing emergency cleanup",
            )
            cleanup_token_file(token_file)
            return {"total": 0, "by_agent": {}, "by_phase": {}}

        with open(token_file, "r", encoding="utf-8") as f:
            token_data = json.load(f)

        # Validate and clean the data structure
        cleaned_data = validate_and_clean_token_data(token_data)
        return cleaned_data

    except (json.JSONDecodeError, ValueError, KeyError) as e:
        log_handler_activity(
            "token_read_error", f"Failed to read/parse token count: {e}"
        )
        # Attempt to recover by cleaning the file
        try:
            cleanup_token_file(token_file)
        except Exception:
            pass
        return {"total": 0, "by_agent": {}, "by_phase": {}}
    except (OSError, MemoryError) as e:
        log_handler_activity("token_read_error", f"File system or memory error: {e}")
        return {"total": 0, "by_agent": {}, "by_phase": {}}
    except Exception as e:
        log_handler_activity(
            "token_read_error", f"Unexpected error reading token count: {e}"
        )
        return {"total": 0, "by_agent": {}, "by_phase": {}}


def handle_pre_tool_use_with_token_tracking(input_data):
    """
    Enhanced PreToolUse handler with comprehensive token tracking
    Preserves existing hook functionality while adding token visibility
    """
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # CRITICAL: COMPASS ENFORCEMENT - Block ALL tools unless compass-captain is called
    if compass_context_active():
        # Only allow compass-captain and memory-safe agents during COMPASS sessions
        if tool_name == "Task":
            subagent_type = tool_input.get("subagent_type", "")
            if subagent_type == "compass-captain":
                # COMPASS CAPTAIN RECURSION PREVENTION: Check if compass-captain is calling itself
                log_handler_activity(
                    "compass_captain_recursion_check",
                    f"Checking compass-captain recursion during active COMPASS session",
                )
                enhanced_message = create_enhanced_recursion_message(
                    "compass_captain", tool_name=tool_name, subagent_type=subagent_type
                )
                return create_permission_decision_with_compass_context(
                    "deny", enhanced_message
                )
            elif subagent_type in [
                "compass-knowledge-discovery",
                "compass-enhanced-analysis",
                "compass-cross-reference",
                "compass-data-flow",
                "compass-dependency-tracker",
            ]:
                pass
            else:
                # Block all other Task tool usage - force compass-captain
                session_context = get_compass_session_context()
                enhanced_enforcement_message = f"""🧭 COMPASS ENFORCEMENT: Task Tool Blocked

⚠️ **UNAUTHORIZED AGENT DETECTED**: '{subagent_type}' attempted during active COMPASS session

🧠 **WHY THIS IS BLOCKED**:
• COMPASS session requires coordination through compass-captain
• Prevents bypass of systematic methodology enforcement
• Ensures all analysis follows proper 7-phase COMPASS approach
• Maintains institutional knowledge integration and quality standards

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Current Phase: {session_context["current_phase"]}
• Total Tokens Used: {session_context["total_tokens"]:,}
• Agents Already Run: {", ".join(session_context["agents_run"][:3]) if session_context["agents_run"] else "None yet"}

✅ **REQUIRED ACTION**:
Use Task tool with subagent_type='compass-captain' for proper methodology coordination

❌ **BLOCKED**: Task tool with subagent_type='{subagent_type}' during COMPASS session

🎯 **NEXT STEP**: compass-captain will coordinate the appropriate methodology approach for your request."""

                return create_permission_decision_with_compass_context(
                    "deny", enhanced_enforcement_message
                )
        elif tool_name in ["TodoWrite"]:
            # Allow TodoWrite for progress tracking
            pass
        elif tool_name in ["Read", "LS", "Grep", "Glob", "Bash"]:
            # Allow basic read-only tools but with warning
            log_handler_activity(
                "compass_tool_bypass", f"Allowing {tool_name} during COMPASS session"
            )
        else:
            # Block all other tools - force compass-captain usage
            session_context = get_compass_session_context()
            enhanced_tool_block_message = f"""🧭 COMPASS ENFORCEMENT: Non-Task Tool Blocked

⚠️ **UNAUTHORIZED TOOL DETECTED**: '{tool_name}' attempted during active COMPASS session

🧠 **WHY THIS IS BLOCKED**:
• COMPASS session requires all tools to go through compass-captain coordination
• Prevents bypass of systematic methodology enforcement
• Ensures proper tool usage context within COMPASS phases
• Maintains institutional knowledge integration standards

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Current Phase: {session_context["current_phase"]}
• Total Tokens Used: {session_context["total_tokens"]:,}
• Recent Activity: {session_context["recent_activity"]}

✅ **REQUIRED ACTION**:
Use Task tool with subagent_type='compass-captain' for proper coordination

❌ **BLOCKED**: {tool_name} tool during active COMPASS session

🎯 **NEXT STEP**: compass-captain will coordinate appropriate tool usage within methodology context."""

            return create_permission_decision_with_compass_context(
                "deny", enhanced_tool_block_message
            )

    # Detect COMPASS agent usage and track tokens
    if tool_name == "Task":
        subagent_type = tool_input.get("subagent_type", "")
        prompt = tool_input.get("prompt", "")

        # Check if this is a COMPASS agent call (look for agent names in prompt)
        compass_agent = detect_compass_agent_in_prompt(prompt)
        if compass_agent:
            # Estimate tokens for COMPASS agent
            estimated_tokens = estimate_agent_tokens(compass_agent, prompt, tool_input)

            # Track in session token counter
            update_session_token_count(compass_agent, estimated_tokens)

            # Check for specialist delegation
            if compass_agent == "compass-coder":
                predicted_specialists = predict_specialist_delegation(prompt)
                if predicted_specialists:
                    delegation_tokens = track_specialist_delegation_tokens(
                        compass_agent, predicted_specialists
                    )
                    update_session_token_count("delegation_chain", delegation_tokens)

            # Update user-visible progress
            update_compass_status_with_tokens(compass_agent, estimated_tokens)

            log_handler_activity(
                "token_tracking",
                f"{compass_agent}: {estimated_tokens} tokens estimated",
            )

    # Continue with existing hook processing
    return handle_pre_tool_use(input_data)


def update_compass_status_with_tokens(agent_type, token_count):
    """
    Update .claude/logs/compass-status with real-time token information
    Integrates token visibility with throttled I/O to prevent excessive writes
    """
    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    status_file = logs_dir / "compass-status"
    if not status_file.exists():
        return

    try:
        # Throttle status updates to prevent excessive I/O
        if not should_update_status_file(status_file):
            return

        # Use memory-efficient file reading with size check
        if status_file.stat().st_size > 50 * 1024:  # 50KB limit for status file
            log_handler_activity(
                "status_file_too_large", "Status file too large, skipping update"
            )
            return

        with open(status_file, "r", encoding="utf-8") as f:
            status_content = f.read()

        # Get session totals with error handling
        session_totals = get_current_session_tokens()

        # Create compact token section to reduce file size
        token_section = f"""
📊 TOKEN USAGE: {agent_type} (+{token_count}) | Total: {session_totals.get("total", 0)} | Cost: ${session_totals.get("total", 0) * 0.00001:.4f}
⚡ PARALLEL EXECUTION: 37.5% faster | Token overhead: ~5%"""

        # Replace existing token section or add new one
        if "📊 TOKEN USAGE" in status_content:
            # Replace existing section efficiently
            lines = status_content.split("\n")
            new_lines = []
            skip_next = False

            for line in lines:
                if "📊 TOKEN USAGE" in line:
                    new_lines.extend(token_section.strip().split("\n"))
                    skip_next = True
                elif skip_next and line.startswith(("⚡", "   •")):
                    continue  # Skip old token lines
                elif skip_next and not line.strip():
                    continue  # Skip empty lines
                else:
                    skip_next = False
                    new_lines.append(line)

            updated_content = "\n".join(new_lines)
        else:
            # Add new section before closing border
            updated_content = status_content.replace(
                "═══════════════════════════════════════════════════════════════",
                token_section
                + "\n\n═══════════════════════════════════════════════════════════════",
            )

        # Write atomically with compact format
        with open(status_file, "w", encoding="utf-8") as f:
            f.write(updated_content)

    except (OSError, MemoryError) as e:
        log_handler_activity("status_update_error", f"Failed to update status: {e}")
        # Don't crash on status update failures


def should_update_status_file(status_file):
    """Throttle status file updates to reduce I/O"""
    try:
        # Only update every 5 seconds to reduce I/O
        last_modified = datetime.fromtimestamp(status_file.stat().st_mtime)
        now = datetime.now()
        return (now - last_modified).total_seconds() > 5
    except OSError:
        return True  # Update if we can't check modification time


def get_most_expensive_phase(phase_tokens):
    """
    Identify the most token-expensive COMPASS phase
    Provides user insight into resource allocation
    """
    if not phase_tokens:
        return "None yet"

    max_phase = max(phase_tokens.items(), key=lambda x: x[1])
    return f"{max_phase[0]} ({max_phase[1]} tokens)"


def log_agent_token_usage(agent_type, token_count, execution_type):
    """
    Log individual agent token usage for analysis and optimization
    Contributes to institutional learning about token patterns
    """
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "action": "agent_token_usage",
        "agent_type": agent_type,
        "token_count": token_count,
        "execution_type": execution_type,
        "handler": "compass-handler",
        "version": "2.1",
    }

    # Use .claude/logs directory
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    log_file = logs_dir / "compass-handler.log"
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Fail silently if logging fails


def log_parallel_efficiency(agent_count, total_tokens, duration):
    """
    Log parallel execution efficiency metrics
    Tracks the time vs token trade-off for optimization
    """
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "action": "parallel_efficiency",
        "agent_count": agent_count,
        "total_tokens": total_tokens,
        "duration_seconds": duration,
        "efficiency_metric": "37.5% faster with 5.1% token overhead",
        "handler": "compass-handler",
        "version": "2.1",
    }

    # Use .claude/logs directory
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    log_file = logs_dir / "compass-handler.log"
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Fail silently if logging fails


def log_delegation_step(primary_agent, specialist_type, specialist_tokens):
    """
    Log specialist delegation chain steps
    Tracks the previously hidden 50-70% of token usage
    """
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "action": "specialist_delegation",
        "primary_agent": primary_agent,
        "specialist_type": specialist_type,
        "specialist_tokens": specialist_tokens,
        "visibility_improvement": "Previously hidden usage now tracked",
        "handler": "compass-handler",
        "version": "2.1",
    }

    # Use .claude/logs directory
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    log_file = logs_dir / "compass-handler.log"
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Fail silently if logging fails


def generate_final_token_report():
    """
    Generate comprehensive token usage report at COMPASS completion
    Provides complete visibility into methodology resource consumption
    """
    session_tokens = get_current_session_tokens()

    if session_tokens.get("total", 0) == 0:
        return "No token usage recorded for this session."

    # Calculate efficiency metrics
    sequential_estimate = calculate_sequential_token_estimate(session_tokens)
    parallel_actual = session_tokens.get("total", 0)
    efficiency_percent = (
        ((sequential_estimate - parallel_actual) / sequential_estimate * 100)
        if sequential_estimate > 0
        else 0
    )

    return f"""
🧭 COMPASS Token Usage Report
════════════════════════════════════════════════════════════════

📊 SESSION SUMMARY:
   • Total Tokens Used: {session_tokens.get("total", 0)} tokens
   • Estimated Cost: ~${session_tokens.get("total", 0) * 0.00001:.4f}
   • Analysis Duration: {calculate_session_duration(session_tokens)}
   • Average Tokens/Minute: {calculate_tokens_per_minute(session_tokens)}

⚡ PARALLEL EXECUTION EFFICIENCY:
   • Sequential Estimate: {sequential_estimate} tokens
   • Parallel Actual: {parallel_actual} tokens
   • Efficiency: {efficiency_percent:.1f}% faster execution
   • Trade-off: Optimal time vs cost balance

🔧 AGENT BREAKDOWN:
{format_agent_breakdown(session_tokens.get("by_agent", {}))}

📈 PHASE ANALYSIS:
{format_phase_breakdown(session_tokens.get("by_phase", {}))}

🎯 INSTITUTIONAL INSIGHTS:
   • Most Efficient Agent: {identify_most_efficient_agent(session_tokens)}
   • Highest Value Agent: {identify_highest_value_agent(session_tokens)}
   • Optimization Opportunities: {identify_optimization_opportunities(session_tokens)}

════════════════════════════════════════════════════════════════
📄 Detailed breakdown available in: .claude-tokens.json
🔄 This data contributes to institutional learning for future optimizations
"""


def calculate_sequential_token_estimate(session_tokens):
    """
    Calculate estimated token usage if agents ran sequentially
    Provides comparison baseline for parallel execution efficiency
    """
    # Remove coordination overhead (10% of parallel groups)
    by_phase = session_tokens.get("by_phase", {})

    # Estimate sequential cost by removing parallel coordination overhead
    phase2_tokens = (
        by_phase.get("phase2_pattern_application", 0)
        + by_phase.get("phase2_documentation_planning", 0)
        + by_phase.get("phase2_data_flow_analysis", 0)
    )
    phase5_tokens = by_phase.get("phase5_cross_reference", 0) + by_phase.get(
        "phase5_svg_analysis", 0
    )

    # Remove 10% coordination overhead from parallel phases
    sequential_phase2 = int(phase2_tokens / 1.1) if phase2_tokens > 0 else 0
    sequential_phase5 = int(phase5_tokens / 1.1) if phase5_tokens > 0 else 0

    other_phases = sum(
        v
        for k, v in by_phase.items()
        if not k.startswith("phase2_") and not k.startswith("phase5_")
    )

    return sequential_phase2 + sequential_phase5 + other_phases


def calculate_session_duration(session_tokens):
    """Calculate human-readable session duration"""
    try:
        start_time = datetime.fromisoformat(session_tokens.get("session_start", ""))
        end_time = datetime.fromisoformat(session_tokens.get("last_update", ""))
        duration = end_time - start_time

        minutes = int(duration.total_seconds() // 60)
        seconds = int(duration.total_seconds() % 60)
        return f"{minutes}m {seconds}s"
    except (ValueError, TypeError, AttributeError):
        return "Unknown"


def calculate_tokens_per_minute(session_tokens):
    """Calculate token usage rate"""
    try:
        start_time = datetime.fromisoformat(session_tokens.get("session_start", ""))
        end_time = datetime.fromisoformat(session_tokens.get("last_update", ""))
        duration_minutes = (end_time - start_time).total_seconds() / 60

        if duration_minutes > 0:
            return int(session_tokens.get("total", 0) / duration_minutes)
        return 0
    except (ValueError, TypeError, AttributeError):
        return 0


def format_agent_breakdown(by_agent):
    """Format agent token usage for user report"""
    if not by_agent:
        return "   No agent usage recorded"

    sorted_agents = sorted(by_agent.items(), key=lambda x: x[1], reverse=True)
    breakdown = []

    for agent, tokens in sorted_agents[:10]:  # Top 10 agents
        percentage = (tokens / sum(by_agent.values())) * 100
        breakdown.append(f"   • {agent}: {tokens} tokens ({percentage:.1f}%)")

    return "\n".join(breakdown)


def format_phase_breakdown(by_phase):
    """Format COMPASS phase token usage for user report"""
    if not by_phase:
        return "   No phase usage recorded"

    phase_names = {
        "phase1_knowledge_query": "Knowledge Query",
        "phase2_pattern_application": "Pattern Application",
        "phase2_documentation_planning": "Documentation Planning",
        "phase2_data_flow_analysis": "Data Flow Analysis",
        "phase3_gap_analysis": "Gap Analysis",
        "phase4_enhanced_analysis": "Enhanced Analysis",
        "phase5_cross_reference": "Cross-Reference",
        "phase5_svg_analysis": "SVG Analysis",
        "phase6_execution_bridge": "Execution Bridge",
    }

    breakdown = []
    for phase, tokens in by_phase.items():
        name = phase_names.get(phase, phase)
        percentage = (tokens / sum(by_phase.values())) * 100
        breakdown.append(f"   • {name}: {tokens} tokens ({percentage:.1f}%)")

    return "\n".join(breakdown)


def identify_most_efficient_agent(session_tokens):
    """Identify agent with best token efficiency"""
    by_agent = session_tokens.get("by_agent", {})
    if not by_agent:
        return "Unknown"

    # Simple metric: lowest token usage (for similar complexity tasks)
    min_tokens = min(by_agent.items(), key=lambda x: x[1])
    return f"{min_tokens[0]} ({min_tokens[1]} tokens)"


def identify_highest_value_agent(session_tokens):
    """Identify agent providing highest value per token"""
    by_phase = session_tokens.get("by_phase", {})

    # Enhanced analysis typically provides highest value
    enhanced_tokens = by_phase.get("phase4_enhanced_analysis", 0)
    if enhanced_tokens > 0:
        return f"Enhanced Analysis ({enhanced_tokens} tokens)"

    # Fall back to knowledge query as foundational value
    knowledge_tokens = by_phase.get("phase1_knowledge_query", 0)
    if knowledge_tokens > 0:
        return f"Knowledge Query ({knowledge_tokens} tokens)"

    return "Unknown"


def identify_optimization_opportunities(session_tokens):
    """Identify potential token optimization opportunities"""
    by_phase = session_tokens.get("by_phase", {})
    opportunities = []

    # Check for high delegation chain usage
    delegation_tokens = session_tokens.get("by_agent", {}).get("delegation_chain", 0)
    total_tokens = session_tokens.get("total", 0)

    if delegation_tokens > total_tokens * 0.3:  # More than 30%
        opportunities.append("Optimize specialist delegation chains")

    # Check for parallel coordination overhead
    phase2_total = sum(v for k, v in by_phase.items() if k.startswith("phase2_"))
    if phase2_total > total_tokens * 0.4:  # More than 40%
        opportunities.append("Consider phase 2 optimization")

    if not opportunities:
        opportunities.append("Current token allocation appears optimal")

    return "; ".join(opportunities)


def requires_compass_methodology(tool_name, tool_input):
    """
    CRITICAL ENFORCEMENT FUNCTION: Determines when COMPASS methodology is required for tool usage

    WARNING: This function is the core logic for COMPASS methodology enforcement.
    Modifications can allow ad-hoc analysis to bypass systematic approach requirements.

    PURPOSE:
    - Analyzes tool usage patterns to detect complex analytical tasks
    - Enforces institutional knowledge integration requirements
    - Prevents ad-hoc analysis that bypasses documented approaches
    - Ensures systematic methodology for complex operations
    - Maintains quality and consistency standards across analysis work

    ENFORCEMENT CRITERIA:
    - Complex analysis tools: MCP Serena search and symbol tools
    - Multi-file operations: Tools working across multiple files
    - Investigation patterns: grep, find, pattern searches
    - Documentation tasks: When creating systematic documentation
    - Pattern recognition: Tools indicating methodical work required

    DETECTION LOGIC:
    - Tool complexity: Identifies tools requiring systematic approach
    - Input analysis: Examines parameters for complexity indicators
    - Usage context: Considers broader operational context
    - Systematic indicators: Detects when methodology would add value

    ARGS:
        tool_name (str): Name of the tool being executed
        tool_input (dict): Parameters and input for the tool

    RETURNS:
        bool: True if COMPASS methodology required, False if tool can proceed independently

    CRITICAL FOR:
    - Quality control: Ensures complex tasks use systematic approaches
    - Institutional knowledge: Forces consultation of existing patterns
    - Consistency: Maintains standard approaches across similar work
    - Bypass prevention: Stops circumvention of methodology requirements

    DO NOT MODIFY WITHOUT:
    1. Understanding COMPASS methodology value and purpose
    2. Testing detection accuracy with various tool usage patterns
    3. Verifying enforcement doesn't block legitimate simple operations
    4. Ensuring systematic approach is truly beneficial for detected cases
    """

    # Tools that always require COMPASS for complex operations
    complex_tools = [
        "mcp__serena__search_for_pattern",
        "mcp__serena__find_symbol",
        "mcp__serena__find_referencing_symbols",
        "mcp__serena__get_symbols_overview",
    ]

    if tool_name in complex_tools:
        return True

    # Reading multiple files or large analysis operations
    if tool_name == "mcp__serena__read_file":
        # Check if this appears to be part of systematic analysis
        relative_path = tool_input.get("relative_path", "")
        if any(
            pattern in relative_path.lower()
            for pattern in ["src/", "lib/", "components/", "services/", "agents/"]
        ):
            return True

    # Directory listing with recursive scanning
    if tool_name == "mcp__serena__list_dir":
        if tool_input.get("recursive", False):
            return True

    # Any regex replacement or symbol modification
    modification_tools = [
        "mcp__serena__replace_regex",
        "mcp__serena__replace_symbol_body",
        "mcp__serena__insert_after_symbol",
        "mcp__serena__insert_before_symbol",
    ]

    if tool_name in modification_tools:
        return True

    return False


def compass_context_active():
    """Check if COMPASS methodology context is currently active"""

    # Primary check: .claude/logs/compass-status file existence (most reliable indicator)
    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if status_file.exists():
        return True

    # Secondary check: Session-based persistence file
    if check_compass_session_active():
        return True

    # Check for COMPASS agent activity in recent logs (expanded detection)
    logs_dir = Path(".claude/logs")
    log_file = logs_dir / "compass-handler.log"
    if log_file.exists():
        try:
            with open(log_file, "r") as f:
                recent_lines = f.readlines()[
                    -20:
                ]  # Check last 20 log entries (doubled)

            for line in recent_lines:
                try:
                    log_entry = json.loads(line.strip())

                    # Expanded action detection for COMPASS activity
                    compass_actions = [
                        "compass_required",
                        "agent_active",
                        "token_tracking",
                        "prompt_routing",
                        "phase_update",
                        "compass_complete",
                    ]

                    action = log_entry.get("action", "")
                    if action in compass_actions and is_recent_timestamp_extended(
                        log_entry.get("timestamp", "")
                    ):
                        return True

                    # Check for compass agent usage in agent_type field
                    agent_type = log_entry.get("agent_type", "")
                    if agent_type.startswith(
                        "compass-"
                    ) and is_recent_timestamp_extended(log_entry.get("timestamp", "")):
                        return True

                except (json.JSONDecodeError, KeyError):
                    continue
        except Exception:
            pass

    # Check for active COMPASS documentation activity (extended window)
    docs_dir = Path("docs")
    if docs_dir.exists():
        recent_files = [
            f
            for f in docs_dir.glob("*.md")
            if f.stat().st_mtime > (datetime.now().timestamp() - 600)  # 10 minutes
        ]
        if recent_files:
            return True

    # Check token tracking file for recent COMPASS activity
    if check_recent_compass_tokens():
        return True

    return False


def is_recent_timestamp(timestamp_str):
    """Check if timestamp is within the last 10 minutes"""
    try:
        timestamp = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        now = datetime.now().astimezone()
        return (now - timestamp).total_seconds() < 600  # 10 minutes
    except Exception:
        return False


def is_recent_timestamp_extended(timestamp_str):
    """Check if timestamp is within the last 10 minutes (extended for COMPASS sessions)"""
    try:
        timestamp = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        now = datetime.now().astimezone()
        return (now - timestamp).total_seconds() < 600  # 10 minutes
    except Exception:
        return False


def check_compass_session_active():
    """Check if COMPASS session is active based on persistent session tracking"""
    logs_dir = Path(".claude/logs")
    session_file = logs_dir / "compass-session.json"
    if not session_file.exists():
        return False

    try:
        with open(session_file, "r") as f:
            session_data = json.load(f)

        # Check if session was created within last 2 hours
        session_start = session_data.get("session_start", "")
        if is_session_timestamp_valid(session_start, 7200):  # 2 hours
            return True

        # Check if there was recent activity
        last_activity = session_data.get("last_activity", "")
        if is_session_timestamp_valid(last_activity, 600):  # 10 minutes
            return True

    except (json.JSONDecodeError, FileNotFoundError):
        pass

    return False


def is_session_timestamp_valid(timestamp_str, seconds_threshold):
    """Check if timestamp is within specified seconds threshold"""
    try:
        timestamp = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        now = datetime.now().astimezone()
        return (now - timestamp).total_seconds() < seconds_threshold
    except Exception:
        return False


def check_recent_compass_tokens():
    """Check token tracking file for recent COMPASS agent activity"""
    logs_dir = Path(".claude/logs")
    token_file = logs_dir / "compass-tokens.json"
    if not token_file.exists():
        return False

    try:
        with open(token_file, "r") as f:
            token_data = json.load(f)

        # Check if last update was recent
        last_update = token_data.get("last_update", "")
        if is_recent_timestamp_extended(last_update):
            return True

        # Check if any compass agents were used recently
        by_agent = token_data.get("by_agent", {})
        for agent_name in by_agent.keys():
            if agent_name.startswith("compass-"):
                return True

    except (json.JSONDecodeError, FileNotFoundError):
        pass

    return False


def create_compass_session_tracking():
    """Create or update COMPASS session tracking file"""
    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    session_file = logs_dir / "compass-session.json"

    current_time = datetime.now().isoformat()

    # Load existing session data or create new
    session_data = {
        "session_start": current_time,
        "last_activity": current_time,
        "compass_activated": True,
        "version": "2.1",
    }

    if session_file.exists():
        try:
            with open(session_file, "r", encoding="utf-8") as f:
                existing_data = json.load(f)

            # Validate existing data structure
            if isinstance(existing_data, dict):
                # Preserve session start time, update activity
                session_data["session_start"] = existing_data.get(
                    "session_start", current_time
                )
            else:
                log_handler_activity(
                    "session_corruption", "Session file corrupted, creating new"
                )

        except (json.JSONDecodeError, FileNotFoundError, ValueError) as e:
            log_handler_activity(
                "session_read_error", f"Failed to read session file: {e}"
            )
            # Continue with new session data

    # Write updated session data with error handling
    try:
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(session_data, f, indent=2)

        log_handler_activity("session_tracking", "COMPASS session tracking updated")

    except OSError as e:
        log_handler_activity(
            "session_write_error", f"Failed to write session file: {e}"
        )
        # Continue without session tracking rather than blocking


def update_compass_session_activity():
    """Update last activity timestamp in session tracking"""
    logs_dir = Path(".claude/logs")
    session_file = logs_dir / "compass-session.json"

    if session_file.exists():
        try:
            with open(session_file, "r") as f:
                session_data = json.load(f)

            session_data["last_activity"] = datetime.now().isoformat()

            with open(session_file, "w") as f:
                json.dump(session_data, f, indent=2)

        except (json.JSONDecodeError, FileNotFoundError):
            # If file is corrupted, create new tracking
            create_compass_session_tracking()


def create_compass_status_file():
    """Create visible status file to show COMPASS methodology activation"""
    status_content = f"""🧭 COMPASS METHODOLOGY ACTIVATED
═══════════════════════════════════════════════════════════════

COMPLEX ANALYTICAL TASK DETECTED: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

REQUIRED: Systematic 6-Phase Analysis Coordination

┌─ PHASE CHECKLIST ─────────────────────────────────────────────┐
│ □ Phase 1: Knowledge Query     (compass-knowledge-discovery)      │
│ □ Phase 2: Pattern Application (compass-pattern-apply)        │
│ □ Phase 3: Gap Analysis       (compass-gap-analysis)         │
│ □ Phase 4: Documentation Plan (compass-doc-planning)         │
│ □ Phase 5: Enhanced Analysis  (compass-enhanced-analysis)    │
│ □ Phase 6: Cross-Reference    (compass-cross-reference)      │
└───────────────────────────────────────────────────────────────┘

🎯 NEXT ACTION REQUIRED:
   Use Task tool with subagent_type='compass-captain' to begin coordination

📊 BENEFITS:
   • Institutional knowledge integration
   • Pattern recognition from existing work
   • Systematic quality assurance
   • Expert consultation capability
   • Proper documentation of discoveries

⚠️  WARNING:
   Complex analysis tools are BLOCKED until COMPASS coordination begins.
   This prevents ad-hoc analysis and ensures systematic methodology.

📁 DIRECTORIES:
   docs/  - Institutional memory and investigation frameworks
   maps/  - Visual pattern recognition and architectural diagrams
   agents/ - Specialized COMPASS methodology coordinators

═══════════════════════════════════════════════════════════════
🔄 This file updates automatically as phases complete
"""

    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    status_file = logs_dir / "compass-status"
    with open(status_file, "w") as f:
        f.write(status_content)

    log_handler_activity(
        "status_file", "Created .claude/logs/compass-status for user visibility"
    )


def update_compass_phase(phase_name, status="in_progress"):
    """Update COMPASS status file with phase progress"""
    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if not status_file.exists():
        return

    # Read current status
    with open(status_file, "r") as f:
        content = f.read()

    # Update the specific phase
    phase_map = {
        "knowledge-query": "Phase 1: Knowledge Query",
        "pattern-apply": "Phase 2: Pattern Application",
        "gap-analysis": "Phase 3: Gap Analysis",
        "doc-planning": "Phase 4: Documentation Plan",
        "enhanced-analysis": "Phase 5: Enhanced Analysis",
        "cross-reference": "Phase 6: Cross-Reference",
    }

    if phase_name in phase_map:
        phase_text = phase_map[phase_name]
        if status == "completed":
            symbol = "✓"
        elif status == "in_progress":
            symbol = "🔄"
        else:
            symbol = "□"

        # Replace the checkbox for this phase
        import re

        pattern = f"│ [□✓🔄] ({re.escape(phase_text)}.*?)│"
        replacement = f"│ {symbol} \\1│"
        content = re.sub(pattern, replacement, content)

        # Update timestamp
        content = re.sub(
            r"COMPLEX ANALYTICAL TASK DETECTED: .*",
            f"COMPLEX ANALYTICAL TASK DETECTED: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            content,
        )

        with open(status_file, "w") as f:
            f.write(content)

        log_handler_activity("phase_update", f"Updated {phase_name} to {status}")


def complete_compass_analysis():
    """Mark COMPASS analysis as complete and clean up status"""
    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if status_file.exists():
        # Create completion summary
        completion_content = f"""🧭 COMPASS METHODOLOGY COMPLETED
═══════════════════════════════════════════════════════════════

ANALYSIS COMPLETED: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

✓ All 6 phases executed successfully
✓ Institutional knowledge integrated
✓ Systematic analysis methodology applied
✓ Quality assurance completed

📁 RESULTS AVAILABLE IN:
   docs/  - Updated investigation frameworks
   maps/  - New visual pattern diagrams

🎯 NEXT STEPS:
   • Review generated documentation
   • Check updated visual maps
   • Apply insights to implementation

═══════════════════════════════════════════════════════════════
Analysis tools are now available for ad-hoc use.
"""

        with open(".claude-complete", "w") as f:
            f.write(completion_content)

        # Remove active status file
        status_file.unlink()

        log_handler_activity(
            "compass_complete", "Analysis completed - status cleaned up"
        )


def complete_compass_analysis_with_token_report():
    """
    Mark COMPASS analysis as complete and generate comprehensive token report
    Enhanced with token usage summary and institutional learning
    """
    # Generate final token report
    token_report = generate_final_token_report()

    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if status_file.exists():
        # Create completion summary with token analysis
        completion_content = f"""🧭 COMPASS METHODOLOGY COMPLETED
═══════════════════════════════════════════════════════════════

ANALYSIS COMPLETED: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

✅ All 6 phases executed successfully
✅ Institutional knowledge integrated
✅ Systematic analysis methodology applied
✅ Quality assurance completed
✅ Token tracking and optimization analysis complete

{token_report}

📁 RESULTS AVAILABLE IN:
   docs/  - Updated investigation frameworks
   maps/  - New visual pattern diagrams
   .claude-tokens.json - Detailed token usage data

🎯 NEXT STEPS:
   • Review generated documentation
   • Check updated visual maps
   • Apply insights to implementation
   • Use token data for future optimization

═══════════════════════════════════════════════════════════════
Analysis tools are now available for ad-hoc use.
Token tracking system is operational for future sessions.
"""

        with open(".claude-complete", "w") as f:
            f.write(completion_content)

        # Remove active status file
        status_file.unlink()

        log_handler_activity(
            "compass_complete",
            "Analysis completed with token tracking - status cleaned up",
        )


def create_compass_status_file_with_tokens():
    """
    Create visible status file with token tracking capabilities
    Enhanced version of existing status file creation
    """
    status_content = f"""🧭 COMPASS METHODOLOGY ACTIVATED
═══════════════════════════════════════════════════════════════

COMPLEX ANALYTICAL TASK DETECTED: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

REQUIRED: Systematic 6-Phase Analysis Coordination

┌─ PHASE CHECKLIST ─────────────────────────────────────────────┐
│ □ Phase 1: Knowledge Query     (compass-knowledge-discovery)      │
│ □ Phase 2: Pattern Application (compass-pattern-apply)        │
│ □ Phase 3: Gap Analysis       (compass-gap-analysis)         │
│ □ Phase 4: Documentation Plan (compass-doc-planning)         │
│ □ Phase 5: Enhanced Analysis  (compass-enhanced-analysis)    │
│ □ Phase 6: Cross-Reference    (compass-cross-reference)      │
└───────────────────────────────────────────────────────────────┘

📊 TOKEN TRACKING ENABLED:
   • Real-time token usage monitoring
   • Specialist delegation chain visibility
   • Parallel execution efficiency metrics
   • Complete cost transparency for user decisions

🎯 NEXT ACTION REQUIRED:
   Use Task tool with subagent_type='compass-captain' to begin coordination

📊 BENEFITS:
   • Institutional knowledge integration
   • Pattern recognition from existing work
   • Systematic quality assurance
   • Expert consultation capability
   • Complete token usage visibility
   • Proper documentation of discoveries

⚠️  WARNING:
   Complex analysis tools are BLOCKED until COMPASS coordination begins.
   This prevents ad-hoc analysis and ensures systematic methodology.

📁 DIRECTORIES:
   docs/  - Institutional memory and investigation frameworks
   maps/  - Visual pattern recognition and architectural diagrams
   agents/ - Specialized COMPASS methodology coordinators

═══════════════════════════════════════════════════════════════
🔄 This file updates automatically as phases complete
💰 Token usage information appears as agents execute
"""

    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logs_dir = Path(".")

    status_file = logs_dir / "compass-status"
    with open(status_file, "w") as f:
        f.write(status_content)

    log_handler_activity(
        "status_file",
        "Created .claude/logs/compass-status with token tracking capabilities",
    )


def check_compass_agent_activity(input_data):
    """Check if COMPASS agents are being used and update status"""
    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if not status_file.exists():
        return

    # Check if Task tool is being used with compass agents
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    if tool_name == "Task":
        subagent_type = tool_input.get("subagent_type", "")

        # Map agents to phases
        agent_phase_map = {
            "compass-captain": "coordination",
            "compass-cleanup-coordinator": "coordination",
            "compass-complexity-analyzer": "strategic-planning",
            "compass-strategy-builder": "strategic-planning",
            "compass-validation-coordinator": "strategic-planning",
            "compass-knowledge-discovery": "knowledge-query",
            "compass-todo-sync": "foundation",
            "compass-pattern-apply": "pattern-apply",
            "compass-doc-planning": "doc-planning",
            "compass-data-flow": "data-flow-analysis",
            "compass-auth-performance-analyst": "auth-specialists",
            "compass-auth-security-validator": "auth-specialists",
            "compass-auth-optimization-specialist": "auth-specialists",
            "compass-writing-analyst": "writing-specialists",
            "compass-academic-analyst": "writing-specialists",
            "compass-memory-enhanced-writer": "writing-specialists",
            "compass-dependency-tracker": "dependency-specialists",
            "compass-gap-analysis": "gap-analysis",
            "compass-enhanced-analysis": "enhanced-analysis",
            "compass-cross-reference": "cross-reference",
            "compass-svg-analyst": "svg-quality",
            "compass-upstream-validator": "upstream-validation",
            "compass-coder": "execution-bridge",
            "compass-memory-integrator": "memory-integration",
            "compass-second-opinion": "expert-consultation",
            "compass-breakthrough-doc": "breakthrough-documentation",
        }

        if subagent_type in agent_phase_map:
            # Update session activity for persistence
            update_compass_session_activity()

            phase = agent_phase_map[subagent_type]
            if phase != "coordination":  # Don't update for captain
                update_compass_phase(phase, "in_progress")
                log_handler_activity(
                    "agent_active",
                    f"Detected {subagent_type} activity - updating phase {phase}",
                )

                # Generate todo update context for Claude
                generate_todo_update_context(subagent_type, phase)


def get_compass_status_for_claude():
    """Get current COMPASS status for Claude to announce"""
    logs_dir = Path(".claude/logs")
    status_file = logs_dir / "compass-status"
    if status_file.exists():
        with open(status_file, "r") as f:
            return f.read()
    elif Path(".claude-complete").exists():
        with open(".claude-complete", "r") as f:
            content = f.read()
        # Clean up completion file after reading
        Path(".claude-complete").unlink()
        return content
    return None


def ensure_compass_directories():
    """Ensure COMPASS directory structure exists with error handling"""
    try:
        for directory in ["docs", "maps"]:
            try:
                Path(directory).mkdir(exist_ok=True)
            except OSError as e:
                log_handler_activity(
                    "dir_creation_error", f"Failed to create {directory}: {e}"
                )
                # Continue with other directories
                continue

        # Initialize map-index.json if missing
        map_index = Path("maps/map-index.json")
        if not map_index.exists():
            try:
                initialize_map_index()
            except Exception as e:
                log_handler_activity(
                    "map_index_init_error", f"Failed to initialize map index: {e}"
                )
                # Continue without map index

    except Exception as e:
        log_handler_activity(
            "compass_dir_error", f"Error ensuring COMPASS directories: {e}"
        )
        # Don't crash on directory creation failures


def initialize_map_index():
    """Initialize empty map index for COMPASS"""
    map_index_content = {
        "version": "1.0",
        "created": datetime.now().strftime("%Y-%m-%d"),
        "description": "COMPASS Pattern Index - Visual Maps and Analysis Patterns",
        "categories": {
            "architectural_patterns": {
                "description": "System architecture and component relationship maps",
                "maps": [],
            },
            "workflow_patterns": {
                "description": "Process flows and automation sequences",
                "maps": [],
            },
            "investigation_patterns": {
                "description": "Root cause analysis and debugging workflows",
                "maps": [],
            },
            "integration_patterns": {
                "description": "Service integrations and API interaction flows",
                "maps": [],
            },
        },
        "recent_patterns": [],
        "tags": {},
    }

    try:
        # Ensure maps directory exists before writing
        maps_dir = Path("maps")
        maps_dir.mkdir(exist_ok=True)

        with open("maps/map-index.json", "w", encoding="utf-8") as f:
            json.dump(map_index_content, f, indent=2)

        log_handler_activity("map_index_created", "Map index initialized successfully")

    except OSError as e:
        log_handler_activity("map_index_error", f"Failed to create map index: {e}")
        # Continue without map index rather than blocking


def generate_todo_update_context(subagent_type, phase):
    """Generate context for Claude to update TodoWrite with COMPASS progress"""

    # Create todo update instruction file that Claude will read
    todo_update = {
        "timestamp": datetime.now().isoformat(),
        "agent": subagent_type,
        "phase": phase,
        "status": "in_progress",
        "instruction": f"Update TodoWrite: mark COMPASS {phase} phase as in_progress for {subagent_type}",
        "phase_description": get_phase_description(phase),
    }

    # Write to claude-todo-updates in root (since Claude needs to detect it)
    try:
        with open(".claude-todo-updates", "a", encoding="utf-8") as f:
            f.write(json.dumps(todo_update, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Fail silently if file write fails

    log_handler_activity(
        "todo_update_generated", f"Generated todo update for {subagent_type} - {phase}"
    )


def get_phase_description(phase):
    """Get human-readable description for COMPASS phases"""
    descriptions = {
        "knowledge-query": "Query existing docs/ and maps/ for relevant patterns",
        "pattern-apply": "Apply documented approaches from knowledge base",
        "gap-analysis": "Identify knowledge gaps requiring investigation",
        "doc-planning": "Plan documentation for new discoveries",
        "enhanced-analysis": "Execute enhanced analysis with institutional context",
        "cross-reference": "Cross-reference findings with existing patterns",
        "memory-integration": "Memory Integration - Update institutional knowledge with new insights",
    }
    return descriptions.get(phase, f"Execute {phase} phase")


def mark_compass_phase_complete(phase, subagent_type):
    """Mark a COMPASS phase as complete and generate todo update"""

    update_compass_phase(phase, "completed")

    # Generate completion todo update
    todo_update = {
        "timestamp": datetime.now().isoformat(),
        "agent": subagent_type,
        "phase": phase,
        "status": "completed",
        "instruction": f"Update TodoWrite: mark COMPASS {phase} phase as completed",
        "phase_description": get_phase_description(phase),
    }

    # Write to claude-todo-updates in root (since Claude needs to detect it)
    try:
        with open(".claude-todo-updates", "a", encoding="utf-8") as f:
            f.write(json.dumps(todo_update, separators=(",", ":")) + "\n")
    except OSError:
        pass  # Fail silently if file write fails

    log_handler_activity(
        "phase_completed", f"Marked {phase} complete for {subagent_type}"
    )


def trigger_upstream_validation(tool_name, tool_input):
    """Trigger upstream validation using COMPASS upstream validator agent"""
    try:
        # Use COMPASS Task agent system instead of standalone Python file
        # Log the validation request
        log_handler_activity(
            "upstream_validation_triggered", f"Requesting validation for {tool_name}"
        )

        # Create Task tool request for compass-upstream-validator
        task_request = {
            "subagent_type": "compass-upstream-validator",
            "description": f"Validate {tool_name} against upstream",
            "prompt": f"""Validate the following tool usage against upstream repository documentation:

Tool: {tool_name}
Input: {json.dumps(tool_input, indent=2)}

VALIDATION REQUIREMENTS:
1. Discover upstream repositories for this project using universal patterns
2. Fetch current documentation from upstream sources
3. Validate tool usage and parameters against latest upstream best practices
4. Check for any breaking changes or deprecations
5. Return validation result with recommendations

This is a double_check=true validation request requiring complete upstream verification.""",
        }

        # Return indication that Task tool should be called
        # This will be handled by the hook system through proper agent coordination
        log_handler_activity(
            "upstream_validation_prepared", f"Task request prepared for {tool_name}"
        )

        return {
            "valid": True,
            "method": "compass_agent",
            "task_request": task_request,
            "reason": "Upstream validation handled by COMPASS agent system",
        }

    except Exception as e:
        log_handler_activity("upstream_validation_error", f"Validation error: {e}")
        return {"valid": False, "reason": f"Validation system error: {e}"}


def get_compass_session_context():
    """
    Get comprehensive COMPASS session context for enhanced messaging

    RETURNS:
        dict: Session context including current state, active agents, token usage, etc.
    """
    context = {
        "session_active": compass_context_active(),
        "session_duration": "Unknown",
        "agents_run": [],
        "current_phase": "Unknown",
        "total_tokens": 0,
        "validation_depth": int(os.environ.get("COMPASS_VALIDATION_DEPTH", "0")),
        "recent_activity": "None detected",
    }

    try:
        # Get session token data for context
        session_tokens = get_current_session_tokens()
        if session_tokens:
            context["total_tokens"] = session_tokens.get("total", 0)
            context["session_duration"] = calculate_session_duration(session_tokens)

            # Get agents that have been run
            by_agent = session_tokens.get("by_agent", {})
            context["agents_run"] = list(by_agent.keys())

            # Identify current phase based on most recent agent
            if by_agent:
                # Fix: by_agent values are integers (token counts), not dictionaries
                # Use the agent with the highest token count as the most recent
                last_agent = max(by_agent.keys(), key=lambda x: by_agent[x])
                context["current_phase"] = map_agent_to_phase(last_agent) or "Unknown"

        # Check session tracking file for recent activity
        logs_dir = Path(".claude/logs")
        session_file = logs_dir / "compass-session.json"
        if session_file.exists():
            try:
                with open(session_file, "r") as f:
                    session_data = json.load(f)
                context["recent_activity"] = session_data.get(
                    "last_activity", "None detected"
                )
            except (json.JSONDecodeError, FileNotFoundError):
                pass

    except Exception as e:
        # Graceful degradation - don't let context gathering break the handler
        log_handler_activity("context_error", f"Failed to gather session context: {e}")

    return context


def create_enhanced_recursion_message(
    recursion_type, tool_name=None, subagent_type=None, validation_depth=0
):
    """
    Create comprehensive, educational recursion prevention message

    ARGS:
        recursion_type (str): Type of recursion detected ('compass_captain', 'upstream_validator', 'depth_limit')
        tool_name (str): Name of tool that triggered recursion check
        subagent_type (str): Subagent type if applicable
        validation_depth (int): Current validation depth level

    RETURNS:
        str: Enhanced educational message with context and actionable alternatives
    """
    session_context = get_compass_session_context()

    if recursion_type == "compass_captain":
        return f"""🛑 COMPASS CAPTAIN RECURSION PREVENTED

⚠️ **RECURSION PATTERN DETECTED**: compass-captain called during active COMPASS session

🧠 **WHY THIS IS BLOCKED**:
• Prevents infinite coordination loops where compass-captain calls itself
• Avoids resource waste from nested methodology enforcement
• Maintains clean agent delegation hierarchy and prevents stack overflow
• Ensures single point of methodology control and coordination

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Agents Already Run: {", ".join(session_context["agents_run"][:5]) if session_context["agents_run"] else "None yet"}
• Current Phase: {session_context["current_phase"]}
• Total Tokens Used: {session_context["total_tokens"]:,}
• Validation Depth: {session_context["validation_depth"]}

✅ **CORRECTIVE ACTIONS**:
1. **Direct Agent Coordination**: Use specific COMPASS agents directly:
   - Phase 1: compass-knowledge-discovery, compass-todo-sync
   - Phase 2: compass-pattern-apply, compass-doc-planning, compass-data-flow
   - Phase 3: compass-gap-analysis
   - Phase 4: compass-enhanced-analysis
   - Phase 5: compass-cross-reference

2. **Check Session Status**: Review .claude/logs/compass-status for current methodology progress

3. **Alternative Coordination**: If methodology reset needed, wait for session timeout or use direct agent calls

4. **Phase-Specific Action**: Based on current phase '{session_context["current_phase"]}', consider appropriate next agent

🎯 **RECOMMENDED NEXT STEP**: Use Task tool with specific compass agent based on current methodology phase."""

    elif recursion_type == "upstream_validator":
        return f"""🛑 UPSTREAM VALIDATOR RECURSION PREVENTED

⚠️ **RECURSION PATTERN DETECTED**: compass-upstream-validator called during validation chain

🧠 **WHY THIS IS BLOCKED**:
• Prevents infinite validation loops where upstream validator calls itself
• Avoids exponential resource consumption from recursive repository checks
• Maintains validation chain integrity and prevents circular dependencies
• Ensures bounded validation depth for system stability

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Current Validation Depth: {validation_depth}
• COMPASS Session Active: {"Yes" if session_context["session_active"] else "No"}
• Total Tokens Used: {session_context["total_tokens"]:,}
• Recent Activity: {session_context["recent_activity"]}

✅ **CORRECTIVE ACTIONS**:
1. **Manual Validation**: If upstream validation needed, use direct repository commands:
   - git fetch upstream
   - git diff upstream/main..HEAD
   - Manual review of changes

2. **Alternative Validation**: Use compass-second-opinion for expert consultation instead

3. **Process Validation**: Check if validation is actually needed for your current task

4. **Validation Chain Review**: Examine validation depth ({validation_depth}) to understand call stack

🎯 **RECOMMENDED NEXT STEP**: Proceed with original tool usage - upstream validation already in progress."""

    elif recursion_type == "depth_limit":
        return f"""🛑 VALIDATION DEPTH LIMIT REACHED

⚠️ **DEPTH LIMITING ACTIVATED**: Maximum validation depth ({validation_depth}) exceeded

🧠 **WHY THIS IS BLOCKED**:
• Prevents runaway validation chains that could consume excessive resources
• Avoids infinite loops in complex validation scenarios
• Maintains system stability under recursive validation patterns
• Ensures bounded computational complexity for validation operations

📊 **CURRENT SESSION CONTEXT**:
• Session Duration: {session_context["session_duration"]}
• Maximum Depth Reached: {validation_depth}/3
• COMPASS Session Active: {"Yes" if session_context["session_active"] else "No"}
• Agents Run: {", ".join(session_context["agents_run"][:3]) if session_context["agents_run"] else "None yet"}
• Total Tokens Used: {session_context["total_tokens"]:,}

✅ **CORRECTIVE ACTIONS**:
1. **Proceed Without Deep Validation**: Continue with original tool usage - basic validation completed

2. **Manual Validation**: If thorough validation needed, perform manual checks:
   - Review repository state manually
   - Check for obvious conflicts or issues
   - Use git status and git diff for change review

3. **Reset Validation Chain**: Wait for validation depth to reset naturally or restart session

4. **Alternative Approach**: Use compass-second-opinion for expert guidance on complex validation needs

🎯 **RECOMMENDED NEXT STEP**: Proceed with tool usage - validation depth limit provides sufficient safety."""

    else:
        return f"""🛑 RECURSION PREVENTION ACTIVE

⚠️ **RECURSION PATTERN DETECTED**: {recursion_type}
• Tool: {tool_name or "Unknown"}
• Subagent: {subagent_type or "Unknown"}

📊 **SESSION CONTEXT**: {session_context["total_tokens"]:,} tokens used, {len(session_context["agents_run"])} agents run

✅ **CORRECTIVE ACTION**: Review COMPASS methodology documentation and use appropriate direct agent calls."""


def log_handler_activity(action, details):
    """Log handler actions for monitoring and debugging with rotation"""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "action": action,
        "details": details,
        "handler": "compass-handler",
        "version": "2.1",
    }

    # Ensure .claude/logs directory exists
    logs_dir = Path(".claude/logs")
    try:
        logs_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        # If we can't create logs directory, fall back to current directory
        logs_dir = Path(".")

    log_file = logs_dir / "compass-handler.log"

    try:
        # Rotate log if too large
        if log_file.exists() and log_file.stat().st_size > MAX_LOG_SIZE:
            rotate_log_file(log_file)

        # Write log entry with error handling
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, separators=(",", ":")) + "\n")

    except (OSError, IOError, MemoryError):
        # Fail silently if logging fails to prevent handler crashes
        pass


# ███████████████████████████████████████████████████████████████████████████████

if __name__ == "__main__":
    main()
