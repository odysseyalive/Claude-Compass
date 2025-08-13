#!/bin/bash
# COMPASS UserPromptSubmit Hook Handler
# Enforces COMPASS methodology through queen bee agent for complex analytical tasks

set -euo pipefail

# Configuration
COMPASS_AGENT_NAME="compass-captain"
LOG_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.compass-hook.log"
TIMEOUT=300  # 5 minutes

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    echo "$*" >&2
}

# Read user prompt from stdin if available, otherwise from environment
if [ -t 0 ]; then
    # stdin is a terminal, try environment variable
    USER_PROMPT="${CLAUDE_USER_PROMPT:-}"
else
    # stdin has data, read it
    USER_PROMPT=$(cat)
fi

# Fallback to command line arguments if no prompt found
if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT="$*"
fi

log "🧭 COMPASS Hook: Analyzing user prompt"
log "Prompt: $USER_PROMPT"

# Define complexity triggers that require COMPASS methodology
COMPLEXITY_TRIGGERS=(
    "analyze"
    "investigate" 
    "debug"
    "implement"
    "refactor"
    "optimize"
    "understand"
    "design"
    "architect"
    "plan"
    "strategy"
    "complex"
    "system"
    "performance"
    "security"
    "scalability"
    "troubleshoot"
    "diagnose"
    "root cause"
    "technical debt"
    "code review"
    "best practices"
    "create"
    "build"
    "write"
    "add"
    "develop"
    "fix"
    "solve"
    "resolve"
    "handle"
    "manage"
    "integrate"
    "connect"
    "setup"
    "configure"
    "install"
    "deploy"
    "test"
    "validate"
    "verify"
    "check"
    "update"
    "modify"
    "change"
    "improve"
    "enhance"
    "extend"
    "expand"
    "scale"
    "migrate"
    "convert"
    "generate"
    "construct"
    "make"
    "produce"
    "craft"
)

# Function to check if prompt contains complexity triggers
is_complex_task() {
    local prompt_lower=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
    
    for trigger in "${COMPLEXITY_TRIGGERS[@]}"; do
        if echo "$prompt_lower" | grep -q "$trigger"; then
            log "Complex task detected: '$trigger' found in prompt"
            return 0
        fi
    done
    
    # Check for code-related patterns
    if echo "$prompt_lower" | grep -qE "(class|function|method|algorithm|database|api|endpoint|integration)"; then
        log "Code-related complexity detected"
        return 0
    fi
    
    # Check for multi-step indicators
    if echo "$prompt_lower" | grep -qE "(\b(and|then|also|additionally|furthermore|moreover)\b.*){2,}"; then
        log "Multi-step task detected"
        return 0
    fi
    
    # Exclude very simple requests that might be handled by existing tools
    if echo "$prompt_lower" | grep -qE "^(show|list|display|print|echo|cat|ls|pwd|cd|help|\?)"; then
        log "Simple command-like request detected - bypassing COMPASS"
        return 1
    fi
    
    # Exclude basic information requests
    if echo "$prompt_lower" | grep -qE "^(what is|what are|how do i|can you tell me|explain briefly).*\?$"; then
        log "Basic information request detected - bypassing COMPASS"
        return 1
    fi
    
    return 1
}

# Function to invoke COMPASS queen bee agent
invoke_compass() {
    log "🚀 Invoking COMPASS queen bee agent"
    
    # Check if claude-code CLI is available
    if ! command -v claude-code >/dev/null 2>&1; then
        log "❌ claude-code CLI not found - attempting direct agent call"
        
        # Try alternative methods to invoke agent
        if command -v claude >/dev/null 2>&1; then
            echo "🧭 COMPASS methodology required. Please ensure you:"
            echo "1. Query existing docs/ and maps/ for relevant patterns"
            echo "2. Apply documented approaches from previous work"
            echo "3. Identify knowledge gaps requiring investigation"  
            echo "4. Plan documentation for new discoveries"
            echo "5. Execute enhanced analysis with institutional knowledge"
            echo "6. Cross-reference findings with existing patterns"
            log "✅ COMPASS reminder provided via claude CLI fallback"
            exit 0
        else
            log "❌ No Claude CLI found - providing manual COMPASS checklist"
            echo "🧭 COMPASS Methodology Required:"
            echo "Before proceeding, you must:"
            echo "□ 1. Query Knowledge: Check docs/ and maps/ directories"  
            echo "□ 2. Apply Patterns: Use existing investigation approaches"
            echo "□ 3. Analyze Gaps: Identify what's missing from knowledge base"
            echo "□ 4. Plan Documentation: Prepare to document new findings"
            echo "□ 5. Enhanced Analysis: Execute with full context"
            echo "□ 6. Cross-Reference: Link discoveries to existing patterns"
            exit 2  # Block execution until COMPASS completed
        fi
    fi
    
    # Invoke COMPASS captain agent via Claude Code CLI
    log "Executing: claude-code --agent $COMPASS_AGENT_NAME"
    
    if timeout "$TIMEOUT" claude-code --agent "$COMPASS_AGENT_NAME" "User Request: $USER_PROMPT" 2>>"$LOG_FILE"; then
        log "✅ COMPASS methodology completed successfully"
        exit 0
    else
        local exit_code=$?
        log "❌ COMPASS enforcement failed with exit code $exit_code"
        
        if [ $exit_code -eq 124 ]; then
            log "⏰ COMPASS execution timed out after ${TIMEOUT}s"
            echo "⏰ COMPASS analysis timed out - proceeding with reduced enforcement" >&2
            exit 0  # Allow to proceed but log the timeout
        else
            echo "❌ COMPASS enforcement failed - analysis cannot proceed safely" >&2
            echo "Check $LOG_FILE for details" >&2
            exit 2  # Block execution
        fi
    fi
}

# Main logic
if [[ -z "$USER_PROMPT" ]]; then
    log "⚠️  No user prompt detected - allowing to proceed"
    exit 0
fi

if is_complex_task; then
    log "🎯 Complex analytical task detected - COMPASS methodology required"
    invoke_compass
else
    log "✅ Simple request detected - COMPASS not required"
    echo "✅ Simple request - proceeding without COMPASS" >&2
    exit 0
fi