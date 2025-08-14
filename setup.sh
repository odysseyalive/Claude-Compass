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
check_dependencies() {
  if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed. Please install curl and try again."
    exit 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 is required for COMPASS technical enforcement but not installed."
    log_error "Please install python3 and try again."
    exit 1
  fi
}

# Download file with error handling
download_file() {
  local url="$1"
  local output_path="$2"
  local description="$3"

  log_info "Downloading $description..."

  if curl -fsSL "$url" -o "$output_path" 2>/dev/null; then
    log_success "Downloaded $description"
    return 0
  else
    log_error "Failed to download $description from $url"
    return 1
  fi
}

# Create necessary directories
setup_directories() {
  log_info "Setting up directory structure..."

  # Create local Claude agents directory if it doesn't exist
  if [[ ! -d "$CLAUDE_AGENTS_DIR" ]]; then
    mkdir -p "$CLAUDE_AGENTS_DIR"
    log_success "Created local agents directory: $CLAUDE_AGENTS_DIR"
  fi

  # Create COMPASS knowledge directories in current project
  mkdir -p "$CURRENT_DIR/docs"
  mkdir -p "$CURRENT_DIR/maps"

  if [[ ! -f "$CURRENT_DIR/maps/map-index.json" ]]; then
    echo '{"version":"1.0","created":"'$(date +%Y-%m-%d)'","maps":[],"categories":{},"recent_patterns":[],"tags":{}}' >"$CURRENT_DIR/maps/map-index.json"
    log_success "Created empty map index: $CURRENT_DIR/maps/map-index.json"
  fi
}

# Install/Update COMPASS agents
install_agents() {
  local force_update="$1"

  log_info "Installing COMPASS agents..."

  local agents=(
    "compass-captain"
    "compass-knowledge-query"
    "compass-pattern-apply"
    "compass-data-flow"
    "compass-gap-analysis"
    "compass-doc-planning"
    "compass-enhanced-analysis"
    "compass-cross-reference"
    "compass-coder"
    "compass-svg-analyst"
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
  )

  for agent in "${agents[@]}"; do
    local agent_url="$REPO_URL/agents/${agent}.md"
    local target_file="$CLAUDE_AGENTS_DIR/${agent}.md"

    if [[ -f "$target_file" ]] && [[ "$force_update" != "true" ]]; then
      log_warning "Agent $agent already exists. Use 'update' to overwrite."
    else
      if download_file "$agent_url" "$target_file" "agent: $agent"; then
        log_success "Installed agent: $agent"
      else
        log_error "Failed to install agent: $agent"
        exit 1
      fi
    fi
  done
}

# Install/Update COMPASS technical enforcement system
install_enforcement_hook() {
  local force_update="$1"

  log_info "Installing COMPASS technical enforcement system..."

  local target_script="$CURRENT_DIR/compass-handler.py"

  # Clean up deprecated files during migration
  if [[ -f "$CURRENT_DIR/compass-hook-handler.sh" ]]; then
    log_info "Removing deprecated hook handler..."
    rm "$CURRENT_DIR/compass-hook-handler.sh"
    log_success "Cleaned up deprecated compass-hook-handler.sh"
  fi

  if [[ -f "$target_script" ]] && [[ "$force_update" != "true" ]]; then
    log_warning "Technical enforcement already exists. Use 'update' to overwrite."
    return 0
  fi

  # Download compass-handler.py from repository
  if download_file "$REPO_URL/compass-handler.py" "$target_script" "technical enforcement system"; then
    chmod +x "$target_script"
    log_success "Installed COMPASS technical enforcement: $target_script"
  else
    log_error "Failed to install technical enforcement system"
    exit 1
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
  local hook_path="$CURRENT_DIR/compass-handler.py"

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
  },
  "compass": {
    "enforcement_level": "technical",
    "complexity_triggers": [
      "analyze", "investigate", "debug", "implement", 
      "refactor", "optimize", "understand", "design",
      "architect", "plan", "strategy", "complex",
      "system", "performance", "security", "scalability",
      "troubleshoot", "diagnose", "root cause",
      "technical debt", "code review", "best practices",
      "create", "build", "write", "add", "develop",
      "fix", "solve", "resolve", "handle", "manage",
      "integrate", "connect", "setup", "configure", "install",
      "deploy", "test", "validate", "verify", "check",
      "update", "modify", "change", "improve", "enhance",
      "extend", "expand", "scale", "migrate", "convert",
      "generate", "construct", "make", "produce", "craft",
      "authenticate", "auth", "login", "credentials", "oauth",
      "saml", "jwt", "session", "token", "api-key", "sso",
      "multi-provider", "enterprise-policy", "key-rotation",
      "identity", "authorization", "permissions", "access-control"
    ],
    "captain_agent": "compass-captain",
    "crew_agents": [
      "compass-knowledge-query",
      "compass-pattern-apply", 
      "compass-data-flow",
      "compass-gap-analysis",
      "compass-doc-planning",
      "compass-enhanced-analysis",
      "compass-cross-reference",
      "compass-coder",
      "compass-svg-analyst",
      "compass-second-opinion",
      "compass-auth-performance-analyst",
      "compass-auth-security-validator",
      "compass-auth-optimization-specialist"
    ],
    "authentication": {
      "session_persistence": true,
      "cross_iteration_memory": true,
      "enterprise_policy_support": true,
      "multi_provider_coordination": true
    },
    "documentation": {
      "create_investigation_docs": true,
      "create_visual_maps": true,
      "update_pattern_library": true,
      "capture_lessons_learned": true
    },
    "bypass_resistance": {
      "context_refresh": true,
      "distributed_enforcement": true,
      "sequential_validation": true
    }
  }
}
EOF

  # Update the hook path in the configuration to match current directory
  if command -v sed >/dev/null 2>&1; then
    sed -i "s|HOOK_PATH_PLACEHOLDER|$hook_path|g" "$claude_config"
    log_success "Configured .claude/settings.json with enhanced COMPASS and authentication capabilities"
  else
    log_warning "sed not available. You need to manually update hook path in .claude/settings.json"
    log_warning "Replace 'HOOK_PATH_PLACEHOLDER' with '$hook_path'"
  fi
}

