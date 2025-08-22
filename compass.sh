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
readonly SERENA_STARTUP_TIMEOUT=10
readonly SERENA_HEALTH_CHECK_TIMEOUT=5
readonly SERENA_MONITOR_INTERVAL=30
readonly SERENA_MAX_RETRIES=3

# Global state for Serena integration
SERENA_PORT=0
SERENA_PID=0
SERENA_MONITOR_PID=0
SERENA_INTEGRATION_ENABLED=false

# Script configuration
readonly SCRIPT_VERSION="2.1.0-serena-integrated"
readonly REPO_URL="https://github.com/odysseyalive/claude-compass"
readonly BRANCH="main"
readonly DEFAULT_MEMORY_PERCENTAGE=50
readonly MIN_MEMORY_MB=512
readonly MAX_MEMORY_MB=15360  # 15GB maximum for stability
readonly DEFAULT_MEMORY_MB=4096

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global state
UPDATE_PERFORMED=false
MEMORY_MB=0
CLAUDE_ARGS=()

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
    
    for ((i=0; i<max_attempts; i++)); do
        # Check if port is available using multiple methods
        if ! ss -tuln 2>/dev/null | grep -q ":${current_port} " && \
           ! netstat -tuln 2>/dev/null | grep -q ":${current_port} " && \
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

# Check if Serena MCP server is healthy using port connectivity
check_serena_server_health() {
    local port="$1"
    
    # Use multiple methods to check if port is responding
    # Method 1: bash TCP check
    if timeout "$SERENA_HEALTH_CHECK_TIMEOUT" bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        return 0
    fi
    
    # Method 2: netcat if available
    if command -v nc >/dev/null 2>&1 && timeout "$SERENA_HEALTH_CHECK_TIMEOUT" nc -z localhost "$port" 2>/dev/null; then
        return 0
    fi
    
    # Method 3: telnet if available
    if command -v telnet >/dev/null 2>&1; then
        if timeout "$SERENA_HEALTH_CHECK_TIMEOUT" bash -c "echo quit | telnet localhost $port" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Method 4: curl if available (though Serena may not have HTTP endpoint)
    if command -v curl >/dev/null 2>&1; then
        if timeout "$SERENA_HEALTH_CHECK_TIMEOUT" curl -s "http://localhost:$port/" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Start Serena MCP server with memory limits and logging
start_serena_mcp_server() {
    local port="$1"
    local log_file=".compass/logs/serena-mcp-server.log"
    local pid_file=".compass/serena-mcp-server.pid"
    
    log_info "Starting Serena MCP server on port ${port}..."
    
    # Ensure log and state directories exist
    mkdir -p "$(dirname "$log_file")"
    mkdir -p .compass
    
    # Clean up any existing server first
    cleanup_serena_server >/dev/null 2>&1
    
    # Start server in background with logging
    {
        uvx --from git+https://github.com/oraios/serena \
            serena start-mcp-server \
            --transport sse \
            --port "$port" \
            --context ide-assistant 2>&1 | \
        while IFS= read -r line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [SERENA] $line"
        done
    } >"$log_file" &
    
    local server_pid=$!
    echo "$server_pid" > "$pid_file"
    SERENA_PID="$server_pid"
    
    log_debug "Serena MCP server started with PID: $server_pid"
    
    # Health check with timeout
    local max_wait="$SERENA_STARTUP_TIMEOUT"
    local wait_time=0
    
    log_info "Waiting for Serena MCP server to become healthy..."
    while (( wait_time < max_wait )); do
        if check_serena_server_health "$port"; then
            log_success "Serena MCP server healthy on port $port"
            SERENA_PORT="$port"
            cache_serena_state "$port" "$server_pid"
            return 0
        fi
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    log_error "Serena MCP server failed to start within ${max_wait} seconds"
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
    
    # Store monitor PID
    echo $$ > "$pid_file"
    SERENA_MONITOR_PID=$$
    
    # Log function for monitor (writes to file instead of terminal)
    monitor_log() {
        local level="$1"
        shift
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$monitor_log"
    }
    
    monitor_log "INFO" "Starting Serena MCP server health monitoring (PID: $$)"
    
    while true; do
        if ! check_serena_server_health "$port"; then
            monitor_log "WARN" "Serena MCP server unhealthy, attempting recovery..."
            
            if attempt_serena_recovery "true"; then
                monitor_log "SUCCESS" "Serena MCP server recovered successfully"
            else
                monitor_log "ERROR" "Serena MCP server recovery failed - stopping monitoring"
                break
            fi
        else
            monitor_log "DEBUG" "Serena MCP server health check passed"
            update_serena_metrics "$port"
        fi
        
        sleep "$SERENA_MONITOR_INTERVAL"
    done
    
    # Clean up monitor PID file
    rm -f "$pid_file"
    monitor_log "INFO" "Serena MCP server monitoring stopped"
}

# Attempt to recover Serena MCP server
attempt_serena_recovery() {
    local silent_mode="${1:-false}"  # Optional parameter for silent logging
    local retry_count=0
    local recovery_delay=10
    
    while (( retry_count < SERENA_MAX_RETRIES )); do
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
                if start_serena_mcp_server "$serena_port" >/dev/null 2>&1; then
                    if register_serena_with_claude "$serena_port" >/dev/null 2>&1; then
                        monitor_log "SUCCESS" "Serena MCP server recovery successful"
                        return 0
                    fi
                fi
            fi
        else
            # Normal mode with regular logging
            if serena_port=$(find_available_port "$SERENA_DEFAULT_PORT"); then
                if start_serena_mcp_server "$serena_port"; then
                    if register_serena_with_claude "$serena_port"; then
                        log_success "Serena MCP server recovery successful"
                        return 0
                    fi
                fi
            fi
        fi
        
        retry_count=$((retry_count + 1))
        recovery_delay=$((recovery_delay * 2))  # Exponential backoff
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
        sleep 2  # Give Claude time to update
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
    python3 << EOF
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
    
    cat > "$cache_dir/server-state.json" << EOF
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
    } >> "$metrics_file"
}

