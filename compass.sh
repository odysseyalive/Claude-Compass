#!/bin/bash

#=============================================================================
# COMPASS - Unified Claude Code Launcher with Memory Optimization
#
# This single script handles everything:
# - Always updates COMPASS components from latest repository
# - Integrates memory optimization automatically
# - Uses uvx for Claude Code management
# - Supports seamless --resume functionality
# - No separate launchers or complex configuration files needed
#
# Usage:
#   ./compass.sh           # Updates COMPASS, starts Claude with memory optimization
#   ./compass.sh --resume  # Updates COMPASS, resumes Claude with memory optimization
#=============================================================================

set -euo pipefail

# Embedded Serena MCP Integration Functions
# These functions are integrated directly into compass.sh to eliminate
# dependency on external scripts that may not exist in target repositories

# Serena MCP server configuration
readonly SERENA_DEFAULT_PORT=9121
readonly SERENA_MEMORY_LIMIT_MB=512
readonly SERENA_STARTUP_TIMEOUT=30
readonly SERENA_HEALTH_CHECK_TIMEOUT_INITIAL=10
readonly SERENA_HEALTH_CHECK_TIMEOUT_STABLE=2
readonly SERENA_UVX_INITIALIZATION_DELAY=8
readonly SERENA_MONITOR_STARTUP_DELAY=45
readonly SERENA_MONITOR_INTERVAL=30
readonly SERENA_MAX_RETRIES=3

# Global state for Serena integration
SERENA_PORT=0
SERENA_PID=0
SERENA_MONITOR_PID=0
SERENA_INTEGRATION_ENABLED=false

# Script configuration
readonly SCRIPT_VERSION="2.2.0-auto-update"
readonly REPO_URL="https://github.com/odysseyalive/claude-compass"
readonly BRANCH="main"
readonly GITHUB_API_URL="https://api.github.com/repos/odysseyalive/claude-compass"
readonly UPDATE_CHECK_TIMEOUT=10
readonly AUTO_UPDATE_ENABLED=true
readonly DEFAULT_MEMORY_PERCENTAGE=50
readonly MIN_MEMORY_MB=512
readonly MAX_MEMORY_MB=15360 # 15GB maximum for stability
readonly DEFAULT_MEMORY_MB=4096

