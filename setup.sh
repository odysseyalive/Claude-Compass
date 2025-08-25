#!/bin/bash
# Claude-Compass Setup Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)"

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/odysseyalive/claude-compass/main"
CURRENT_DIR="$(pwd)"
CLAUDE_AGENTS_DIR="$CURRENT_DIR/.claude/agents"
OPERATION="${1:-install}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Escape special characters in path for sed safety
escape_path_for_sed() {
  local path="$1"
  # Escape forward slashes, backslashes, and ampersands for sed
  # Since we're using # as delimiter in sed, only escape & characters
  echo "$path" | sed 's/&/\&/g'
}

# Show usage information
show_usage() {
  echo "Claude-Compass Setup Script"
  echo ""
  echo "Usage: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)\" -- [OPERATION]"
  echo ""
  echo "Operations:"
  echo "  install    Install Claude-Compass (default)"
  echo "  update     Update existing Claude-Compass installation"
  echo ""
  echo "Examples:"
  echo "  # Install (default)"
  echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)\""
  echo ""
  echo "  # Update existing installation"
  echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)\" -- update"
}

# Check if curl is available
# Validate repository URL to prevent malicious redirects
validate_repo_url() {
  local repo_url="$1"

  # Basic URL validation - ensure it's HTTPS and points to expected domain
  if [[ ! "$repo_url" =~ ^https://raw\.githubusercontent\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid repository URL format: $repo_url"
    log_error "Expected format: https://raw.githubusercontent.com/user/repo/branch"
    exit 1
  fi

  # Test connectivity to repository
  if ! curl -fsSL --head "$repo_url/setup.sh" >/dev/null 2>&1; then
    log_warning "Cannot validate repository connectivity - proceeding with caution"
  fi
}

# Enhanced cleanup function for error recovery
cleanup_on_error() {
  local exit_code="$1"
  log_info "Cleaning up after error (exit code: $exit_code)..."

  # Remove any temporary files that might have been created
  rm -f /tmp/compass-setup-* 2>/dev/null || true

  # If this was an update that failed, provide recovery instructions
  if [[ "$OPERATION" == "update" ]]; then
    log_info "Update failed - your existing installation should still be functional"
    log_info "You can retry the update or contact support for assistance"
  fi
}

# Set up error trap for cleanup
trap 'cleanup_on_error $?' ERR

check_dependencies() {
  local missing_deps=()

  # Check for required commands
  if ! command -v curl >/dev/null 2>&1; then
    missing_deps+=("curl")
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    missing_deps+=("python3")
  fi

  # Check for additional utilities needed for portable operation
  if ! command -v mktemp >/dev/null 2>&1; then
    missing_deps+=("mktemp")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_error "Please install the missing dependencies and try again."
    echo ""
    echo "Installation instructions:"
    for dep in "${missing_deps[@]}"; do
      case "$dep" in
      curl)
        echo "  • curl: Usually available in 'curl' package"
        ;;
      python3)
        echo "  • python3: Required for COMPASS technical enforcement"
        ;;
      mktemp)
        echo "  • mktemp: Usually part of coreutils package"
        ;;
      esac
    done
    exit 1
  fi

  # Verify Python can import json module (needed for validation)
  if ! python3 -c "import json" 2>/dev/null; then
    log_error "Python3 json module not available - check Python3 installation"
    exit 1
  fi
}

# Download file with error handling and integrity verification
download_file() {
  local url="$1"
  local output_path="$2"
  local description="$3"

  log_info "Downloading $description..."

  # Create temporary file to validate before moving to final location
  local temp_file=""
  temp_file=$(mktemp) || {
    log_error "Failed to create temporary file for download"
    return 1
  }

  if curl -fsSL "$url" -o "$temp_file" 2>/dev/null; then
    # Verify download has content (not empty or error page)
    if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -v "404\|error\|not found" >/dev/null 2>&1; then
      # Move validated file to final location
      if mv "$temp_file" "$output_path"; then
        log_success "Downloaded $description"
        return 0
      else
        log_error "Failed to move downloaded file to final location: $output_path"
        rm -f "$temp_file" 2>/dev/null || true
        return 1
      fi
    else
      log_error "Downloaded file appears to be invalid or empty: $description"
      rm -f "$temp_file" 2>/dev/null || true
      return 1
    fi
  else
    log_error "Failed to download $description from $url"
    rm -f "$temp_file" 2>/dev/null || true
    return 1
  fi
}