# Clean up Serena MCP server processes and state
cleanup_serena_server() {
    local silent_mode="${1:-false}"  # Optional parameter for silent operation
    
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
            while kill -0 "$server_pid" 2>/dev/null && (( wait_count < 10 )); do
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

# Main function to integrate Serena MCP server with COMPASS
integrate_serena_mcp_server() {
    log_info "Initializing Serena MCP server integration..."
    
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
    if ! start_serena_mcp_server "$serena_port"; then
        log_warn "Serena MCP server startup failed - continuing without Serena integration"
        return 1
    fi
    
    # Configure Claude settings
    if ! configure_serena_mcp_settings "$serena_port"; then
        log_warn "Serena MCP settings configuration failed - server running but not optimally configured"
    fi
    
    # Register with Claude
    if ! register_serena_with_claude "$serena_port"; then
        log_warn "Claude MCP registration failed - Serena server running but not integrated with Claude"
    fi
    
    # Start background health monitoring with all output redirected to log files
    monitor_serena_server "$serena_port" >/dev/null 2>&1 &
    SERENA_MONITOR_PID=$!
    echo "$SERENA_MONITOR_PID" > .compass/serena-monitor.pid
    
    # Mark integration as successful
    SERENA_INTEGRATION_ENABLED=true
    
    log_success "Serena MCP server integration complete (Port: $serena_port, PID: $SERENA_PID)"
    return 0
}

# Function to check Serena integration status
check_serena_integration_status() {
    if [[ "$SERENA_INTEGRATION_ENABLED" == "true" ]] && \
       [[ "$SERENA_PORT" -gt 0 ]] && \
       check_serena_server_health "$SERENA_PORT"; then
        echo "Serena MCP integration: Active (Port: $SERENA_PORT)"
        return 0
    else
        echo "Serena MCP integration: Inactive"
        return 1
    fi
}

#=============================================================================
# End Serena MCP Integration Functions
#=============================================================================

# Print unified banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              COMPASS Unified Setup v${SCRIPT_VERSION}              ║"
    echo "║           Auto-Update + Memory-Optimized Launcher           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Detect operating system
detect_os() {
    case "$OSTYPE" in
        "linux-gnu"*) echo "linux" ;;
        "darwin"*) echo "macos" ;;
        "cygwin"|"msys"|"win32") echo "windows" ;;
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
                if [[ -n "$memory_bytes" && "$memory_bytes" =~ ^[0-9]+$ ]] && (( memory_bytes > 0 )); then
                    total_memory_mb=$((memory_bytes / 1024 / 1024))
                    log_debug "macOS memory detection: ${total_memory_mb}MB"
                fi
            fi
            ;;
        "windows")
            if command -v powershell.exe >/dev/null 2>&1; then
                local memory_bytes
                memory_bytes=$(powershell.exe -NoProfile -Command "(Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory" 2>/dev/null | tr -d '\r' || echo "0")
                if [[ -n "$memory_bytes" && "$memory_bytes" =~ ^[0-9]+$ ]] && (( memory_bytes > 0 )); then
                    total_memory_mb=$((memory_bytes / 1024 / 1024))
                    log_debug "Windows memory detection: ${total_memory_mb}MB"
                fi
            fi
            ;;
    esac
    
    # Fallback: try 'free' command (Linux/WSL)
    if (( total_memory_mb == 0 )) && command -v free >/dev/null 2>&1; then
        local memory_kb
        memory_kb=$(free -k | awk '/^Mem:/ {print $2}' 2>/dev/null || echo "0")
        if [[ -n "$memory_kb" && "$memory_kb" =~ ^[0-9]+$ ]] && (( memory_kb > 0 )); then
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
    
    if (( system_memory_mb == 0 )); then
        log_warn "Could not detect system memory, using default: ${DEFAULT_MEMORY_MB}MB"
        allocated_memory_mb=$DEFAULT_MEMORY_MB
    else
        # Calculate 50% allocation
        allocated_memory_mb=$(( (system_memory_mb * DEFAULT_MEMORY_PERCENTAGE) / 100 ))
        
        # Apply bounds checking
        if (( allocated_memory_mb < MIN_MEMORY_MB )); then
            log_warn "Calculated memory (${allocated_memory_mb}MB) below minimum, using ${MIN_MEMORY_MB}MB"
            allocated_memory_mb=$MIN_MEMORY_MB
        elif (( allocated_memory_mb > MAX_MEMORY_MB )); then
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
    python3 << EOF
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