# Colors for output - with automatic detection
setup_colors() {
  # Check if colors should be disabled
  if [[ "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]] || [[ ! -t 1 ]] || [[ ! -t 2 ]]; then
    # Disable colors: output redirected, NO_COLOR set, or dumb terminal
    readonly RED=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly BLUE=""
    readonly CYAN=""
    readonly NC=""
  else
    # Enable colors: interactive terminal with color support
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
  fi
}

# Initialize colors
setup_colors

# Global state
UPDATE_PERFORMED=false
SELF_UPDATE_PERFORMED=false
MEMORY_MB=0
CLAUDE_ARGS=()
DEBUG_MODE_EARLY=false
AUTO_UPDATE_DISABLED=false

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${CYAN}[SUCCESS]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
  if [[ "${DEBUG:-}" == "1" ]]; then
    echo -e "${BLUE}[DEBUG]${NC} $*" >&2
  fi
}

#=============================================================================
# Serena MCP Integration Functions
#=============================================================================

# Check if Serena MCP server is available via uvx
check_serena_availability() {
  log_info "Checking Serena MCP server availability..."

  # Check if uvx is available
  if ! command -v uvx >/dev/null 2>&1; then
    log_error "uvx not available - required for Serena MCP server"
    return 1
  fi

  # Test Serena installation/availability
  log_debug "Testing Serena availability via uvx..."
  if timeout 10 uvx --from git+https://github.com/oraios/serena serena --help >/dev/null 2>&1; then
    log_success "Serena MCP server available via uvx"
    return 0
  else
    log_warn "Serena MCP server not available or installation needed"
    return 1
  fi
}

# Find an available port starting from the default port
find_available_port() {
  local start_port="${1:-$SERENA_DEFAULT_PORT}"
  local max_attempts=10
  local current_port="$start_port"

  log_debug "Searching for available port starting from $start_port..."

  for ((i = 0; i < max_attempts; i++)); do
    # Check if port is available using multiple methods
    if ! ss -tuln 2>/dev/null | grep -q ":${current_port} " &&
      ! netstat -tuln 2>/dev/null | grep -q ":${current_port} " &&
      ! lsof -i ":${current_port}" >/dev/null 2>&1; then
      log_debug "Found available port: $current_port"
      echo "$current_port"
      return 0
    fi
    log_debug "Port $current_port in use, trying next..."
    current_port=$((current_port + 1))
  done

  log_error "No available ports found in range ${start_port}-$((start_port + max_attempts - 1))"
  return 1
}

# Check if uvx Python process is actually running for Serena
check_uvx_serena_process() {
  local expected_pid="${1:-}"

  # Method 1: Check if expected PID is running and is Python process
  if [[ -n "$expected_pid" ]] && kill -0 "$expected_pid" 2>/dev/null; then
    # Verify it's actually a Python process running Serena
    if ps -p "$expected_pid" -o command --no-headers 2>/dev/null | grep -q "python.*serena"; then
      log_debug "uvx Python process verified (PID: $expected_pid)"
      return 0
    fi
  fi

  # Method 2: Find Python processes running Serena via uvx
  local serena_python_pids
  serena_python_pids=$(pgrep -f "python.*serena.*start-mcp-server" 2>/dev/null || true)

  if [[ -n "$serena_python_pids" ]]; then
    log_debug "Found uvx Serena Python processes: $serena_python_pids"
    return 0
  fi

  log_debug "No uvx Serena Python processes found"
  return 1
}

# SSE-compatible health check with intelligent timeout adjustment
check_serena_server_health() {
  local port="$1"
  local health_check_attempts="${2:-1}"
  local timeout_duration

  # Progressive timeout: Start high, reduce after successful checks
  if ((health_check_attempts <= 3)); then
    timeout_duration="$SERENA_HEALTH_CHECK_TIMEOUT_INITIAL"
  else
    timeout_duration="$SERENA_HEALTH_CHECK_TIMEOUT_STABLE"
  fi

  log_debug "SSE health check attempt $health_check_attempts using ${timeout_duration}s timeout"

  # Method 1: Check SSE endpoint specifically (Serena's primary interface)
  if command -v curl >/dev/null 2>&1; then
    # Test SSE endpoint with proper headers and expect SSE response
    local sse_response
    sse_response=$(timeout "$timeout_duration" curl -s -H "Accept: text/event-stream" -H "Cache-Control: no-cache" \
      --max-time "$timeout_duration" "http://localhost:$port/sse" 2>/dev/null | head -1)
    
    # SSE streams typically start with data: or event: or comment (:)
    if [[ -n "$sse_response" ]] && [[ "$sse_response" =~ ^(data:|event:|:) ]]; then
      log_debug "SSE endpoint responding correctly"
      return 0
    fi
  fi

  # Method 2: Check if the port accepts connections (TCP check)
  if timeout "$timeout_duration" bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
    log_debug "Port accepting connections"
    return 0
  fi

  # Method 3: netcat verification if available
  if command -v nc >/dev/null 2>&1 && timeout "$timeout_duration" nc -z localhost "$port" 2>/dev/null; then
    log_debug "Port verified via netcat"
    return 0
  fi

  # Method 4: Fallback health endpoint check (if Serena provides one)
  if command -v curl >/dev/null 2>&1; then
    if timeout "$timeout_duration" curl -sf --max-time "$timeout_duration" "http://localhost:$port/health" >/dev/null 2>&1; then
      log_debug "Health endpoint responding"
      return 0
    fi
  fi

  # Method 5: Process validation - ensure the Python process is still running
  if [[ -f ".compass/serena-mcp-server.pid" ]]; then
    local server_pid
    server_pid=$(cat .compass/serena-mcp-server.pid 2>/dev/null || echo "")
    if [[ -n "$server_pid" ]] && check_uvx_serena_process "$server_pid"; then
      log_debug "Server process still running, may be initializing"
      return 0
    fi
  fi

  return 1
}

# Start Serena MCP server with memory limits and logging
# Wrapper function with retry logic and enhanced failsafe
start_serena_mcp_server_with_retry() {
  local port="$1"
  local max_retries="${SERENA_MAX_RETRIES:-3}"
  local retry_count=0

  while ((retry_count < max_retries)); do
    log_info "Starting Serena MCP server (attempt $((retry_count + 1))/$max_retries)"

    # Run failsafe cleanup before each attempt
    if ! failsafe_cleanup_serena_processes; then
      log_warn "Failsafe cleanup reported issues, but continuing with startup attempt"
    fi

    # Attempt to start the server
    if start_serena_mcp_server "$port"; then
      log_success "Serena MCP server started successfully on attempt $((retry_count + 1))"
      return 0
    fi

    retry_count=$((retry_count + 1))
    if ((retry_count < max_retries)); then
      log_warn "Serena startup failed, retrying in 3 seconds... (attempt $retry_count/$max_retries)"
      sleep 3

      # Force cleanup between retries
      cleanup_serena_server >/dev/null 2>&1
      sleep 1
    fi
  done

  log_error "Failed to start Serena MCP server after $max_retries attempts"
  return 1
}

start_serena_mcp_server() {
  local port="$1"
  local log_file=".compass/logs/serena-mcp-server.log"
  local pid_file=".compass/serena-mcp-server.pid"

  log_info "Starting Serena MCP server on port ${port}..."

  # Ensure log and state directories exist
  mkdir -p "$(dirname "$log_file")"
  mkdir -p .compass

  # Enhanced failsafe cleanup before startup
  failsafe_cleanup_serena_processes

  # Clean up any existing server first
  cleanup_serena_server >/dev/null 2>&1

  # Start server in background with proper process group isolation and timeout protection
  {
    # Create new process group for better isolation and cleanup
    setsid bash -c '
      # Use timeout to prevent hanging during server startup - increased for SSE initialization
      exec timeout 45 uvx --from git+https://github.com/oraios/serena \
        serena start-mcp-server \
        --transport sse \
        --port '"$port"' \
        --context ide-assistant 2>&1
    ' | while IFS= read -r line; do
      echo "$(date '+%Y-%m-%d %H:%M:%S') [SERENA] $line"
    done

    # Check if timeout occurred
    local exit_code=${PIPESTATUS[0]}
    if [[ $exit_code -eq 124 ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [SERENA] ERROR: Server startup timed out after 45 seconds"
    elif [[ $exit_code -ne 0 ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [SERENA] ERROR: Server startup failed with exit code $exit_code"
    fi
  } >"$log_file" 2>&1 &

  local server_pid=$!
  echo "$server_pid" >"$pid_file"
  SERENA_PID="$server_pid"

  log_debug "Serena MCP server started with PID: $server_pid"

  # Health check with timeout - more robust approach
  local max_wait="$SERENA_STARTUP_TIMEOUT"
  local wait_time=0
  local health_check_interval=1

  log_info "Waiting for Serena MCP server to become healthy..."

  # Extended delay for uvx initialization
  log_info "Allowing ${SERENA_UVX_INITIALIZATION_DELAY}s for uvx initialization..."
  sleep "$SERENA_UVX_INITIALIZATION_DELAY"

  local health_check_count=0
  while ((wait_time < max_wait)); do
    health_check_count=$((health_check_count + 1))

    # First check if the process is still running and is the expected Python process
    if ! check_uvx_serena_process "$server_pid"; then
      log_error "Serena MCP server uvx Python process not found or died (PID: $server_pid)"
      cleanup_serena_server
      return 1
    fi

    # Then check if port is responding with progressive timeout
    if check_serena_server_health "$port" "$health_check_count"; then
      log_success "Serena MCP server healthy on port $port (verified after $health_check_count health checks)"
      SERENA_PORT="$port"
      cache_serena_state "$port" "$server_pid"
      return 0
    fi

    sleep "$health_check_interval"
    wait_time=$((wait_time + health_check_interval))

    # Provide feedback every few seconds to show progress
    if ((wait_time % 3 == 0)); then
      log_debug "Still waiting for Serena server on port $port (${wait_time}/${max_wait}s, health check #$health_check_count)"
    fi
  done

  log_warn "Serena MCP server failed to respond within ${max_wait} seconds - cleanup and continue"
  cleanup_serena_server
  return 1
}

# Monitor Serena server health and recover if needed
monitor_serena_server() {
  local port="$1"
  local pid_file=".compass/serena-monitor.pid"
  local monitor_log=".compass/logs/serena-monitor.log"

  # Ensure log directory exists
  mkdir -p "$(dirname "$monitor_log")"

  # Note: PID file will be written by parent process after backgrounding
  # Do not write PID here to avoid race condition

  # Log function for monitor (writes to file instead of terminal)
  monitor_log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >>"$monitor_log"
  }

  monitor_log "INFO" "Starting Serena MCP server health monitoring (PID: $$)"
  monitor_log "INFO" "Waiting ${SERENA_MONITOR_STARTUP_DELAY}s before beginning health monitoring..."

  # Delay monitor startup to let server stabilize
  sleep "$SERENA_MONITOR_STARTUP_DELAY"

  monitor_log "INFO" "Health monitoring active - checking every ${SERENA_MONITOR_INTERVAL}s"

  local consecutive_failures=0
  local max_consecutive_failures=5
  local health_check_count=0

  while true; do
    health_check_count=$((health_check_count + 1))

    if ! check_serena_server_health "$port" "$health_check_count"; then
      consecutive_failures=$((consecutive_failures + 1))
      monitor_log "WARN" "Serena MCP server unhealthy (failure $consecutive_failures/$max_consecutive_failures), attempting recovery..."

      if attempt_serena_recovery "true"; then
        monitor_log "SUCCESS" "Serena MCP server recovered successfully"
        consecutive_failures=0 # Reset failure counter on success
      else
        monitor_log "ERROR" "Serena MCP server recovery failed (attempt $consecutive_failures)"

        # Only stop monitoring after repeated failures
        if ((consecutive_failures >= max_consecutive_failures)); then
          monitor_log "ERROR" "Max consecutive failures reached - entering degraded monitoring mode"
          # Continue monitoring but with longer intervals and no recovery attempts
          while true; do
            sleep $((SERENA_MONITOR_INTERVAL * 3)) # 3x normal interval
            health_check_count=$((health_check_count + 1))
            if check_serena_server_health "$port" "$health_check_count"; then
              monitor_log "INFO" "Serena MCP server spontaneously recovered - resuming normal monitoring"
              consecutive_failures=0
              break # Exit degraded mode and resume normal monitoring
            fi
            monitor_log "DEBUG" "Degraded monitoring: server still unhealthy"
          done
        fi
      fi
    else
      if ((consecutive_failures > 0)); then
        monitor_log "INFO" "Health check passed after $consecutive_failures failures - normal operation resumed"
      fi
      consecutive_failures=0
      monitor_log "DEBUG" "Serena MCP server health check passed"
      update_serena_metrics "$port"
    fi

    sleep "$SERENA_MONITOR_INTERVAL"
  done

  # Clean up monitor PID file
  rm -f "$pid_file"
  monitor_log "INFO" "Serena MCP server monitoring stopped"

  # Exit cleanly to prevent zombie processes
  exit 0
}

# Attempt to recover Serena MCP server
attempt_serena_recovery() {
  local silent_mode="${1:-false}" # Optional parameter for silent logging
  local retry_count=0
  local recovery_delay=10

  while ((retry_count < SERENA_MAX_RETRIES)); do
    if [[ "$silent_mode" == "true" ]]; then
      monitor_log "INFO" "Attempting Serena MCP server recovery (attempt $((retry_count + 1))/$SERENA_MAX_RETRIES)"
    else
      log_info "Attempting Serena MCP server recovery (attempt $((retry_count + 1))/$SERENA_MAX_RETRIES)"
    fi

    if [[ "$silent_mode" == "true" ]]; then
      cleanup_serena_server "true"
    else
      cleanup_serena_server
    fi
    sleep "$recovery_delay"

    local serena_port
    if [[ "$silent_mode" == "true" ]]; then
      # In silent mode, redirect all output from recovery operations to the monitor log
      if serena_port=$(find_available_port "$SERENA_DEFAULT_PORT" 2>/dev/null); then
        if start_serena_mcp_server_with_retry "$serena_port" >/dev/null 2>&1; then
          if register_serena_with_claude "$serena_port" >/dev/null 2>&1; then
            monitor_log "SUCCESS" "Serena MCP server recovery successful"
            return 0
          fi
        fi
      fi
    else
      # Normal mode with regular logging
      if serena_port=$(find_available_port "$SERENA_DEFAULT_PORT"); then
        if start_serena_mcp_server_with_retry "$serena_port"; then
          if register_serena_with_claude "$serena_port"; then
            log_success "Serena MCP server recovery successful"
            return 0
          fi
        fi
      fi
    fi

    retry_count=$((retry_count + 1))
    recovery_delay=$((recovery_delay * 2)) # Exponential backoff
  done

  if [[ "$silent_mode" == "true" ]]; then
    monitor_log "ERROR" "Serena MCP server recovery failed after $SERENA_MAX_RETRIES attempts"
  else
    log_error "Serena MCP server recovery failed after $SERENA_MAX_RETRIES attempts"
  fi
  return 1
}

# Register Serena MCP server with Claude
register_serena_with_claude() {
  local port="$1"
  local server_url="http://localhost:${port}/sse"

  log_info "Registering Serena MCP server with Claude..."

  # Check if Claude command is available
  if ! command -v claude >/dev/null 2>&1; then
    log_warn "Claude command not available - skipping MCP registration"
    return 1
  fi

  # Check if already registered
  if claude mcp list 2>/dev/null | grep -q "serena.*${port}"; then
    log_info "Serena MCP server already registered with Claude"
    return 0
  fi

  # Register with Claude MCP system
  if claude mcp add serena --transport sse "$server_url" 2>/dev/null; then
    log_success "Serena MCP server registered with Claude successfully"

    # Verify registration
    sleep 2 # Give Claude time to update
    if claude mcp list 2>/dev/null | grep -q "serena"; then
      log_success "Serena MCP server registration verified"
      return 0
    else
      log_warn "Serena MCP server registration could not be verified"
      return 1
    fi
  else
    log_error "Failed to register Serena MCP server with Claude"
    return 1
  fi
}

# Configure Claude settings for Serena MCP integration
configure_serena_mcp_settings() {
  local port="$1"
  local config_file="$HOME/.claude/settings.json"

  log_info "Configuring Serena MCP settings in Claude..."

  # Ensure Claude config directory exists
  mkdir -p "$(dirname "$config_file")"

  # Create or update Claude settings for Serena integration
  python3 <<EOF
import json
import os
from pathlib import Path

config_path = "$config_file"
config = {}

# Load existing configuration
if os.path.exists(config_path):
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError:
        print("Warning: Invalid JSON in settings file, updating configuration")
        config = {}

# Ensure compass configuration exists
if 'compass_unified' not in config:
    config['compass_unified'] = {}

# Add Serena-specific settings to compass configuration
config['compass_unified']['serena_mcp'] = {
    'enabled': True,
    'auto_start': True,
    'port': $port,
    'health_check_interval': $SERENA_MONITOR_INTERVAL,
    'recovery_enabled': True,
    'memory_limit_mb': $SERENA_MEMORY_LIMIT_MB,
    'integration_version': '1.0.0'
}

# Write updated configuration
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("Serena MCP configuration updated successfully")
EOF

  if [[ $? -eq 0 ]]; then
    log_success "Serena MCP settings configured in Claude"
    return 0
  else
    log_error "Failed to configure Serena MCP settings"
    return 1
  fi
}

# Cache Serena server state for monitoring
cache_serena_state() {
  local port="$1"
  local pid="$2"
  local cache_dir=".compass/cache/serena"

  mkdir -p "$cache_dir"

  cat >"$cache_dir/server-state.json" <<EOF
{
    "port": $port,
    "pid": $pid,
    "started_at": "$(date -Iseconds)",
    "health_status": "healthy",
    "integration_status": "active",
    "memory_limit_mb": $SERENA_MEMORY_LIMIT_MB
}
EOF
}

# Update Serena server metrics
update_serena_metrics() {
  local port="$1"
  local metrics_file=".compass/logs/serena-metrics.log"

  # Ensure log directory exists
  mkdir -p "$(dirname "$metrics_file")"

  # Get server PID
  local server_pid
  if [[ -f ".compass/serena-mcp-server.pid" ]]; then
    server_pid=$(cat .compass/serena-mcp-server.pid)
  else
    server_pid="unknown"
  fi

  # Get memory usage if possible
  local memory_usage="unknown"
  if [[ "$server_pid" != "unknown" ]] && kill -0 "$server_pid" 2>/dev/null; then
    memory_usage=$(ps -o rss= -p "$server_pid" 2>/dev/null | awk '{print $1/1024 " MB"}' || echo "unknown")
  fi

  # Log metrics
  {
    echo "$(date -Iseconds) SERENA_METRICS"
    echo "  Port: $port"
    echo "  PID: $server_pid"
    echo "  Memory: $memory_usage"
    echo "  Health: $(check_serena_server_health "$port" && echo 'healthy' || echo 'unhealthy')"
    echo "  Uptime: $(ps -o etime= -p "$server_pid" 2>/dev/null | tr -d ' ' || echo 'unknown')"
  } >>"$metrics_file"
}

# Clean up Serena MCP server processes and state
# Enhanced failsafe cleanup to handle orphaned processes, zombie processes, and port conflicts
failsafe_cleanup_serena_processes() {
  log_debug "Running enhanced failsafe Serena process cleanup..."

  local cleanup_errors=0
  local target_port="${SERENA_PORT:-$SERENA_DEFAULT_PORT}"

  # 1. Handle zombie and orphaned processes first
  log_debug "Phase 1: Cleaning up zombie and orphaned processes"
  
  # Find and clean up zombie processes
  local zombie_pids=$(ps axo stat,pid,command | awk '$1~/Z/ && /serena/ {print $2}' 2>/dev/null || true)
  if [[ -n "$zombie_pids" ]]; then
    log_warn "Found zombie Serena processes: $zombie_pids"
    # Send SIGCHLD to parent processes to clean up zombies
    for pid in $zombie_pids; do
      local parent_pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
      if [[ -n "$parent_pid" ]] && [[ "$parent_pid" != "1" ]]; then
        kill -CHLD "$parent_pid" 2>/dev/null || true
      fi
    done
    sleep 1
  fi

  # 2. Check if target port is in use and identify processes with enhanced detection
  log_debug "Phase 2: Port conflict resolution"
  local port_pids=$(lsof -ti :"$target_port" 2>/dev/null || true)
  
  if [[ -n "$port_pids" ]]; then
    log_warn "Port $target_port is in use by processes: $port_pids"
    
    # Graceful termination first
    for pid in $port_pids; do
      if kill -0 "$pid" 2>/dev/null; then
        log_debug "Gracefully terminating process $pid using port $target_port"
        kill -TERM "$pid" 2>/dev/null || ((cleanup_errors++))
      fi
    done
    
    # Wait for graceful shutdown
    sleep 3
    
    # Check if processes are still running and force kill if necessary
    for pid in $port_pids; do
      if kill -0 "$pid" 2>/dev/null; then
        log_warn "Force killing stubborn process $pid using port $target_port"
        kill -KILL "$pid" 2>/dev/null || ((cleanup_errors++))
      fi
    done
    
    # Additional wait for port to be released
    sleep 2
  fi

  # 3. Find and terminate all Serena-related processes with better pattern matching
  log_debug "Phase 3: Comprehensive Serena process cleanup"
  
  # Multiple patterns to catch all Serena processes
  local serena_patterns=("serena start-mcp-server" "python.*serena.*start-mcp-server" "uvx.*serena" "serena.*mcp")
  
  for pattern in "${serena_patterns[@]}"; do
    local serena_pids=$(pgrep -f "$pattern" 2>/dev/null || true)
    if [[ -n "$serena_pids" ]]; then
      log_warn "Found processes matching '$pattern': $serena_pids"
      
      # Process group termination for better cleanup
      for pid in $serena_pids; do
        if kill -0 "$pid" 2>/dev/null; then
          # Try to terminate the entire process group
          local pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || echo "$pid")
          if [[ -n "$pgid" ]] && [[ "$pgid" != "$pid" ]]; then
            log_debug "Terminating process group $pgid for process $pid"
            kill -TERM -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || ((cleanup_errors++))
          else
            kill -TERM "$pid" 2>/dev/null || ((cleanup_errors++))
          fi
        fi
      done
      
      # Wait for graceful shutdown
      sleep 2
      
      # Force kill remaining processes
      for pid in $serena_pids; do
        if kill -0 "$pid" 2>/dev/null; then
          log_warn "Force killing stubborn Serena process $pid"
          kill -KILL "$pid" 2>/dev/null || ((cleanup_errors++))
        fi
      done
    fi
  done

  # 4. Enhanced stale PID file validation and cleanup
  log_debug "Phase 4: Enhanced PID file cleanup"
  local pid_files=(".compass/serena-mcp-server.pid" ".compass/serena-monitor.pid")
  
  for pid_file in "${pid_files[@]}"; do
    if [[ -f "$pid_file" ]]; then
      local recorded_pid=$(cat "$pid_file" 2>/dev/null || true)
      if [[ -n "$recorded_pid" ]] && [[ "$recorded_pid" =~ ^[0-9]+$ ]]; then
        if ! kill -0 "$recorded_pid" 2>/dev/null; then
          log_debug "Removing stale PID file $pid_file for non-existent process: $recorded_pid"
          rm -f "$pid_file" || ((cleanup_errors++))
        else
          # Process still exists, check if it's actually a Serena process
          local process_cmd=$(ps -p "$recorded_pid" -o command --no-headers 2>/dev/null || true)
          if [[ -n "$process_cmd" ]] && ! echo "$process_cmd" | grep -q "serena"; then
            log_warn "PID file $pid_file contains PID $recorded_pid but process is not Serena: $process_cmd"
            log_warn "Removing potentially corrupted PID file"
            rm -f "$pid_file" || ((cleanup_errors++))
          fi
        fi
      else
        log_warn "Invalid PID in file $pid_file: '$recorded_pid'"
        rm -f "$pid_file" || ((cleanup_errors++))
      fi
    fi
  done

  # 5. Final comprehensive port and process verification
  log_debug "Phase 5: Final verification and cleanup"
  
  # Multiple port check methods for reliability
  local port_still_in_use=false
  
  if lsof -ti :"$target_port" >/dev/null 2>&1; then
    port_still_in_use=true
  elif netstat -tuln 2>/dev/null | grep -q ":${target_port} "; then
    port_still_in_use=true
  elif ss -tuln 2>/dev/null | grep -q ":${target_port} "; then
    port_still_in_use=true
  fi
  
  if [[ "$port_still_in_use" == "true" ]]; then
    log_error "Port $target_port still in use after comprehensive cleanup - startup may fail"
    ((cleanup_errors++))
  fi
  
  # Clean up any remaining cache/state files
  rm -f .compass/cache/serena/server-state.json 2>/dev/null || true
  
  # Final process verification
  local remaining_serena=$(pgrep -f "serena" 2>/dev/null | wc -l)
  if [[ "$remaining_serena" -gt 0 ]]; then
    log_warn "Still found $remaining_serena Serena-related processes after cleanup"
    ((cleanup_errors++))
  fi

  if [[ "$cleanup_errors" -eq 0 ]]; then
    log_debug "Enhanced failsafe cleanup completed successfully - port $target_port is available"
    return 0
  else
    log_warn "Enhanced failsafe cleanup completed with $cleanup_errors errors - some issues may persist"
    return 1
  fi
}

cleanup_serena_server() {
  local silent_mode="${1:-false}" # Optional parameter for silent operation

  if [[ "$silent_mode" == "true" ]]; then
    monitor_log "DEBUG" "Cleaning up Serena MCP server..."
  else
    log_debug "Cleaning up Serena MCP server..."
  fi

  local pid_file=".compass/serena-mcp-server.pid"
  local monitor_pid_file=".compass/serena-monitor.pid"

  # Stop health monitoring first
  if [[ -f "$monitor_pid_file" ]]; then
    local monitor_pid=$(cat "$monitor_pid_file")
    if kill -0 "$monitor_pid" 2>/dev/null; then
      if [[ "$silent_mode" == "true" ]]; then
        monitor_log "DEBUG" "Stopping Serena health monitor (PID: $monitor_pid)"
      else
        log_debug "Stopping Serena health monitor (PID: $monitor_pid)"
      fi
      kill -TERM "$monitor_pid" 2>/dev/null
    fi
    rm -f "$monitor_pid_file"
  fi

  # Kill server process if running
  if [[ -f "$pid_file" ]]; then
    local server_pid=$(cat "$pid_file")
    if kill -0 "$server_pid" 2>/dev/null; then
      if [[ "$silent_mode" == "true" ]]; then
        monitor_log "DEBUG" "Stopping Serena MCP server (PID: $server_pid)"
      else
        log_debug "Stopping Serena MCP server (PID: $server_pid)"
      fi
      kill -TERM "$server_pid" 2>/dev/null

      # Wait for graceful shutdown
      local wait_count=0
      while kill -0 "$server_pid" 2>/dev/null && ((wait_count < 10)); do
        sleep 1
        wait_count=$((wait_count + 1))
      done

      # Force kill if still running
      if kill -0 "$server_pid" 2>/dev/null; then
        if [[ "$silent_mode" == "true" ]]; then
          monitor_log "DEBUG" "Force killing Serena MCP server"
        else
          log_debug "Force killing Serena MCP server"
        fi
        kill -KILL "$server_pid" 2>/dev/null
      fi
    fi

    rm -f "$pid_file"
  fi

  # Clean up any remaining Serena processes
  pkill -f "serena start-mcp-server" 2>/dev/null || true

  # Reset global state
  SERENA_PID=0
  SERENA_PORT=0
  SERENA_MONITOR_PID=0

  if [[ "$silent_mode" == "true" ]]; then
    monitor_log "DEBUG" "Serena MCP server cleanup completed"
  else
    log_debug "Serena MCP server cleanup completed"
  fi
}

# Set up signal handlers for graceful shutdown
setup_serena_signal_handlers() {
  # Set up signal handlers for graceful shutdown
  trap 'cleanup_serena_server' INT TERM EXIT

  log_debug "Serena MCP server signal handlers configured"
}

# Phase 1: Start Serena MCP server only (before Claude init)
start_serena_mcp_server_only() {
  log_info "Starting Serena MCP server (Phase 1 - Pre-initialization)..."

  # Check if Serena integration should be enabled
  if [[ "${SERENA_INTEGRATION_DISABLED:-}" == "true" ]]; then
    log_info "Serena MCP integration disabled by environment variable"
    return 0
  fi

  # Check Serena availability first (fail fast if not available)
  if ! check_serena_availability; then
    log_warn "Serena not available - continuing without Serena integration"
    return 1
  fi

  # Find available port
  local serena_port
  if ! serena_port=$(find_available_port "$SERENA_DEFAULT_PORT"); then
    log_warn "No available ports for Serena MCP server - continuing without Serena integration"
    return 1
  fi

  # Set up signal handlers
  setup_serena_signal_handlers

  # Start Serena MCP server
  if ! start_serena_mcp_server_with_retry "$serena_port"; then
    log_warn "Serena MCP server startup failed - continuing without Serena integration"
    return 1
  fi

  # Store port for later registration
  SERENA_PORT="$serena_port"

  log_success "Serena MCP server started successfully (Port: $serena_port, PID: $SERENA_PID)"
  log_info "Server ready for Claude initialization with enhanced capabilities"
  return 0
}

# Phase 2: Complete Serena integration after Claude is initialized
complete_serena_mcp_integration() {
  log_info "Completing Serena MCP server integration (Phase 2 - Post-initialization)..."

  # Check if Serena was started in Phase 1
  if [[ "$SERENA_PORT" -eq 0 ]] || [[ "$SERENA_PID" -eq 0 ]]; then
    log_debug "Serena not started in Phase 1, skipping Phase 2"
    return 1
  fi

  # Verify server is still running
  if ! check_serena_server_health "$SERENA_PORT" 1; then
    log_warn "Serena server no longer healthy, attempting restart"
    if ! start_serena_mcp_server_with_retry "$SERENA_PORT"; then
      log_warn "Failed to restart Serena server"
      return 1
    fi
  fi

  # Configure Claude settings
  if ! configure_serena_mcp_settings "$SERENA_PORT"; then
    log_warn "Serena MCP settings configuration failed - server running but not optimally configured"
  fi

  # Register with Claude
  if ! register_serena_with_claude "$SERENA_PORT"; then
    log_warn "Claude MCP registration failed - Serena server running but not integrated with Claude"
  fi

  # Start background health monitoring with proper process group isolation
  # Use setsid to create new session and process group for complete isolation
  {
    # Create isolated monitoring process with proper process group
    setsid nohup monitor_serena_server "$SERENA_PORT" </dev/null >/dev/null 2>&1 &
    local monitor_pid=$!
    echo "$monitor_pid" >.compass/serena-monitor.pid
    SERENA_MONITOR_PID="$monitor_pid"

    # Disown the background process completely to prevent signal inheritance
    disown "$monitor_pid" 2>/dev/null || true

    log_debug "Background monitor starting with process group isolation and ${SERENA_MONITOR_STARTUP_DELAY}s delay (PID: $monitor_pid)"
  } 2>/dev/null || {
    # Fallback to standard background process if setsid fails
    nohup monitor_serena_server "$SERENA_PORT" </dev/null >/dev/null 2>&1 &
    local monitor_pid=$!
    echo "$monitor_pid" >.compass/serena-monitor.pid
    SERENA_MONITOR_PID="$monitor_pid"
    disown "$monitor_pid" 2>/dev/null || true
    log_debug "Background monitor setup completed with standard isolation (PID: $monitor_pid)"
  }

  # Mark integration as successful
  SERENA_INTEGRATION_ENABLED=true

  log_success "Serena MCP server integration complete (Port: $SERENA_PORT, PID: $SERENA_PID)"
  return 0
}

# Main function to integrate Serena MCP server with COMPASS (legacy wrapper)
integrate_serena_mcp_server() {
  log_info "Initializing Serena MCP server integration..."

  # Check if Claude is properly initialized before starting Serena
  if ! early_check_claude_initialization; then
    log_warn "Claude Code not initialized - attempting Phase 1 only"
    return start_serena_mcp_server_only
  fi

  # If Claude is initialized, do full integration
  if [[ "$SERENA_PORT" -eq 0 ]]; then
    # Serena wasn't started in Phase 1, do full startup now
    start_serena_mcp_server_only
  fi

  # Complete the integration
  complete_serena_mcp_integration
  return $?
}

# Function to check Serena integration status
check_serena_integration_status() {
  # Redirect all error-prone operations to prevent Claude startup interference
  local status_msg="Serena MCP integration: "

  if [[ "$SERENA_INTEGRATION_ENABLED" == "true" ]] &&
    [[ "$SERENA_PORT" -gt 0 ]] &&
    check_serena_server_health "$SERENA_PORT" 1 2>/dev/null; then
    echo "${status_msg}Active (Port: $SERENA_PORT)"
    return 0
  else
    # Check if monitor is still running despite integration issues
    if [[ -f ".compass/serena-monitor.pid" ]]; then
      local monitor_pid
      monitor_pid=$(cat .compass/serena-monitor.pid 2>/dev/null || echo "")
      if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null; then
        echo "${status_msg}Monitoring (PID: $monitor_pid)"
        return 0
      fi
    fi

    echo "${status_msg}Inactive"
    return 1
  fi
}

#=============================================================================
# End Serena MCP Integration Functions
#=============================================================================

#=============================================================================
# Auto-Update System Functions
#=============================================================================

# Parse --debug flag early for auto-update bypass
parse_early_debug_flag() {
  local arg
  for arg in "$@"; do
    case "$arg" in
    --debug)
      DEBUG_MODE_EARLY=true
      AUTO_UPDATE_DISABLED=true
      export DEBUG=1
      log_debug "Early debug mode detected - auto-update disabled"
      return 0
      ;;
    --no-auto-update)
      AUTO_UPDATE_DISABLED=true
      log_info "Auto-update disabled by flag"
      return 0
      ;;
    esac
  done
  return 0
}

# Get latest version from GitHub API
get_latest_version() {
  log_debug "Checking latest version from GitHub API..."

  local latest_version
  latest_version=$(timeout "$UPDATE_CHECK_TIMEOUT" curl -fsSL \
    "${GITHUB_API_URL}/releases/latest" 2>/dev/null |
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tag = data.get('tag_name', '')
    # Strip 'v' prefix if present
    version = tag.lstrip('v')
    print(version)
except:
    sys.exit(1)
" 2>/dev/null)

  if [[ -n "$latest_version" ]]; then
    echo "$latest_version"
    return 0
  else
    log_debug "Failed to fetch latest version from GitHub API"
    return 1
  fi
}

# Compare version strings (semantic versioning)
compare_versions() {
  local current="$1"
  local latest="$2"

  # Remove any non-version suffixes (like "-serena-integrated", "-auto-update")
  current=$(echo "$current" | sed 's/-.*$//')
  latest=$(echo "$latest" | sed 's/-.*$//')

  log_debug "Comparing versions: current='$current' vs latest='$latest'"

  # Use Python for proper semantic version comparison
  python3 <<EOF
import sys
from packaging import version

try:
    current_ver = version.parse("$current")
    latest_ver = version.parse("$latest")
    
    if latest_ver > current_ver:
        print("update_available")
        sys.exit(0)
    elif latest_ver == current_ver:
        print("current")
        sys.exit(0)
    else:
        print("newer")
        sys.exit(0)
except ImportError:
    # Fallback to simple string comparison if packaging module unavailable
    if "$latest" != "$current":
        print("update_available")
    else:
        print("current")
except Exception as e:
    print("error")
    sys.exit(1)
EOF
}

# Download latest compass.sh from GitHub
download_latest_script() {
  local temp_dir="$1"
  local script_url="${REPO_URL}/raw/${BRANCH}/compass.sh"
  local temp_script="${temp_dir}/compass.sh.new"

  log_info "Downloading latest compass.sh from GitHub..."
  log_debug "Download URL: $script_url"

  if timeout "$UPDATE_CHECK_TIMEOUT" curl -fsSL "$script_url" -o "$temp_script"; then
    # Verify downloaded script has valid shebang and basic structure
    if [[ -f "$temp_script" ]] &&
      head -1 "$temp_script" | grep -q "^#!/bin/bash" &&
      grep -q "SCRIPT_VERSION=" "$temp_script" &&
      grep -q "main()" "$temp_script"; then
      log_success "Downloaded and validated new script version"
      echo "$temp_script"
      return 0
    else
      log_error "Downloaded script failed validation"
      return 1
    fi
  else
    log_error "Failed to download latest script from GitHub"
    return 1
  fi
}

# Create backup of current script
create_script_backup() {
  local script_path="$1"
  local backup_path="${script_path}.backup.$(date +%s)"

  if cp "$script_path" "$backup_path"; then
    log_debug "Created backup: $backup_path"
    echo "$backup_path"
    return 0
  else
    log_error "Failed to create script backup"
    return 1
  fi
}

# Atomic script replacement
replace_script_atomically() {
  local current_script="$1"
  local new_script="$2"
  local backup_path="$3"

  log_info "Performing atomic script replacement..."

  # Make new script executable
  chmod +x "$new_script" || {
    log_error "Failed to make new script executable"
    return 1
  }

  # Atomic move (should be atomic on most filesystems)
  if mv "$new_script" "$current_script"; then
    log_success "Script replaced successfully"
    log_info "Backup available at: $backup_path"
    return 0
  else
    log_error "Failed to replace script"
    # Restore from backup if move failed
    if [[ -f "$backup_path" ]]; then
      cp "$backup_path" "$current_script"
      log_info "Restored from backup due to replacement failure"
    fi
    return 1
  fi
}

# Early check for Claude initialization (before auto-update)
early_check_claude_initialization() {
  log_debug "Performing early Claude initialization check..."

  local claude_config_dir="$HOME/.claude"
  local credentials_file="$claude_config_dir/.credentials.json"
  local settings_file="$claude_config_dir/settings.json"
  local needs_claude_init=false
  local claude_available=false

  # Check if Claude command is available
  if command -v claude >/dev/null 2>&1; then
    claude_available=true
    log_debug "Claude command is available"
  else
    log_debug "Claude command not available yet"
    return 1 # Definitely needs initialization if command doesn't exist
  fi

  # Check basic initialization requirements (file-based checks are more reliable)
  if [[ ! -d "$claude_config_dir" ]]; then
    log_debug "Claude config directory missing"
    needs_claude_init=true
  elif [[ ! -f "$credentials_file" ]]; then
    log_debug "Claude credentials missing"
    needs_claude_init=true
  elif [[ ! -f "$settings_file" ]]; then
    log_debug "Claude settings file missing"
    needs_claude_init=true
  fi

  # Enhanced config flag checking with timeouts and fallbacks for remote servers
  if [[ "$claude_available" == "true" ]] && [[ "$needs_claude_init" == "false" ]]; then
    local trust_accepted=false
    local onboarding_complete=false

    # Check trust dialog status with timeout (5 seconds max)
    log_debug "Checking Claude trust dialog status..."
    if timeout 5 claude config get hasTrustDialogAccepted 2>/dev/null | grep -q "true"; then
      trust_accepted=true
      log_debug "Trust dialog accepted"
    else
      log_debug "Trust dialog check failed or returned false"
    fi

    # Check onboarding status with timeout (5 seconds max)
    log_debug "Checking Claude onboarding status..."
    if timeout 5 claude config get hasCompletedProjectOnboarding 2>/dev/null | grep -q "true"; then
      onboarding_complete=true
      log_debug "Project onboarding complete"
    else
      log_debug "Project onboarding check failed or incomplete"
    fi

    # If config commands failed (remote server issues), use heuristics
    if [[ "$trust_accepted" == "false" ]] || [[ "$onboarding_complete" == "false" ]]; then
      # Fallback: Check for signs of successful initialization
      if [[ -d "$claude_config_dir/projects" ]] && [[ -d "$claude_config_dir/shell-snapshots" ]] && [[ -s "$credentials_file" ]]; then
        log_debug "Config commands failed but files suggest Claude is initialized"
        trust_accepted=true
        onboarding_complete=true
      else
        log_debug "Config commands failed and files don't suggest full initialization"
        needs_claude_init=true
      fi
    fi

    # Final determination
    if [[ "$trust_accepted" == "false" ]] || [[ "$onboarding_complete" == "false" ]]; then
      needs_claude_init=true
    fi
  fi

  if [[ "$needs_claude_init" == "true" ]]; then
    log_debug "Claude needs initialization"
    return 1 # Claude needs initialization
  else
    log_debug "Claude appears to be properly initialized"
    return 0 # Claude is ready
  fi
}

# Handle Claude initialization requirement before updates
handle_claude_initialization_requirement() {
  log_warn "Claude Code requires initialization before COMPASS can proceed."
  echo
  cat <<EOF
${YELLOW}⚠️  CLAUDE INITIALIZATION REQUIRED${NC}

COMPASS needs Claude Code to be properly initialized before it can:
• Check for updates
• Start Serena MCP server
• Begin your session

${CYAN}What needs to be done:${NC}
• Claude Code authentication setup (one-time)
• Trust dialog acceptance
• Basic configuration creation

${GREEN}How to proceed:${NC}
1. Exit this script (press Ctrl+C or wait)
2. Run: ${CYAN}claude init${NC}
3. Follow the authentication prompts
4. Accept the trust dialog when prompted
5. Then run ${CYAN}./compass.sh${NC} again

${YELLOW}Important:${NC} Claude must be initialized first to ensure proper setup.
This is a one-time requirement for new installations.
EOF
  echo
  echo "${RED}Exiting...${NC} Please run '${CYAN}claude /init${NC}' first, then restart COMPASS."
  exit 1
}

# Check and perform auto-update
check_and_auto_update() {
  if [[ "$AUTO_UPDATE_DISABLED" == "true" ]]; then
    log_debug "Auto-update disabled, skipping version check"
    return 0
  fi

  if [[ "$AUTO_UPDATE_ENABLED" != "true" ]]; then
    log_debug "Auto-update not enabled, skipping"
    return 0
  fi

  if [[ "$SELF_UPDATE_PERFORMED" == "true" ]]; then
    log_debug "Self-update already performed this session, skipping"
    return 0
  fi

  log_info "Checking for compass.sh updates..."

  # Get latest version from GitHub
  local latest_version
  if ! latest_version=$(get_latest_version); then
    log_warn "Could not check for updates - continuing with current version"
    return 0
  fi

  # Compare with current version
  local comparison_result
  comparison_result=$(compare_versions "$SCRIPT_VERSION" "$latest_version")

  case "$comparison_result" in
  "update_available")
    log_info "Update available: v$SCRIPT_VERSION → v$latest_version"
    perform_auto_update "$latest_version"
    return $?
    ;;
  "current")
    log_debug "Already running latest version: v$SCRIPT_VERSION"
    return 0
    ;;
  "newer")
    log_debug "Running newer version than latest release: v$SCRIPT_VERSION"
    return 0
    ;;
  "error")
    log_warn "Version comparison failed - continuing with current version"
    return 0
    ;;
  *)
    log_warn "Unknown version comparison result: $comparison_result"
    return 0
    ;;
  esac
}