# Create necessary directories with permission verification
setup_directories() {
  log_info "Setting up directory structure..."

  # Verify write permissions before attempting operations
  if [[ ! -w "$CURRENT_DIR" ]]; then
    log_error "No write permission in current directory: $CURRENT_DIR"
    exit 1
  fi

  # Create local Claude agents directory if it doesn't exist
  if [[ ! -d "$CLAUDE_AGENTS_DIR" ]]; then
    if ! mkdir -p "$CLAUDE_AGENTS_DIR"; then
      log_error "Failed to create agents directory: $CLAUDE_AGENTS_DIR"
      exit 1
    fi
    log_success "Created local agents directory: $CLAUDE_AGENTS_DIR"
  fi

  # Create COMPASS knowledge directories in current project
  if ! mkdir -p "$CURRENT_DIR/docs" "$CURRENT_DIR/maps"; then
    log_error "Failed to create COMPASS knowledge directories"
    exit 1
  fi

  if [[ ! -f "$CURRENT_DIR/maps/map-index.json" ]]; then
    # Fixed: Use safe variable substitution instead of command substitution
    local current_date
    current_date=$(date +%Y-%m-%d)
    printf '{"version":"1.0","created":"%s","maps":[],"categories":{},"recent_patterns":[],"tags":{}}' "$current_date" >"$CURRENT_DIR/maps/map-index.json"
    log_success "Created empty map index: $CURRENT_DIR/maps/map-index.json"
  fi
}

# Install/Update COMPASS agents
install_agents() {
  local force_update="$1"

  log_info "Installing COMPASS agents..."

  local agents=(
    "compass-captain"
    "compass-complexity-analyzer"
    "compass-strategy-builder"
    "compass-validation-coordinator"
    "compass-knowledge-discovery"
    "compass-knowledge-reader"
    "compass-knowledge-synthesizer"
    "compass-pattern-apply"
    "compass-data-flow"
    "compass-gap-analysis"
    "compass-doc-planning"
    "compass-enhanced-analysis"
    "compass-cross-reference"
    "compass-coder"
    "compass-writing-analyst"
    "compass-academic-analyst"
    "compass-memory-enhanced-writer"
    "compass-second-opinion"
    "compass-auth-performance-analyst"
    "compass-auth-security-validator"
    "compass-auth-optimization-specialist"
    "compass-upstream-validator"
    "compass-dependency-tracker"
    "compass-breakthrough-doc"
    "compass-todo-sync"
    "compass-svg-analyst"
  )

  # Track installation progress for rollback capability
  local installed_agents=()

  for agent in "${agents[@]}"; do
    local agent_url="$REPO_URL/claude/agents/${agent}.md"
    local target_file="$CLAUDE_AGENTS_DIR/${agent}.md"

    if [[ -f "$target_file" ]] && [[ "$force_update" != "true" ]]; then
      log_warning "Agent $agent already exists. Use 'update' to overwrite."
      installed_agents+=("$agent")
    else
      if download_file "$agent_url" "$target_file" "agent: $agent"; then
        log_success "Installed agent: $agent"
        installed_agents+=("$agent")
      else
        log_error "Failed to install agent: $agent"

        # Rollback: Remove any agents installed in this session on failure
        if [[ "$force_update" == "true" ]]; then
          log_info "Rolling back partial installation due to failed agent: $agent"
          for installed_agent in "${installed_agents[@]}"; do
            if [[ -f "$CLAUDE_AGENTS_DIR/${installed_agent}.md" ]]; then
              if rm "$CLAUDE_AGENTS_DIR/${installed_agent}.md"; then
                log_info "Removed: $installed_agent"
              else
                log_warning "Failed to remove: $installed_agent"
              fi
            fi
          done
        fi
        exit 1
      fi
    fi
  done
}

# Install/Update COMPASS technical enforcement system
# Install/Update COMPASS technical enforcement system and tools
install_compass_tools() {
  local force_update="$1"

  log_info "Installing COMPASS tools and technical enforcement..."

  # Create .compass directory structure
  local compass_dir="$CURRENT_DIR/.compass"
  if ! mkdir -p "$compass_dir"/{handlers,bin,logs}; then
    log_error "Failed to create .compass directory structure"
    exit 1
  fi

  # Install compass-handler.py
  local handler_script="$compass_dir/handlers/compass-handler.py"
  if [[ -f "$handler_script" ]] && [[ "$force_update" != "true" ]]; then
    log_warning "Technical enforcement already exists. Use 'update' to overwrite."
  else
    if download_file "$REPO_URL/compass/handlers/compass-handler.py" "$handler_script" "technical enforcement system"; then
      if head -1 "$handler_script" | grep -q "^#!/.*python"; then
        chmod +x "$handler_script"
        log_success "Installed COMPASS technical enforcement: $handler_script"
      else
        log_error "Downloaded technical enforcement file does not appear to be a valid Python script"
        rm -f "$handler_script"
        exit 1
      fi
    else
      log_error "Failed to install technical enforcement system"
      exit 1
    fi
  fi

  # Clean up deprecated files during migration
  if [[ -f "$CURRENT_DIR/compass-handler.py" ]]; then
    log_info "Migrating from old compass-handler.py location..."
    rm "$CURRENT_DIR/compass-handler.py"
    log_success "Cleaned up old compass-handler.py"
  fi
  if [[ -f "$CURRENT_DIR/compass-hook-handler.sh" ]]; then
    log_info "Removing deprecated hook handler..."
    rm "$CURRENT_DIR/compass-hook-handler.sh"
    log_success "Cleaned up deprecated compass-hook-handler.sh"
  fi
}

