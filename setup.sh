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

# Configure settings
configure_settings() {
  log_info "Configuring .claude/settings.json..."

  local settings_file="$CURRENT_DIR/.claude/settings.json"
  
  # Create basic settings if file doesn't exist
  if [[ ! -f "$settings_file" ]]; then
    cat > "$settings_file" << 'EOF'
{
  "hooks": {
    "preToolUse": [".compass/handlers/compass-handler.py"],
    "userPromptSubmit": [".compass/handlers/compass-handler.py"]
  }
}
EOF
  else
    # Update existing settings - simplified approach
    if ! grep -q "preToolUse" "$settings_file"; then
      log_info "Adding hooks to existing settings..."
      # Create a backup
      cp "$settings_file" "$settings_file.backup"
      
      # Simple insertion approach
      local temp_settings
      temp_settings=$(mktemp)
      
      if [[ -s "$settings_file" ]]; then
        # Remove closing brace and add hooks
        sed '$ s/}$//' "$settings_file" > "$temp_settings"
        cat >> "$temp_settings" << 'EOF'
  "hooks": {
    "preToolUse": [".compass/handlers/compass-handler.py"],
    "userPromptSubmit": [".compass/handlers/compass-handler.py"]
  }
}
EOF
      else
        cat > "$temp_settings" << 'EOF'
{
  "hooks": {
    "preToolUse": [".compass/handlers/compass-handler.py"],
    "userPromptSubmit": [".compass/handlers/compass-handler.py"]
  }
}
EOF
      fi
      
      mv "$temp_settings" "$settings_file"
    fi
  fi

  log_success "Configured Claude Code settings with COMPASS hooks"
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