# Perform the actual auto-update and restart
perform_auto_update() {
  local latest_version="$1"
  local script_path="${BASH_SOURCE[0]:-$0}"

  # Resolve script path to absolute path
  script_path=$(readlink -f "$script_path")

  log_info "Performing auto-update to v$latest_version..."

  # Create temporary directory
  local temp_dir
  temp_dir=$(mktemp -d) || {
    log_error "Failed to create temporary directory for update"
    return 1
  }

  # Ensure cleanup on exit
  trap "rm -rf '$temp_dir'" EXIT

  # Download latest script
  local new_script
  if ! new_script=$(download_latest_script "$temp_dir"); then
    log_error "Failed to download latest script"
    return 1
  fi

  # Create backup
  local backup_path
  if ! backup_path=$(create_script_backup "$script_path"); then
    log_error "Failed to create backup - aborting update"
    return 1
  fi

  # Replace script atomically
  if ! replace_script_atomically "$script_path" "$new_script" "$backup_path"; then
    log_error "Failed to replace script - update aborted"
    return 1
  fi

  # Mark update as performed to prevent loops
  SELF_UPDATE_PERFORMED=true

  log_success "Auto-update completed successfully!"
  log_info "Restarting with updated script..."

  # Restart with new version, preserving all original arguments
  exec "$script_path" "$@"
}