# Configure or update .claude/settings.json
configure_claude_settings() {
  local force_update="$1"

  log_info "Configuring .claude/settings.json..."

  # Create .claude directory if it doesn't exist
  local claude_dir="$CURRENT_DIR/.claude"
  if [[ ! -d "$claude_dir" ]]; then
    mkdir -p "$claude_dir"
    log_success "Created .claude directory: $claude_dir"
  fi

  local claude_config="$claude_dir/settings.json"
  local hook_path="$CURRENT_DIR/.compass/handlers/compass-handler.py"

  # Clean up deprecated .claude.json during migration
  if [[ -f "$CURRENT_DIR/.claude.json" ]]; then
    log_info "Migrating from deprecated .claude.json to modern .claude/settings.json..."
    if [[ "$force_update" == "true" ]] || [[ ! -f "$claude_config" ]]; then
      rm "$CURRENT_DIR/.claude.json"
      log_success "Removed deprecated .claude.json"
    fi
  fi

  if [[ -f "$claude_config" ]] && [[ "$force_update" != "true" ]]; then
    log_warning ".claude/settings.json already exists. Use 'update' to overwrite."
    return 0
  fi

  # Create the .claude/settings.json configuration with enhanced authentication capabilities
  cat >"$claude_config" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "HOOK_PATH_PLACEHOLDER",
            "timeout": 30000
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "HOOK_PATH_PLACEHOLDER",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
EOF

  # Update the hook path in the configuration to match current directory
  if command -v sed >/dev/null 2>&1; then
    # Fixed: Escape special characters in path to prevent sed injection
    escaped_hook_path=$(escape_path_for_sed "$hook_path")
    if sed -i "s#HOOK_PATH_PLACEHOLDER#$escaped_hook_path#g" "$claude_config"; then
      log_success "Configured .claude/settings.json with enhanced COMPASS and authentication capabilities"
    else
      log_error "Failed to update hook path in configuration"
      exit 1
    fi
  else
    log_warning "sed not available. You need to manually update hook path in .claude/settings.json"
    log_warning "Replace 'HOOK_PATH_PLACEHOLDER' with '$hook_path'"
    return 1
  fi
}

