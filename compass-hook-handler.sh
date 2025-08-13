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