#=============================================================================
# End Auto-Update System Functions
#=============================================================================

# Print unified banner
print_banner() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              COMPASS Unified Setup v${SCRIPT_VERSION}"
  echo "║        Self-Updating + Memory-Optimized Launcher             ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# Detect operating system
detect_os() {
  case "$OSTYPE" in
  "linux-gnu"*) echo "linux" ;;
  "darwin"*) echo "macos" ;;
  "cygwin" | "msys" | "win32") echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

# Cross-platform memory detection
get_system_memory_mb() {
  local total_memory_mb=0
  local os_type
  os_type=$(detect_os)

  log_debug "Detecting system memory on ${os_type}..."

  case "$os_type" in
  "linux")
    if [[ -r "/proc/meminfo" ]]; then
      local memory_kb
      memory_kb=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
      if [[ -n "$memory_kb" && "$memory_kb" =~ ^[0-9]+$ ]]; then
        total_memory_mb=$((memory_kb / 1024))
        log_debug "Linux memory detection: ${total_memory_mb}MB"
      fi
    fi
    ;;
  "macos")
    if command -v sysctl >/dev/null 2>&1; then
      local memory_bytes
      memory_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
      if [[ -n "$memory_bytes" && "$memory_bytes" =~ ^[0-9]+$ ]] && ((memory_bytes > 0)); then
        total_memory_mb=$((memory_bytes / 1024 / 1024))
        log_debug "macOS memory detection: ${total_memory_mb}MB"
      fi
    fi
    ;;
  "windows")
    if command -v powershell.exe >/dev/null 2>&1; then
      local memory_bytes
      memory_bytes=$(powershell.exe -NoProfile -Command "(Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory" 2>/dev/null | tr -d '\r' || echo "0")
      if [[ -n "$memory_bytes" && "$memory_bytes" =~ ^[0-9]+$ ]] && ((memory_bytes > 0)); then
        total_memory_mb=$((memory_bytes / 1024 / 1024))
        log_debug "Windows memory detection: ${total_memory_mb}MB"
      fi
    fi
    ;;
  esac

  # Fallback: try 'free' command (Linux/WSL)
  if ((total_memory_mb == 0)) && command -v free >/dev/null 2>&1; then
    local memory_kb
    memory_kb=$(free -k | awk '/^Mem:/ {print $2}' 2>/dev/null || echo "0")
    if [[ -n "$memory_kb" && "$memory_kb" =~ ^[0-9]+$ ]] && ((memory_kb > 0)); then
      total_memory_mb=$((memory_kb / 1024))
      log_debug "Fallback memory detection: ${total_memory_mb}MB"
    fi
  fi

  echo "$total_memory_mb"
}