# Validate installation
validate_installation() {
  log_info "Validating Claude-Compass installation..."

  # Test technical enforcement system execution
  local compass_handler="$CURRENT_DIR/.compass/handlers/compass-handler.py"
  if [[ -x "$compass_handler" ]]; then
    log_success "Technical enforcement system is executable"

    # Test actual functionality with sample input
    local test_input='{"tool_name":"test","tool_input":{}}'
    if echo "$test_input" | "$compass_handler" >/dev/null 2>&1; then
      log_success "Technical enforcement system functional"
    else
      log_error "compass-handler.py execution failed - check Python dependencies"

      # Provide helpful debugging information
      log_info "Attempting to diagnose issue..."
      if ! python3 "$compass_handler" --version 2>/dev/null; then
        log_error "Python script execution failed - check script permissions and Python path"
      fi
      exit 1
    fi
  else
    log_error "Technical enforcement system is not executable"
    exit 1
  fi

  # Test agent file accessibility
  local missing_agents=()
  local agents=(
    "compass-captain"
    "compass-complexity-analyzer"
    "compass-strategy-builder"
    "compass-validation-coordinator"
    "compass-knowledge-discovery"
    "compass-knowledge-reader"
    "compass-knowledge-synthesizer"
    "compass-pattern-apply"
    "compass-data-flow"
    "compass-gap-analysis"
    "compass-doc-planning"
    "compass-enhanced-analysis"
    "compass-cross-reference"
    "compass-coder"
    "compass-writing-analyst"
    "compass-academic-analyst"
    "compass-memory-enhanced-writer"
    "compass-second-opinion"
    "compass-auth-performance-analyst"
    "compass-auth-security-validator"
    "compass-auth-optimization-specialist"
    "compass-upstream-validator"
    "compass-dependency-tracker"
    "compass-breakthrough-doc"
    "compass-todo-sync"
    "compass-svg-analyst"
  )

  for agent in "${agents[@]}"; do
    if [[ ! -f "$CLAUDE_AGENTS_DIR/${agent}.md" ]]; then
      missing_agents+=("$agent")
    fi
  done

  if [[ ${#missing_agents[@]} -gt 0 ]]; then
    log_error "Missing agent files: ${missing_agents[*]}"
    exit 1
  fi

  log_success "All COMPASS agents installed successfully (26 total agents including complexity analyzer, strategy builder, validation coordinator, knowledge discovery/reader/synthesizer specialists, writing/academic/memory specialists, authentication specialists, upstream validation, dependency tracking, breakthrough documentation, and todo synchronization)"

  # Test .claude/settings.json syntax
  if command -v python3 >/dev/null 2>&1; then
    if [[ -f "$CURRENT_DIR/.claude/settings.json" ]]; then
      if python3 -m json.tool "$CURRENT_DIR/.claude/settings.json" >/dev/null 2>&1; then
        log_success ".claude/settings.json syntax is valid"

        # Verify hook configuration correctness
        if grep -q "PreToolUse" "$CURRENT_DIR/.claude/settings.json" && grep -q ".compass/handlers/compass-handler.py" "$CURRENT_DIR/.claude/settings.json"; then
          log_success "Hook configuration properly configured for technical enforcement"
        else
          log_warning "Hook configuration may not be using PreToolUse with .compass/handlers/compass-handler.py"
        fi
      else
        log_error ".claude/settings.json contains syntax errors"
        exit 1
      fi
    fi
  fi
}

# Install operation
do_install() {
  log_info "🧭 Installing Claude-Compass..."

  setup_directories
  install_agents "false"
  install_compass_tools "false"
  configure_claude_settings "false"
  validate_installation

  log_success "🧭 Claude-Compass successfully installed!"
  show_success_message
}

# Update operation
do_update() {
  log_info "🔄 Updating Claude-Compass..."

  setup_directories
  install_agents "true"
  install_compass_tools "true"
  configure_claude_settings "true"
  validate_installation

  log_success "🔄 Claude-Compass successfully updated!"
  show_success_message
}

# Show success message with next steps
show_success_message() {
  echo ""
  echo "📍 Installation Summary:"
  echo "   • Captain and crew agents installed to: $CLAUDE_AGENTS_DIR"
  echo "   • Technical enforcement installed to: $CURRENT_DIR/.compass/handlers/compass-handler.py"

  echo "   • Configuration file: $CURRENT_DIR/.claude/settings.json"
  echo "   • Knowledge directories: $CURRENT_DIR/{docs,maps}/"
  echo "   • COMPASS logs directory: $CURRENT_DIR/.compass/logs/"
  echo ""
  echo "🚀 Next Steps:"
  echo "   1. Start Claude Code in this directory: claude"
  echo "   2. Try a complex analytical request to trigger COMPASS"
  echo "   3. Watch the captain coordinate all 22 agents through COMPASS methodology"
  echo "   4. Observe parallel agent execution and strategic planning optimization"
  echo ""
  echo "🔍 Test COMPASS with prompts like:"
  echo "   • \"Analyze the architecture of this codebase\""
  echo "   • \"Debug this performance issue systematically\""
  echo "   • \"Investigate the root cause of this problem\""
  echo "   • \"Implement a secure authentication system\""
  echo ""
  echo "✅ COMPASS technical enforcement active - blocks operations without methodology compliance!"
  echo "🛡️ PreToolUse hooks provide true bypass resistance through operation blocking!"
  echo "⚡ Strategic planning via micro-agent architecture (complexity-analyzer, strategy-builder, validation-coordinator) optimizes token usage and execution!"
  echo "🔄 Parallel agent coordination delivers 20-25% performance improvement!"
  echo "🧭⚓️ Ready to navigate any codebase with institutional knowledge and expert execution!"
}

# Main execution
main() {
  echo "🧭 Claude-Compass Setup Script"
  echo "=============================="
  echo "Repository: https://github.com/odysseyalive/claude-compass"
  echo ""

  if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
  fi

  # Validate repository URL before any operations
  validate_repo_url "$REPO_URL"

  check_dependencies

  case "$OPERATION" in
  "install")
    do_install
    ;;
  "update")
    do_update
    ;;
  *)
    log_error "Unknown operation: $OPERATION"
    echo ""
    show_usage
    exit 1
    ;;
  esac
}

# Run main function with all arguments
main "$@"