# Configure PreToolUse hooks for COMPASS
if 'hooks' not in config:
    config['hooks'] = {}

config['hooks']['PreToolUse'] = [
    {
        'description': 'COMPASS methodology enforcement with unified setup integration',
        'script': os.path.abspath('.compass/handlers/compass-handler.py')
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
        cat << EOF
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
        cat > "$settings_file" << 'EOF'
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
    
    # Set Node.js memory options
    export NODE_OPTIONS="--max-old-space-size=${memory_mb}"
    
    log_info "Memory optimization: NODE_OPTIONS=$NODE_OPTIONS"
    log_success "Starting Claude Code with unified COMPASS setup..."
    
    # Clear signal handlers before exec to prevent inheritance issues
    trap - INT TERM EXIT
    
    # Launch Claude Code using uvx with all arguments
    exec claude "${args[@]}"
}

# Show usage information
show_usage() {
    cat << EOF
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
    --debug                 Enable debug output
    --version               Show version information
    --disable-serena        Disable Serena MCP server integration

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

SIMPLIFIED WORKFLOW:
    Every execution automatically:
    1. Updates COMPASS components from repository
    2. Configures memory optimization  
    3. Installs/updates Claude Code via uvx
    4. Starts and registers Serena MCP server (if available)
    5. Handles Claude Code initialization (if needed)
       - Checks for existing Claude configuration
       - Guides through authentication setup
       - Creates basic settings configuration
    6. Launches Claude with optimal settings and MCP integration
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
    
    # Phase 2: Always Update COMPASS
    log_info "Phase 2: Auto-Update COMPASS Components"
    update_compass_components
    
    # Phase 3: Memory Optimization Configuration
    log_info "Phase 3: Memory Optimization Configuration"
    local system_memory_mb
    system_memory_mb=$(get_system_memory_mb)
    MEMORY_MB=$(calculate_memory_allocation "$system_memory_mb")
    
    # Phase 4: Claude Code Integration & Initialization
    log_info "Phase 4: Claude Code Integration & Initialization"
    configure_claude_settings
    install_update_claude_code
    
    # Phase 4.5: Serena MCP Server Integration
    log_info "Phase 4.5: Serena MCP Server Integration"
    if integrate_serena_mcp_server; then
        log_success "Serena MCP server integration completed successfully"
    else
        log_warn "Serena MCP server integration failed - COMPASS will function without Serena MCP capabilities"
    fi
    
    # Phase 5: Launch
    log_info "Phase 5: Launch Preparation Complete"
    echo
    log_success "COMPASS Unified Setup Complete!"
    
    # Display integration status
    check_serena_integration_status
    
    log_info "Launching Claude Code with unified configuration..."
    echo
    
    # Launch Claude with memory optimization and all arguments
    launch_claude_with_memory "$MEMORY_MB" "${CLAUDE_ARGS[@]}"
}

# Execute main function with all arguments
main "$@"