# Calculate optimal memory allocation
calculate_memory_allocation() {
  local system_memory_mb="$1"
  local allocated_memory_mb

  if ((system_memory_mb == 0)); then
    log_warn "Could not detect system memory, using default: ${DEFAULT_MEMORY_MB}MB"
    allocated_memory_mb=$DEFAULT_MEMORY_MB
  else
    # Calculate 50% allocation
    allocated_memory_mb=$(((system_memory_mb * DEFAULT_MEMORY_PERCENTAGE) / 100))

    # Apply bounds checking
    if ((allocated_memory_mb < MIN_MEMORY_MB)); then
      log_warn "Calculated memory (${allocated_memory_mb}MB) below minimum, using ${MIN_MEMORY_MB}MB"
      allocated_memory_mb=$MIN_MEMORY_MB
    elif ((allocated_memory_mb > MAX_MEMORY_MB)); then
      log_warn "Calculated memory (${allocated_memory_mb}MB) above maximum, using ${MAX_MEMORY_MB}MB"
      allocated_memory_mb=$MAX_MEMORY_MB
    fi

    log_info "System Memory: ${system_memory_mb}MB → Allocating: ${allocated_memory_mb}MB (${DEFAULT_MEMORY_PERCENTAGE}%)"
  fi

  echo "$allocated_memory_mb"
}

