#!/bin/bash
# Claude-Compass Setup Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/setup.sh)"

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main"
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
CURRENT_DIR="$PWD"
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
    echo "Usage: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/setup.sh)\" -- [OPERATION]"
    echo ""
    echo "Operations:"
    echo "  install    Install Claude-Compass (default)"
    echo "  update     Update existing Claude-Compass installation"
    echo ""
    echo "Examples:"
    echo "  # Install (default)"
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/setup.sh)\""
    echo ""
    echo "  # Update existing installation"
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/setup.sh)\" -- update"
}

# Check if curl is available
check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed. Please install curl and try again."
        exit 1
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "python3 not found. JSON validation will be skipped."
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
    
    # Create Claude agents directory if it doesn't exist
    if [[ ! -d "$CLAUDE_AGENTS_DIR" ]]; then
        mkdir -p "$CLAUDE_AGENTS_DIR"
        log_success "Created agents directory: $CLAUDE_AGENTS_DIR"
    fi
    
    # Create COMPASS knowledge directories in current project
    mkdir -p "$CURRENT_DIR/docs"
    mkdir -p "$CURRENT_DIR/maps"
    
    if [[ ! -f "$CURRENT_DIR/maps/map-index.json" ]]; then
        echo '{"version":"1.0","created":"'$(date +%Y-%m-%d)'","maps":[],"categories":{},"recent_patterns":[],"tags":{}}' > "$CURRENT_DIR/maps/map-index.json"
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

# Install/Update hook handler
install_hook_handler() {
    local force_update="$1"
    
    log_info "Installing COMPASS hook handler..."
    
    local hook_url="$REPO_URL/compass-hook-handler.sh"
    local target_script="$CURRENT_DIR/compass-hook-handler.sh"
    
    if [[ -f "$target_script" ]] && [[ "$force_update" != "true" ]]; then
        log_warning "Hook handler already exists. Use 'update' to overwrite."
    else
        if download_file "$hook_url" "$target_script" "hook handler"; then
            chmod +x "$target_script"
            log_success "Installed hook handler: $target_script"
        else
            log_error "Failed to install hook handler"
            exit 1
        fi
    fi
}

# Configure or update .claude.json
configure_claude_json() {
    local force_update="$1"
    
    log_info "Configuring .claude.json..."
    
    local claude_config="$CURRENT_DIR/.claude.json"
    local hook_path="$CURRENT_DIR/compass-hook-handler.sh"
    local config_url="$REPO_URL/.claude.json"
    
    # Download the template configuration
    local temp_config="/tmp/claude-compass-config.json"
    if ! download_file "$config_url" "$temp_config" ".claude.json template"; then
        log_error "Failed to download configuration template"
        exit 1
    fi
    
    # Update the hook path in the template to match current directory
    if command -v sed >/dev/null 2>&1; then
        sed "s|/path/to/compass-hook-handler.sh|$hook_path|g" "$temp_config" > "$temp_config.updated"
        mv "$temp_config.updated" "$temp_config"
    else
        log_warning "sed not available. You may need to manually update hook path in .claude.json"
    fi
    
    if [[ -f "$claude_config" ]] && [[ "$force_update" != "true" ]]; then
        log_warning ".claude.json already exists. Use 'update' to overwrite."
        log_info "New configuration available at: $temp_config"
    else
        cp "$temp_config" "$claude_config"
        log_success "Configured .claude.json with COMPASS hooks"
    fi
    
    # Cleanup
    rm -f "$temp_config"
}

# Validate installation
validate_installation() {
    log_info "Validating Claude-Compass installation..."
    
    # Test hook handler execution
    if [[ -x "$CURRENT_DIR/compass-hook-handler.sh" ]]; then
        log_success "Hook handler is executable"
    else
        log_error "Hook handler is not executable"
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
    
    log_success "All COMPASS agents installed successfully (14 total agents including writing/academic/memory specialists)"
    
    # Test .claude.json syntax
    if command -v python3 >/dev/null 2>&1; then
        if [[ -f "$CURRENT_DIR/.claude.json" ]] && python3 -m json.tool "$CURRENT_DIR/.claude.json" >/dev/null 2>&1; then
            log_success ".claude.json syntax is valid"
        elif [[ -f "$CURRENT_DIR/.claude.json" ]]; then
            log_error ".claude.json contains syntax errors"
            exit 1
        fi
    fi
}

# Install operation
do_install() {
    log_info "🧭 Installing Claude-Compass..."
    
    setup_directories
    install_agents "false"
    install_hook_handler "false"
    configure_claude_json "false"
    validate_installation
    
    log_success "🧭 Claude-Compass successfully installed!"
    show_success_message
}

# Update operation
do_update() {
    log_info "🔄 Updating Claude-Compass..."
    
    setup_directories
    install_agents "true"
    install_hook_handler "true"
    configure_claude_json "true"
    validate_installation
    
    log_success "🔄 Claude-Compass successfully updated!"
    show_success_message
}

# Show success message with next steps
show_success_message() {
    echo ""
    echo "📍 Installation Summary:"
    echo "   • Captain and crew agents installed to: $CLAUDE_AGENTS_DIR"
    echo "   • Hook handler installed to: $CURRENT_DIR/compass-hook-handler.sh"
    echo "   • Configuration file: $CURRENT_DIR/.claude.json"
    echo "   • Knowledge directories: $CURRENT_DIR/{docs,maps}/"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Start Claude Code in this directory: claude"
    echo "   2. Try a complex analytical request to trigger COMPASS"
    echo "   3. Watch the captain coordinate all 14 agents through COMPASS methodology"
    echo ""
    echo "🔍 Test COMPASS with prompts like:"
    echo "   • \"Analyze the architecture of this codebase\""
    echo "   • \"Debug this performance issue systematically\""
    echo "   • \"Investigate the root cause of this problem\""
    echo "   • \"Implement a secure authentication system\""
    echo ""
    echo "✅ COMPASS is now protecting your project with bypass-resistant methodology enforcement!"
    echo "🧭⚓️ Ready to navigate any codebase with institutional knowledge and expert execution!"
}

# Main execution
main() {
    echo "🧭 Claude-Compass Setup Script"
    echo "=============================="
    echo "Repository: https://github.com/odysseyalive/Claude-Compass"
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