# Validate installation
validate_installation() {
  log_info "Validating Claude-Compass installation..."

  # Test technical enforcement system execution
  if [[ -x "$CURRENT_DIR/compass-handler.py" ]]; then
    log_success "Technical enforcement system is executable"

    # Test actual functionality with sample input
    if echo '{"tool_name":"test","tool_input":{}}' | "$CURRENT_DIR/compass-handler.py" >/dev/null 2>&1; then
      log_success "Technical enforcement system functional"
    else
      log_error "compass-handler.py execution failed - check Python dependencies"
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
    "compass-knowledge-query"
    "compass-pattern-apply"
    "compass-data-flow"
    "compass-gap-analysis"
    "compass-doc-planning"
    "compass-enhanced-analysis"
    "compass-cross-reference"
    "compass-coder"
    "compass-svg-analyst"
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

  log_success "All COMPASS agents installed successfully (21 total agents including writing/academic/memory specialists, authentication specialists, upstream validation, dependency tracking, breakthrough documentation, and todo synchronization)"

  # Test .claude/settings.json syntax
  if command -v python3 >/dev/null 2>&1; then
    if [[ -f "$CURRENT_DIR/.claude/settings.json" ]]; then
      if python3 -m json.tool "$CURRENT_DIR/.claude/settings.json" >/dev/null 2>&1; then
        log_success ".claude/settings.json syntax is valid"

        # Verify hook configuration correctness
        if grep -q "PreToolUse" "$CURRENT_DIR/.claude/settings.json" && grep -q "compass-handler.py" "$CURRENT_DIR/.claude/settings.json"; then
          log_success "Hook configuration properly configured for technical enforcement"
        else
          log_warning "Hook configuration may not be using PreToolUse with compass-handler.py"
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
  install_enforcement_hook "false"
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
  install_enforcement_hook "true"
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
  echo "   • Technical enforcement installed to: $CURRENT_DIR/compass-handler.py"
  echo "   • Configuration file: $CURRENT_DIR/.claude/settings.json"
  echo "   • Knowledge directories: $CURRENT_DIR/{docs,maps}/"
  echo ""
  echo "🚀 Next Steps:"
  echo "   1. Start Claude Code in this directory: claude"
  echo "   2. Try a complex analytical request to trigger COMPASS"
  echo "   3. Watch the captain coordinate all 21 agents through COMPASS methodology"
  echo ""
  echo "🔍 Test COMPASS with prompts like:"
  echo "   • \"Analyze the architecture of this codebase\""
  echo "   • \"Debug this performance issue systematically\""
  echo "   • \"Investigate the root cause of this problem\""
  echo "   • \"Implement a secure authentication system\""
  echo ""
  echo "✅ COMPASS technical enforcement active - blocks operations without methodology compliance!"
  echo "🛡️ PreToolUse hooks provide true bypass resistance through operation blocking!"
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