# Validate dependencies
validate_dependencies() {
  log_info "Validating system dependencies..."

  local missing_deps=()

  # Core dependencies
  command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
  command -v python3 >/dev/null 2>&1 || missing_deps+=("python3")

  # Check uvx availability
  if ! command -v uvx >/dev/null 2>&1; then
    log_warn "uvx not found, attempting installation..."
    if command -v pip >/dev/null 2>&1; then
      pip install uvx || missing_deps+=("uvx (installation failed)")
    elif command -v pipx >/dev/null 2>&1; then
      pipx install uvx || missing_deps+=("uvx (installation failed)")
    else
      missing_deps+=("uvx (pip/pipx not available)")
    fi
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_info "Please install missing dependencies and run setup again"
    exit 1
  fi

  # Validate Python JSON module
  if ! python3 -c "import json" 2>/dev/null; then
    log_error "Python json module not available"
    exit 1
  fi

  # Check for Python packaging module (for version comparison)
  if ! python3 -c "import packaging.version" 2>/dev/null; then
    log_debug "Python packaging module not available, will use fallback version comparison"
  fi

  log_success "All dependencies validated"
}

# Setup directory structure
setup_directories() {
  log_info "Setting up COMPASS directory structure..."

  # Core COMPASS directories
  mkdir -p .claude/agents
  mkdir -p .compass/handlers
  mkdir -p docs
  mkdir -p maps

  log_success "Directory structure ready"
}

# Update COMPASS components from repository
update_compass_components() {
  if [[ "$UPDATE_PERFORMED" == "true" ]]; then
    log_debug "Update already performed, skipping"
    return 0
  fi

  log_info "Updating COMPASS components from repository..."

  local temp_dir
  temp_dir=$(mktemp -d)

  # Download and extract latest COMPASS
  if curl -fsSL "${REPO_URL}/archive/${BRANCH}.tar.gz" | tar -xz -C "$temp_dir" --strip-components=1; then
    log_success "Downloaded latest COMPASS components"

    # Copy agents
    if [[ -d "$temp_dir/.claude/agents" ]]; then
      cp -r "$temp_dir/.claude/agents/." .claude/agents/
      log_info "Updated COMPASS agents"
    fi

    # Copy handlers
    if [[ -d "$temp_dir/.compass/handlers" ]]; then
      cp -r "$temp_dir/.compass/handlers/." .compass/handlers/
      log_info "Updated COMPASS handlers"
    fi

    # Copy documentation and maps
    if [[ -d "$temp_dir/docs" ]]; then
      cp -r "$temp_dir/docs/." docs/
      log_info "Updated documentation"
    fi

    if [[ -d "$temp_dir/maps" ]]; then
      cp -r "$temp_dir/maps/." maps/
      log_info "Updated pattern maps"
    fi

    UPDATE_PERFORMED=true
    log_success "COMPASS components updated successfully"
  else
    log_error "Failed to download COMPASS components"
    exit 1
  fi

  # Cleanup
  rm -rf "$temp_dir"
}

# Configure Claude settings with COMPASS integration
configure_claude_settings() {
  log_info "Configuring Claude with COMPASS integration..."

  local config_file="$HOME/.claude/settings.json"
  local config_dir
  config_dir="$(dirname "$config_file")"

  # Ensure .claude directory exists
  mkdir -p "$config_dir"

  # Create or update settings.json
  python3 <<EOF
import json
import os

config_path = "$config_file"
config = {}

# Load existing configuration
if os.path.exists(config_path):
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError:
        print("Warning: Invalid JSON in settings file, creating new configuration")
        config = {}

# Configure hooks for COMPASS
if 'hooks' not in config:
    config['hooks'] = {}

config['hooks']['PreToolUse'] = [
    {
        'description': 'COMPASS methodology enforcement with unified setup integration',
        'script': os.path.abspath('.compass/handlers/compass-handler.py')
    }
]

config['hooks']['UserPromptSubmit'] = [
    {
        'matcher': '*',
        'hooks': [
            {
                'type': 'command',
                'command': os.path.abspath('.compass/handlers/compass-handler.py'),
                'timeout': 30000
            }
        ]
    }
]

# Add unified setup configuration
config['compass_unified'] = {
    'enabled': True,
    'version': '$SCRIPT_VERSION',
    'auto_update': True,
    'memory_optimization': True,
    'memory_allocation_mb': $MEMORY_MB,
    'uvx_integration': True,
    'last_update': '$(date -Iseconds)'
}

# Write updated configuration
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("COMPASS integration configured successfully")
EOF

  log_success "Claude configured with COMPASS integration"
}

