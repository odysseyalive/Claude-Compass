#!/bin/bash
# Claude-Compass Setup Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)"

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/odysseyalive/claude-compass/main"
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

# Install/Update hook handler - CORRECTED VERSION
install_hook_handler() {
    local force_update="$1"
    
    log_info "Installing COMPASS hook handler..."
    
    local target_script="$CURRENT_DIR/compass-hook-handler.sh"
    
    if [[ -f "$target_script" ]] && [[ "$force_update" != "true" ]]; then
        log_warning "Hook handler already exists. Use 'update' to overwrite."
        return 0
    fi
    
    # Create the corrected hook handler with embedded content
    cat > "$target_script" << 'HOOK_EOF'
#!/bin/bash
# COMPASS UserPromptSubmit Hook Handler  
# Properly integrates with Claude Code's JSON-based hook system

set -euo pipefail

# Configuration
LOG_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.compass-hook.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Read JSON input from stdin
input_json=$(cat)
log "🧭 COMPASS Hook: Received input: $input_json"

# Parse JSON input using jq if available, otherwise fall back to basic parsing
if command -v jq >/dev/null 2>&1; then
    USER_PROMPT=$(echo "$input_json" | jq -r '.prompt // empty')
    SESSION_ID=$(echo "$input_json" | jq -r '.session_id // empty')
    HOOK_EVENT=$(echo "$input_json" | jq -r '.hook_event_name // empty')
else
    # Basic JSON parsing without jq (less robust)
    USER_PROMPT=$(echo "$input_json" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    SESSION_ID=$(echo "$input_json" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    HOOK_EVENT=$(echo "$input_json" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

# Validate we have the expected hook event
if [[ "$HOOK_EVENT" != "UserPromptSubmit" ]]; then
    log "❌ Unexpected hook event: $HOOK_EVENT"
    exit 0
fi

# Validate we have a user prompt
if [[ -z "$USER_PROMPT" ]]; then
    log "⚠️ No user prompt found in input"
    exit 0
fi

log "🎯 Analyzing prompt: $USER_PROMPT"

# Define complexity triggers that require COMPASS methodology
COMPLEXITY_TRIGGERS=(
    "analyze" "investigate" "debug" "implement" "refactor" "optimize" 
    "understand" "design" "architect" "plan" "strategy" "complex"
    "system" "performance" "security" "scalability" "troubleshoot" 
    "diagnose" "root cause" "technical debt" "code review" "best practices"
    "create" "build" "write" "add" "develop" "fix" "solve" "resolve" 
    "handle" "manage" "integrate" "connect" "setup" "configure" "install"
    "deploy" "test" "validate" "verify" "check" "update" "modify" 
    "change" "improve" "enhance" "extend" "expand" "scale" "migrate" 
    "convert" "generate" "construct" "make" "produce" "craft"
)

# Function to check if prompt contains complexity triggers
is_complex_task() {
    local prompt_lower=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
    
    for trigger in "${COMPLEXITY_TRIGGERS[@]}"; do
        if echo "$prompt_lower" | grep -q "$trigger"; then
            log "✅ Complex task detected: '$trigger' found in prompt"
            return 0
        fi
    done
    
    # Check for code-related patterns
    if echo "$prompt_lower" | grep -qE "(class|function|method|algorithm|database|api|endpoint|integration)"; then
        log "✅ Code-related complexity detected"
        return 0
    fi
    
    # Check for multi-step indicators
    if echo "$prompt_lower" | grep -qE "(\b(and|then|also|additionally|furthermore|moreover)\b.*){2,}"; then
        log "✅ Multi-step task detected"
        return 0
    fi
    
    # Exclude very simple requests
    if echo "$prompt_lower" | grep -qE "^(show|list|display|print|echo|cat|ls|pwd|cd|help|\?)"; then
        log "⚪ Simple command-like request detected - bypassing COMPASS"
        return 1
    fi
    
    # Exclude basic information requests
    if echo "$prompt_lower" | grep -qE "^(what is|what are|how do i|can you tell me|explain briefly).*\?$"; then
        log "⚪ Basic information request detected - bypassing COMPASS"
        return 1
    fi
    
    return 1
}

# Function to inject COMPASS methodology context
inject_compass_context() {
    local compass_context="🧭 COMPASS METHODOLOGY REQUIRED

Complex analytical task detected. This request requires systematic institutional knowledge integration.

MANDATORY: You must use the Task tool with subagent_type='compass-captain' to coordinate:
□ Step 1: Query existing docs/ and maps/ for relevant patterns (compass-knowledge-query)
□ Step 2: Apply documented approaches from knowledge base (compass-pattern-apply) 
□ Step 3: Identify knowledge gaps requiring investigation (compass-gap-analysis)
□ Step 4: Plan documentation for new discoveries (compass-doc-planning)
□ Step 5: Execute enhanced analysis with institutional knowledge (compass-enhanced-analysis)
□ Step 6: Cross-reference findings with existing patterns (compass-cross-reference)

COMPASS IS NOT OPTIONAL for complex analytical tasks. This enforcement prevents institutional knowledge loss and ensures quality."

    # Output JSON to inject context into the prompt
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg context "$compass_context" '{
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": $context
            }
        }'
    else
        # Fallback JSON output without jq (basic escaping)
        local escaped_context=$(echo "$compass_context" | sed 's/"/\\"/g' | tr '\n' ' ')
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$escaped_context\"}}"
    fi
    
    log "✅ COMPASS context injected into prompt"
}

# Main logic
if is_complex_task; then
    log "🚀 Complex analytical task detected - injecting COMPASS methodology requirement"
    inject_compass_context
    exit 0
else
    log "✅ Simple request detected - COMPASS not required"
    exit 0
fi
HOOK_EOF
    
    chmod +x "$target_script"
    log_success "Installed corrected COMPASS hook handler: $target_script"
}

# Configure or update .claude.json
configure_claude_json() {
    local force_update="$1"
    
    log_info "Configuring .claude.json..."
    
    local claude_config="$CURRENT_DIR/.claude.json"
    local hook_path="$CURRENT_DIR/compass-hook-handler.sh"
    
    if [[ -f "$claude_config" ]] && [[ "$force_update" != "true" ]]; then
        log_warning ".claude.json already exists. Use 'update' to overwrite."
        return 0
    fi
    
    # Create the .claude.json configuration with embedded content
    cat > "$claude_config" << 'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "HOOK_PATH_PLACEHOLDER",
            "timeout": 120000
          }
        ]
      }
    ]
  },
  "compass": {
    "enforcement_level": "selective",
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
      "generate", "construct", "make", "produce", "craft"
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
      "second-opinion"
    ],
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
        log_success "Configured .claude.json with COMPASS hooks"
    else
        log_warning "sed not available. You need to manually update hook path in .claude.json"
        log_warning "Replace 'HOOK_PATH_PLACEHOLDER' with '$hook_path'"
    fi
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