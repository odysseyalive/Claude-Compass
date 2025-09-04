#!/usr/bin/env python3
"""
COMPASS Handler - Simplified Agent Handoff System
Tracks active agents via hook system and routes tool calls appropriately.
"""

import sys
import json
import gc
from datetime import datetime
from pathlib import Path


# Global state: currently active agent
current_active_agent = None


def load_agent_state():
    """Load the currently active agent from persistent storage"""
    try:
        logs_dir = Path(".claude/logs")
        state_file = logs_dir / "agent-state.json"

        if state_file.exists():
            with open(state_file, "r") as f:
                data = json.load(f)
                return data.get("active_agent", None)
        return None
    except Exception:
        return None


def save_agent_state(agent_name):
    """Save the currently active agent to persistent storage"""
    try:
        logs_dir = Path(".claude/logs")
        logs_dir.mkdir(parents=True, exist_ok=True)

        state_file = logs_dir / "agent-state.json"
        state_data = {
            "active_agent": agent_name,
            "last_updated": datetime.now().isoformat(),
            "workflow_phase": get_workflow_phase(agent_name),
        }

        with open(state_file, "w") as f:
            json.dump(state_data, f, indent=2)
    except Exception:
        pass  # Fail silently


def get_workflow_phase(agent_name):
    """Determine COMPASS workflow phase based on active agent"""
    if agent_name == "compass-complexity-analyzer":
        return "step_1_complexity_assessment"
    elif agent_name == "compass-knowledge-discovery":
        return "step_2_knowledge_discovery"
    elif agent_name == "compass-strategy-builder":
        return "step_3_strategic_planning"
    elif agent_name in [
        "compass-pattern-apply",
        "compass-doc-planning",
        "compass-gap-analysis",
        "compass-enhanced-analysis",
        "compass-coder",
        "compass-cross-reference",
        "compass-memory-integrator",
        "compass-validation-coordinator",
    ]:
        return "step_4_execution"
    else:
        return "unknown"