# Check if Claude Code is initialized
check_claude_initialization() {
  log_info "Checking Claude Code initialization status..."

  local claude_config_dir="$HOME/.claude"
  local credentials_file="$claude_config_dir/.credentials.json"
  local settings_file="$claude_config_dir/settings.json"
  local needs_initialization=false

  # Check if Claude config directory exists
  if [[ ! -d "$claude_config_dir" ]]; then
    log_info "Claude config directory not found, initialization needed"
    needs_initialization=true
  fi

  # Check if credentials exist
  if [[ ! -f "$credentials_file" ]]; then
    log_info "Claude credentials not found, authentication setup needed"
    needs_initialization=true
  fi

  # Check configuration flags via claude config
  local trust_accepted=false
  local onboarding_complete=false

  if command -v claude >/dev/null 2>&1; then
    # Check trust dialog status
    if claude config get hasTrustDialogAccepted 2>/dev/null | grep -q "true"; then
      trust_accepted=true
    fi

    # Check project onboarding status
    if claude config get hasCompletedProjectOnboarding 2>/dev/null | grep -q "true"; then
      onboarding_complete=true
    fi
  fi

  if [[ "$needs_initialization" == "true" ]]; then
    log_warn "Claude Code requires initialization"
    return 1
  elif [[ "$trust_accepted" == "false" ]]; then
    log_warn "Claude Code trust dialog needs acceptance"
    return 1
  elif [[ "$onboarding_complete" == "false" ]]; then
    log_warn "Claude Code project onboarding incomplete"
    return 1
  else
    log_success "Claude Code is properly initialized"
    return 0
  fi
}

# Initialize Claude Code if needed
initialize_claude_code() {
  log_info "Initializing Claude Code for first-time setup..."

  # Ensure Claude config directory exists
  mkdir -p "$HOME/.claude"

  # Check if we need authentication setup
  if [[ ! -f "$HOME/.claude/.credentials.json" ]]; then
    log_info "Setting up Claude Code authentication..."
    log_info "You will need to authenticate with your Claude account"
    echo

    # Guide user through authentication
    cat <<EOF
${YELLOW}CLAUDE AUTHENTICATION REQUIRED${NC}

Claude Code needs to authenticate with your Claude account.
This is a one-time setup process.

${CYAN}Choose your authentication method:${NC}
1. setup-token - Set up a long-lived token (requires Claude subscription)
2. Interactive login - Login interactively during first Claude session

${GREEN}Recommendation:${NC} If you have a Claude subscription, use setup-token for the best experience.
EOF
    echo
    read -p "Would you like to run 'claude setup-token' now? (y/N): " -r setup_token_response

    if [[ $setup_token_response =~ ^[Yy]$ ]]; then
      log_info "Running Claude token setup..."
      if claude setup-token; then
        log_success "Claude authentication configured successfully"
      else
        log_warn "Token setup failed or was cancelled, will proceed with interactive login"
        log_info "You'll be prompted to authenticate when Claude starts"
      fi
    else
      log_info "Skipping token setup - you'll authenticate interactively when Claude starts"
    fi
  fi

  # Create basic settings.json if it doesn't exist
  local settings_file="$HOME/.claude/settings.json"
  if [[ ! -f "$settings_file" ]]; then
    log_info "Creating basic Claude settings configuration..."
    cat >"$settings_file" <<'EOF'
{
  "model": "sonnet"
}
EOF
    log_success "Basic Claude settings created"
  fi

  log_success "Claude Code initialization complete"
}

# Install or update Claude Code using uvx
install_update_claude_code() {
  log_info "Installing/updating Claude Code via uvx..."

  # Check if uvx is working
  if ! uvx --help >/dev/null 2>&1; then
    log_error "uvx is not functioning properly"
    exit 1
  fi

  # Install/update claude-code package
  log_info "Setting up Claude Code with uvx..."

  # Install Claude Code globally via npm
  log_info "Installing Claude Code globally via npm..."
  if npm i -g @anthropic-ai/claude-code 2>/dev/null; then
    log_success "Claude Code installed/updated via npm"
  else
    log_warn "npm global installation failed or already up-to-date"
  fi

  # Verify Claude Code is available via uvx
  if claude --version >/dev/null 2>&1; then
    log_success "Claude Code is available via uvx"
  else
    log_warn "Claude Code package verification failed, but will attempt execution"
  fi

  # Check if Claude Code is initialized
  if ! check_claude_initialization; then
    initialize_claude_code
  fi

  log_success "uvx Claude Code setup complete"
}

