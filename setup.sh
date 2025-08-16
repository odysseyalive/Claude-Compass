#!/bin/bash

# COMPASS Setup Script - Fixed Version
# Fixed: Removed set -u to avoid unbound variable errors
# Fixed: Added missing escape_path_for_sed function
set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for escaped paths in sed
escape_path_for_sed() {
  printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Get current directory
CURRENT_DIR="$(pwd)"

# Create directories if they don't exist
setup_directories() {
  log_info "Setting up directory structure..."

  # Create .claude/agents directory
  if [[ ! -d "$CURRENT_DIR/.claude/agents" ]]; then
    mkdir -p "$CURRENT_DIR/.claude/agents"
    log_success "Created local agents directory: $CURRENT_DIR/.claude/agents"
  fi

  # Create maps directory and index
  if [[ ! -d "$CURRENT_DIR/maps" ]]; then
    mkdir -p "$CURRENT_DIR/maps"
  fi

  if [[ ! -f "$CURRENT_DIR/maps/map-index.json" ]]; then
    local current_date
    current_date=$(date +%Y-%m-%d)
    printf '{"version":"1.0","created":"%s","maps":[],"categories":{},"recent_patterns":[],"tags":{}}' "$current_date" >"$CURRENT_DIR/maps/map-index.json"
    log_success "Created empty map index: $CURRENT_DIR/maps/map-index.json"
  fi
}

# Download file function with proper error handling
download_file() {
  local url="$1"
  local output_path="$2"
  local description="$3"

  local temp_file=""
  temp_file=$(mktemp) || {
    log_error "Failed to create temporary file for download"
    return 1
  }

  # Cleanup function
  cleanup_temp() {
    [[ -n "$temp_file" && -f "$temp_file" ]] && rm -f "$temp_file"
  }
  trap cleanup_temp RETURN

  if curl -fsSL "$url" -o "$temp_file" 2>/dev/null; then
    # Validate download
    if [[ -s "$temp_file" ]] && head -1 "$temp_file" | grep -v "404\|error\|not found" >/dev/null 2>&1; then
      # Move to final location
      if mv "$temp_file" "$output_path"; then
        log_success "Downloaded $description"
        return 0
      else
        log_error "Failed to move $description to final location"
        return 1
      fi
    else
      log_error "Download validation failed for $description"
      return 1
    fi
  else
    log_error "Failed to download $description from $url"
    return 1
  fi
}

# Install agents
install_agents() {
  local force_update="$1"

  log_info "Installing COMPASS agents..."

  local agents=(
    "compass-captain"
    "compass-methodology-selector"
    "compass-knowledge-query"
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
    "compass-svg-analyst.md"
  )

  for agent in "${agents[@]}"; do
    local agent_file="$CURRENT_DIR/.claude/agents/$agent.md"
    local agent_url="https://raw.githubusercontent.com/odysseyalive/claude-compass/main/claude/agents/$agent.md"

    if [[ -f "$agent_file" && "$force_update" != "true" ]]; then
      log_warning "Agent $agent already exists. Use 'update' to overwrite."
      continue
    fi

    log_info "Downloading agent: $agent..."
    if download_file "$agent_url" "$agent_file" "agent: $agent"; then
      log_success "Installed agent: $agent"
    else
      log_error "Failed to install agent: $agent"
      return 1
    fi
  done
}

# Install technical enforcement
install_technical_enforcement() {
  log_info "Installing COMPASS tools and technical enforcement..."

  # Create .compass/handlers directory
  mkdir -p "$CURRENT_DIR/.compass/handlers"

  # Download compass-handler.py
  local handler_url="https://raw.githubusercontent.com/odysseyalive/claude-compass/main/compass/handlers/compass-handler.py"
  local handler_file="$CURRENT_DIR/.compass/handlers/compass-handler.py"

  log_info "Downloading technical enforcement system..."
  if download_file "$handler_url" "$handler_file" "technical enforcement system"; then
    log_success "Installed COMPASS technical enforcement: $handler_file"
  else
    log_error "Failed to install technical enforcement system"
    return 1
  fi
}

# Configure or update .claude/settings.json
configure_settings() {
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
  },
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

# Main execution
main() {
  echo "🧭 Claude-Compass Setup Script"
  echo "=============================="
  echo "Repository: https://github.com/odysseyalive/claude-compass"
  echo

  local force_update="false"
  if [[ "${1:-}" == "update" ]]; then
    force_update="true"
    log_info "🔄 Updating Claude-Compass..."
  else
    log_info "🧭 Installing Claude-Compass..."
  fi

  # Run setup steps
  setup_directories || exit 1
  install_agents "$force_update" || exit 1
  install_technical_enforcement || exit 1
  configure_settings || exit 1

  echo
  log_success "🎉 COMPASS installation completed successfully!"
  echo
  echo "Next steps:"
  echo "1. Restart Claude Code to load the new configuration"
  echo "2. COMPASS will automatically activate on complex tasks"
  echo "3. Check the documentation: docs/ and maps/ directories will be created as you work"
  echo
}

# Run main function with all arguments
main "$@"