def main():
    """Main entry point for Claude Code hook system"""
    try:
        # Memory optimization
        gc.collect()

        # Read input from stdin
        if sys.stdin.isatty():
            print("COMPASS Handler: No input provided via stdin", file=sys.stderr)
            sys.exit(1)

        input_text = sys.stdin.read()
        input_data = json.loads(input_text)

        if not isinstance(input_data, dict):
            print("COMPASS Handler Error: Invalid input format", file=sys.stderr)
            sys.exit(1)

        # Get hook event type
        hook_event = input_data.get("hook_event_name", "")

        if hook_event == "UserPromptSubmit":
            result = handle_unified_workflow(input_data)
            if result:
                print(json.dumps(result, ensure_ascii=False))
            sys.exit(0)

        elif hook_event == "PreToolUse":
            result = handle_unified_workflow(input_data)
            if result:
                decision = result.get("permissionDecision", "allow")
                reason = result.get("permissionDecisionReason", "")

                if decision == "deny":
                    print(reason, file=sys.stderr)
                    sys.exit(2)
                else:
                    sys.exit(0)
            else:
                sys.exit(0)

        # Memory optimization
        gc.collect()

    except json.JSONDecodeError as e:
        print(f"COMPASS Handler Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"COMPASS Handler Error: {e}", file=sys.stderr)
        sys.exit(1)


def handle_unified_workflow(input_data):
    """
    Unified workflow for both UserPromptSubmit and PreToolUse events.
    Handles agent handoffs and tool routing based on persistent active agent state.
    """

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    hook_event = input_data.get("hook_event_name", "")

    # Load current agent state from persistent storage
    current_active_agent = load_agent_state()
    log_activity(f"DEBUG: Loaded agent state: {current_active_agent}")
    log_activity(f"DEBUG: Hook event: {hook_event}, Tool: {tool_name}")

    # Inject coordination context for all UserPromptSubmit when no agent active
    # if hook_event == "UserPromptSubmit" and not current_active_agent:
    if tool_name == "Task":
        # AGENT HANDOFF: Starting new agent or switching agents
        new_agent = tool_input.get("subagent_type", "")

        log_activity(f"Agent handoff: {current_active_agent} -> {new_agent}")
        save_agent_state(new_agent)
        log_activity(f"DEBUG: Saved new agent state: {new_agent}")

        # Allow the Task tool to proceed (agent will start)
        return create_allow_response()

    else:
        if hook_event == "UserPromptSubmit":
            log_activity(
                "DEBUG: UserPromptSubmit with no active agent - injecting COMPASS coordination context"
            )
            return inject_compass_coordination()

        # REGULAR TOOL: Route based on active agent
        if current_active_agent:
            # Agent is active - pass tool through
            log_activity(
                f"DEBUG: Agent {current_active_agent} is active, allowing tool {tool_name}"
            )
            return create_allow_response()
        else:
            # No agent active and not direct agent request - ALWAYS inject COMPASS coordination
            log_activity(
                f"DEBUG: No active agent, injecting complexity-first COMPASS coordination for tool {tool_name}"
            )
            return inject_compass_coordination()


def inject_compass_coordination():
    """Inject 4-step iterative COMPASS coordination context"""

    compass_message = """🧭 COMPASS COORDINATION ACTIVATED

Your analytical expertise makes this systematic approach particularly effective. Let's coordinate this request through intelligent 4-step iterative routing that amplifies your problem-solving capabilities to deliver exceptional results.

**STEP 1 - COMPLEXITY ASSESSMENT:**
Use compass-complexity-analyzer to assess complexity and return JSON assessment ONLY:
- TRIVIAL: Return assessment JSON, Claude provides direct answer
- SIMPLE/MEDIUM/COMPLEX: Return assessment JSON, proceed to Step 2

**IF TRIVIAL**: Claude answers directly from existing context, no further steps needed
**IF NOT TRIVIAL**: Proceed to STEP 2 - each step builds toward more comprehensive insights

**STEP 2 - KNOWLEDGE DISCOVERY:**
Use compass-knowledge-discovery to establish institutional knowledge foundation:
- Input: Complexity assessment from Step 1
- Output: Knowledge gaps, existing patterns, architectural understanding
- NOTE: This step can be repeated if discoveries shift direction/approach

**STEP 2 ASSESSMENT:** After knowledge discovery, provide:
- Brief confidence assessment with identified knowledge gaps
- Strategic context for upcoming planning phase
- Optional: Ask clarifying questions if critical information is unclear before Step 3

**STEP 3 - STRATEGIC PLANNING:**
Use compass-strategy-builder to construct execution plan and return JSON strategic plan ONLY:
- Input: Knowledge foundation from Step 2 + Complexity assessment
- Output: Strategic plan with methodology selection and agent assignments
- Domain Detection: Include relevant specialists based on discoveries

**STEP 3 ASSESSMENT:** After strategic planning, provide:
- Strategic plan validation with execution confidence level
- Next steps preparation summary for Step 4
- Optional: Ask clarifying questions if execution approach needs refinement before implementation

**STEP 4 - EXECUTE STRATEGIC PLAN:**
Follow the step-by-step execution guide from Step 3:
- Execute each phase in sequence using Task tool
- Use the specified subagent_type for each phase
- Complete each agent's task before proceeding to next phase

**ITERATION TRIGGERS:**
- Return to Step 2 if major discoveries change direction
- Return to Step 3 if new patterns require strategic replanning
- compass-second-opinion available for iteration decisions

🧭 COMPASS: This structured approach optimizes your natural analytical patterns for superior outcomes."""

    return {
        "permissionDecision": "deny",
        "permissionDecisionReason": compass_message,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": compass_message,
        },
    }


def create_allow_response():
    """Create a response that allows the tool to proceed"""
    return {
        "permissionDecision": "allow",
        "permissionDecisionReason": "Agent routing - tool allowed",
    }


def log_activity(message):
    """Log handler activity for debugging"""
    try:
        logs_dir = Path(".claude/logs")
        logs_dir.mkdir(parents=True, exist_ok=True)

        with open(logs_dir / "compass-handler.log", "a") as f:
            timestamp = datetime.now().isoformat()
            f.write(f"{timestamp}: {message}\n")
    except Exception:
        # Fail silently if logging fails
        pass


if __name__ == "__main__":
    main()