# Launch Claude Code with memory optimization
launch_claude_with_memory() {
  local memory_mb="$1"
  shift
  local args=("$@")

  log_info "Launching Claude Code with ${memory_mb}MB memory allocation..."

  log_info "Memory optimization: NODE_OPTIONS=--max-old-space-size=${memory_mb}"
  log_success "Starting Claude Code with unified COMPASS setup..."

  # Enhanced process isolation before exec
  # Wait longer for complete background process isolation
  sleep 2

  # Clear all signal handlers before exec to prevent inheritance issues
  trap - INT TERM EXIT HUP QUIT

  # Complete process cleanup and isolation
  {
    # Close all non-standard file descriptors
    for fd in {3..255}; do
      exec {fd}>&- 2>/dev/null || true
    done

    # Ensure process group isolation
    setsid 2>/dev/null || true

    # Final background process check
    jobs -p | xargs -r kill -0 2>/dev/null || true

  } 2>/dev/null || true

  log_debug "Process isolation complete, launching Claude..."

  # Export memory optimization for child process
  export NODE_OPTIONS="--max-old-space-size=${memory_mb}"

  # Launch Claude Code using uvx with all arguments
  # If no arguments provided, ensure interactive mode
  if [[ ${#args[@]} -eq 0 ]]; then
    log_debug "No arguments provided, launching Claude in interactive mode"
    exec claude
  else
    log_debug "Launching Claude with arguments: ${args[*]}"
    exec claude "${args[@]}"
  fi
}

# Show usage information
show_usage() {
  cat <<EOF
COMPASS Unified Setup Script v${SCRIPT_VERSION}

DESCRIPTION:
    This script does everything in one operation:
    - Updates COMPASS components from repository
    - Configures memory optimization automatically  
    - Installs/updates Claude Code via uvx
    - Integrates Serena MCP server automatically
    - Handles Claude Code initialization automatically (first-time setup)
    - Launches Claude with optimal settings

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --resume                Resume previous Claude session (passes --resume to Claude)
    --help                  Show this help message
    --debug                 Enable debug output and disable auto-update
    --version               Show version information
    --disable-serena        Disable Serena MCP server integration
    --no-auto-update        Disable automatic script updates
    --cleanup-serena        Run Serena MCP server cleanup and exit (internal use)

EXAMPLES:
    $0                    # Update COMPASS and start Claude with memory optimization
    $0 --resume          # Update COMPASS and resume Claude session
    $0 --debug           # Run with debug output enabled

MEMORY OPTIMIZATION:
    - Automatically detects system memory
    - Allocates 50% of system RAM to Claude (capped at 15GB)
    - Cross-platform support (Linux, macOS, Windows)
    - Minimum allocation: ${MIN_MEMORY_MB}MB
    - Maximum allocation: ${MAX_MEMORY_MB}MB

CLAUDE CODE INITIALIZATION:
    For new users, compass.sh automatically handles Claude Code setup:
    - Detects if Claude Code has been configured
    - Creates necessary configuration directories
    - Guides through authentication options:
      * Long-lived token setup (requires Claude subscription)
      * Interactive login (free option)
    - Creates basic settings configuration
    - No manual 'claude init' command needed

SERENA MCP INTEGRATION:
    - Automatically starts Serena MCP server on available port (default: 9121)
    - Registers Serena server with Claude MCP system
    - Provides advanced code analysis capabilities
    - Monitors server health and recovers automatically
    - Integrates seamlessly with existing COMPASS workflow
    - Disable with: SERENA_INTEGRATION_DISABLED=true or --disable-serena

AUTO-UPDATE SYSTEM:
    - Automatically checks for script updates on GitHub before each execution
    - Downloads and installs latest version if available
    - Creates backup of current version before replacement
    - Atomic replacement ensures no corruption during update
    - Self-restarts with preserved arguments after successful update
    - --debug flag disables auto-update for development safety
    - --no-auto-update flag permanently disables updates for current run

ENHANCED BOOTSTRAP WORKFLOW:
    Every execution automatically follows this optimized sequence:
    1. Checks if Claude Code command exists (installs if needed)
    2. Installs/updates Claude Code via npm/uvx 
    3. Starts Serena MCP server BEFORE Claude initialization (SUPERPOWERS!)
    4. Checks Claude initialization status
       - If not initialized: Prompts for 'claude init' with Serena already running
       - User gets enhanced initialization experience with advanced capabilities
    5. Updates COMPASS components from repository (after Claude ready)
    6. Configures memory optimization
    7. Completes Serena MCP server integration (registration with Claude)
    8. Launches Claude with optimal settings and full MCP integration

KEY INNOVATION - SERENA FIRST:
    ✨ Serena MCP server starts BEFORE 'claude init'
    ✨ Users get advanced code analysis during initial setup
    ✨ Enhanced capabilities available from first session
    ✨ No need to restart after adding Serena later

FIRST-TIME USERS:
    The script provides an enhanced initialization experience:
    - Installs Claude Code automatically if not present
    - Starts Serena MCP server before prompting for 'claude init'
    - Shows whether Serena superpowers are available during setup
    - Guides through authentication with enhanced capabilities ready
    - Completes all integrations automatically after 'claude init'
    - No manual MCP server setup required
EOF
}

# Show version information
show_version() {
  echo "COMPASS Unified Setup v${SCRIPT_VERSION}"
  echo "OS: $(detect_os)"
  echo "Memory Detection: $(get_system_memory_mb)MB"
  if command -v uvx >/dev/null 2>&1; then
    echo "uvx: $(uvx --version 2>/dev/null || echo 'available')"
  else
    echo "uvx: not found"
  fi
  echo "Repository: $REPO_URL"
}

# Main execution function
main() {
  local resume_session=false
  local claude_needs_init=false
  local claude_needs_install=false

  # Phase 0: Early flag parsing for auto-update control
  parse_early_debug_flag "$@"

  # Phase 0.1: Check if Claude command exists at all
  if ! command -v claude >/dev/null 2>&1; then
    log_info "Claude Code not installed - will install before initialization"
    claude_needs_install=true
    claude_needs_init=true
  else
    # Phase 0.2: Check if Claude needs initialization (command exists but not initialized)
    if ! early_check_claude_initialization; then
      claude_needs_init=true
    fi
  fi

  # Phase 0.3: Skip auto-update if Claude needs installation or init
  # (We want to get Claude working first before updating COMPASS)
  if [[ "$claude_needs_install" == "true" ]] || [[ "$claude_needs_init" == "true" ]]; then
    log_info "Deferring COMPASS auto-update until after Claude setup"
    AUTO_UPDATE_DISABLED=true
  fi

  # Phase 0.4: Check and perform auto-update (unless disabled)
  if [[ "$AUTO_UPDATE_DISABLED" != "true" ]] && [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
    if ! check_and_auto_update "$@"; then
      log_warn "Auto-update failed, continuing with current version"
    fi
  fi

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    --resume)
      resume_session=true
      CLAUDE_ARGS+=(--resume)
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    --debug)
      export DEBUG=1
      shift
      ;;
    --disable-serena)
      export SERENA_INTEGRATION_DISABLED=true
      shift
      ;;
    --no-auto-update)
      # Already handled in early parsing, just consume the flag
      shift
      ;;
    --cleanup-serena)
      # Internal flag for Serena cleanup - used by timeout subprocess
      # This ensures function availability in subprocess context
      log_info "Running Serena MCP server cleanup via flag..."

      # Set up minimal environment for cleanup
      export DEBUG="${DEBUG:-0}"

      # Execute cleanup with comprehensive error handling
      local cleanup_success=false
      if failsafe_cleanup_serena_processes 2>/dev/null; then
        cleanup_success=true
        log_success "Serena cleanup completed successfully"
      else
        log_warn "Standard cleanup failed, attempting direct process cleanup"
        # Direct cleanup as last resort
        pkill -f "serena start-mcp-server" 2>/dev/null || true
        pkill -f "uvx.*serena" 2>/dev/null || true
        lsof -ti ":${SERENA_DEFAULT_PORT}" 2>/dev/null | xargs -r kill -TERM 2>/dev/null || true
        sleep 1
        lsof -ti ":${SERENA_DEFAULT_PORT}" 2>/dev/null | xargs -r kill -KILL 2>/dev/null || true
        rm -f .compass/serena-*.pid 2>/dev/null || true
        cleanup_success=true
        log_info "Direct cleanup completed"
      fi

      if [[ "$cleanup_success" == "true" ]]; then
        exit 0
      else
        log_error "All cleanup methods failed"
        exit 1
      fi
      ;;
    --version)
      show_version
      exit 0
      ;;
    *)
      # Pass any other arguments to Claude
      CLAUDE_ARGS+=("$1")
      shift
      ;;
    esac
  done

  # Print banner
  print_banner

  if [[ "$resume_session" == "true" ]]; then
    log_info "Resume mode: Will restore previous Claude session"
  fi

  # Phase 1: Foundation Setup
  log_info "Phase 1: Foundation Setup"
  validate_dependencies
  setup_directories

  # Phase 2: Claude Code Installation (if needed)
  if [[ "$claude_needs_install" == "true" ]]; then
    log_info "Phase 2: Claude Code Installation"
    install_update_claude_code
  else
    log_info "Phase 2: Claude Code already installed, updating if needed"
    install_update_claude_code
  fi

  # Phase 3: Serena MCP Server Pre-initialization (superpowers for init!)
  log_info "Phase 3: Serena MCP Server Pre-initialization"
  if start_serena_mcp_server_only; then
    log_success "Serena MCP server ready - Claude init will have enhanced capabilities"
  else
    log_info "Continuing without Serena pre-initialization"
  fi

  # Phase 4: Claude Initialization Check and Prompt
  if [[ "$claude_needs_init" == "true" ]]; then
    log_info "Phase 4: Claude Code Initialization Required"

    # Show enhanced initialization message with Serena info
    log_warn "Claude Code requires initialization to proceed with COMPASS setup."
    echo

    # Use echo with proper variable expansion instead of cat heredoc
    echo -e "${YELLOW}⚠️  CLAUDE INITIALIZATION REQUIRED${NC}"
    echo
    echo "COMPASS needs Claude Code to be properly initialized before continuing."
    echo
    echo -e "${CYAN}Enhanced Setup Available:${NC}"
    if [[ "$SERENA_PORT" -gt 0 ]]; then
      echo "✅ Serena MCP server is running on port $SERENA_PORT"
      echo "   Your initialization will have advanced code analysis capabilities!"
    else
      echo "ℹ️  Serena MCP server could not be started"
      echo "   Standard initialization will proceed"
    fi
    echo
    echo -e "${GREEN}Required Steps:${NC}"
    echo -e "1. Run: ${CYAN}claude init${NC}"
    echo "2. Follow authentication prompts"
    echo "3. Accept trust dialog when prompted"
    echo -e "4. Then restart COMPASS with: ${CYAN}./compass.sh${NC}"
    echo
    echo -e "${YELLOW}After initialization:${NC}"
    echo "• COMPASS will auto-update components"
    echo "• Serena integration will complete automatically"
    echo "• Memory optimization will be applied"
    echo "• Full enhanced workflow will be available"
    echo
    echo -e "${RED}Please run '${CYAN}claude init${NC}${RED}' first, then restart COMPASS.${NC}"
    exit 1
  else
    log_success "Claude Code is properly initialized"
  fi

  # Phase 5: Update COMPASS Components (now that Claude is ready)
  log_info "Phase 5: Auto-Update COMPASS Components"
  update_compass_components

  # Phase 6: Memory Optimization Configuration
  log_info "Phase 6: Memory Optimization Configuration"
  local system_memory_mb
  system_memory_mb=$(get_system_memory_mb)
  MEMORY_MB=$(calculate_memory_allocation "$system_memory_mb")

  # Phase 7: Claude Configuration
  log_info "Phase 7: Claude Configuration"
  configure_claude_settings

  # Phase 8: Complete Serena MCP Server Integration
  log_info "Phase 8: Complete Serena MCP Server Integration"

  if complete_serena_mcp_integration; then
    log_success "Serena MCP server integration completed successfully"
  else
    local exit_code=$?
    log_warn "Serena MCP server integration completion failed - server may still be running"

    # Fallback cleanup for critical cases
    local script_path="${BASH_SOURCE[0]:-$0}"
    if [[ -f "$script_path" ]] && timeout 10 "$script_path" --cleanup-serena 2>/dev/null; then
      log_debug "Serena cleanup via flag completed successfully"
    else
      log_warn "Flag-based cleanup failed, using fallback cleanup"
      pkill -f "serena start-mcp-server" 2>/dev/null || true
      pkill -f "uvx.*serena" 2>/dev/null || true
      rm -f .compass/*.pid 2>/dev/null || true
      lsof -ti ":${SERENA_DEFAULT_PORT}" 2>/dev/null | xargs -r kill -TERM 2>/dev/null || true
    fi
  fi

  # Phase 9: Launch Preparation Complete
  log_info "Phase 9: Launch Preparation Complete"
  echo
  log_success "COMPASS Unified Setup Complete!"

  # Display integration status with comprehensive error suppression
  {
    local integration_status
    integration_status=$(check_serena_integration_status 2>/dev/null) || integration_status="Serena MCP integration: Initializing"
    echo "$integration_status"
  } 2>/dev/null || {
    log_info "Serena MCP integration: Status check unavailable"
  }

  log_info "Launching Claude Code with unified configuration..."
  echo

  # Launch Claude with memory optimization and all arguments
  launch_claude_with_memory "$MEMORY_MB" "${CLAUDE_ARGS[@]}"
}

# Execute main function with all arguments
main "$@"
