#!/usr/bin/env python3
"""
COMPASS Background Service
Handles comprehensive state management outside the hook process
"""

import json
import time
import signal
import sys
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, deque
import threading
import os

class CompassBackgroundService:
    def __init__(self):
        self.running = True
        
        # Ensure .compass/logs directory exists
        self.logs_dir = Path(".compass/logs")
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        
        # All files go in .compass/logs
        self.event_queue = self.logs_dir / "compass-events.queue"
        self.pid_file = self.logs_dir / "compass-service.pid"
        self.state_file = self.logs_dir / "compass-state.json"
        
        # In-memory state (bounded)
        self.token_tracking = defaultdict(int)
        self.agent_activity = deque(maxlen=1000)  # Last 1000 events
        self.session_start = datetime.now()
        self.last_cleanup = datetime.now()
        self.phase_status = {}
        
        # Set up signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self.shutdown)
        signal.signal(signal.SIGINT, self.shutdown)
    
    def start(self):
        """Start the background service"""
        try:
            # Write PID file
            with open(self.pid_file, 'w') as f:
                f.write(str(os.getpid()))
            
            self.log_info("COMPASS Background Service started")
            
            # Main service loop
            while self.running:
                self.process_events()
                self.update_status()
                self.periodic_cleanup()
                time.sleep(1)  # Process every second
                
        except Exception as e:
            self.log_error(f"Service error: {e}")
        finally:
            self.cleanup_and_exit()
    
    def process_events(self):
        """Process events from the queue"""
        if not self.event_queue.exists():
            return
        
        try:
            # Read all events atomically
            with open(self.event_queue, 'r') as f:
                lines = f.readlines()
            
            # Clear the queue after reading
            self.event_queue.unlink()
            
            # Process each event
            for line in lines:
                try:
                    event = json.loads(line.strip())
                    self.handle_event(event)
                except json.JSONDecodeError:
                    continue
                    
        except (FileNotFoundError, PermissionError):
            pass
    
    def handle_event(self, event):
        """Handle individual events"""
        event_type = event.get("event_type", "")
        data = event.get("data", {})
        timestamp = event.get("timestamp", "")
        
        # Track agent activity
        if event_type == "PreToolUse":
            tool_name = data.get("tool_name", "")
            tool_input = data.get("tool_input", {})
            
            # Check for COMPASS agent usage
            if tool_name == "Task":
                subagent_type = tool_input.get("subagent_type", "")
                if subagent_type.startswith("compass-"):
                    self.track_agent_activity(subagent_type, tool_input, timestamp)
        
        elif event_type == "UserPromptSubmit":
            prompt = data.get("prompt", "")
            self.analyze_prompt_complexity(prompt)
        
        # Add to activity log (bounded deque)
        self.agent_activity.append({
            "timestamp": timestamp,
            "type": event_type,
            "summary": self.summarize_event(event)
        })
        
        self.log_info(f"Processed event: {event_type}")
    
    def track_agent_activity(self, agent_type, tool_input, timestamp):
        """Track COMPASS agent activity and estimate tokens"""
        prompt = tool_input.get("prompt", "")
        
        # Token estimation with agent-specific multipliers
        base_tokens = len(prompt) // 4  # 4 chars per token estimate
        
        multipliers = {
            "compass-captain": 1.2,
            "compass-knowledge-query": 1.5,
            "compass-pattern-apply": 1.3,
            "compass-gap-analysis": 1.4,
            "compass-enhanced-analysis": 2.0,
            "compass-cross-reference": 1.6,
            "compass-data-flow": 1.5,
            "compass-doc-planning": 1.1,
            "compass-coder": 1.8
        }
        
        multiplier = multipliers.get(agent_type, 1.0)
        estimated_tokens = int(base_tokens * multiplier)
        
        # Update tracking
        self.token_tracking[agent_type] += estimated_tokens
        self.token_tracking["total"] += estimated_tokens
        
        # Update phase tracking
        phase = self.map_agent_to_phase(agent_type)
        if phase:
            self.update_compass_phase(phase, "in_progress", agent_type)
        
        self.log_info(f"Token tracking: {agent_type} +{estimated_tokens} tokens")
    
    def map_agent_to_phase(self, agent_type):
        """Map agent to COMPASS phase"""
        phase_mapping = {
            "compass-captain": "coordination",
            "compass-knowledge-query": "phase1_knowledge_query",
            "compass-pattern-apply": "phase2_pattern_application",
            "compass-gap-analysis": "phase3_gap_analysis",
            "compass-doc-planning": "phase4_documentation",
            "compass-enhanced-analysis": "phase5_enhanced_analysis",
            "compass-cross-reference": "phase6_cross_reference",
            "compass-data-flow": "analysis_data_flow",
            "compass-coder": "execution_bridge"
        }
        return phase_mapping.get(agent_type)
    
    def analyze_prompt_complexity(self, prompt):
        """Background tracking only - no complexity triggers"""
        # Background service just logs prompts for tracking
        # All complexity analysis happens in compass-methodology-selector
        self.log_info(f"Prompt received for tracking: {prompt[:50]}...")
    
    def create_compass_status_file(self):
        """Create COMPASS status file when compass-captain activates"""
        compass_dir = Path(".compass")
        status_file = compass_dir / "status"
        
        if status_file.exists():
            return  # Already exists
        
        status_content = f"""🧭 COMPASS METHODOLOGY ACTIVE
═══════════════════════════════════════════════════════════════

COMPASS-CAPTAIN COORDINATING: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

Strategic methodology selection in progress via compass-methodology-selector

┌─ ADAPTIVE COORDINATION ─────────────────────────────────────┐
│ compass-captain → compass-methodology-selector → execution   │
│ Methodology will be: light/medium/full (TBD by analysis)    │
└─────────────────────────────────────────────────────────────┘

🎯 STATUS: compass-captain determining optimal approach
📊 TOKEN TRACKING: Real-time monitoring active
⚡ BACKGROUND SERVICE: Processing coordination events

📁 DIRECTORIES:
   docs/  - Institutional memory and investigation frameworks
   maps/  - Visual pattern recognition and architectural diagrams
   
═══════════════════════════════════════════════════════════════
🔄 This file updates as compass-captain coordinates methodology
💰 Token usage tracked in real-time by background service
"""
        
        try:
            with open(status_file, "w") as f:
                f.write(status_content)
            
            self.log_info("Created COMPASS status file for compass-captain coordination")
            
        except OSError as e:
            self.log_error(f"Failed to create status file: {e}")
    
    def update_compass_phase(self, phase, status, agent_type):
        """Update COMPASS phase progress"""
        compass_dir = Path(".compass")
        status_file = compass_dir / "status"
        
        if not status_file.exists():
            return
        
        try:
            with open(status_file, "r") as f:
                content = f.read()
            
            # Update phase tracking
            self.phase_status[phase] = {
                "status": status,
                "agent": agent_type,
                "updated": datetime.now().isoformat()
            }
            
            # Update phase checkboxes
            phase_mappings = {
                "phase1_knowledge_query": "Knowledge Query",
                "phase2_pattern_application": "Pattern Application",
                "phase3_gap_analysis": "Gap Analysis", 
                "phase4_documentation": "Documentation",
                "phase5_enhanced_analysis": "Enhanced Analysis",
                "phase6_cross_reference": "Cross-Reference"
            }
            
            if phase in phase_mappings:
                phase_name = phase_mappings[phase]
                symbol = "🔄" if status == "in_progress" else "✓" if status == "completed" else "□"
                
                # Replace the checkbox for this phase
                old_pattern = f"│ [□✓🔄] {phase_name}"
                new_line = f"│ {symbol} {phase_name}"
                content = content.replace(old_pattern, new_line)
            
            # Update timestamp
            content = content.replace(
                "COMPLEX ANALYTICAL TASK DETECTED: " + content.split("COMPLEX ANALYTICAL TASK DETECTED: ")[1].split("\n")[0],
                f"COMPLEX ANALYTICAL TASK DETECTED: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            )
            
            with open(status_file, "w") as f:
                f.write(content)
                
            self.log_info(f"Updated phase: {phase} -> {status}")
                
        except (OSError, FileNotFoundError, IndexError) as e:
            self.log_error(f"Failed to update phase: {e}")
    
    def update_status(self):
        """Update comprehensive status information"""
        if not self.token_tracking or self.token_tracking.get("total", 0) == 0:
            return
        
        # Update token information in status file
        self.update_token_status()
        
        # Save state to file for persistence
        self.save_state()
    
    def update_token_status(self):
        """Update token usage information in status file"""
        if not Path(".compass-status").exists():
            return
        
        try:
            total_tokens = self.token_tracking.get("total", 0)
            
            with open(".compass-status", "r") as f:
                content = f.read()
            
            # Create token usage section
            top_agents = sorted(
                [(k, v) for k, v in self.token_tracking.items() if k != "total"],
                key=lambda x: x[1], reverse=True
            )[:5]  # Top 5 agents
            
            agent_breakdown = "\n".join([
                f"   • {agent}: {tokens} tokens" 
                for agent, tokens in top_agents
            ])
            
            token_info = f"""
📊 TOKEN USAGE (Real-time):
   • Session Total: {total_tokens} tokens
   • Estimated Cost: ~${total_tokens * 0.00001:.4f}
   • Session Duration: {self.get_session_duration()}
   • Active Agents: {len([k for k, v in self.token_tracking.items() if k != "total" and v > 0])}

⚡ TOP AGENTS:
{agent_breakdown}

🔄 BACKGROUND SERVICE: Processing events efficiently
"""
            
            # Replace or add token section
            if "📊 TOKEN USAGE" in content:
                # Find and replace existing token section
                lines = content.split("\n")
                new_lines = []
                in_token_section = False
                
                for line in lines:
                    if "📊 TOKEN USAGE" in line:
                        in_token_section = True
                        new_lines.extend(token_info.strip().split("\n"))
                    elif in_token_section and line.startswith(("   •", "⚡", "🔄")):
                        continue  # Skip old token section lines
                    elif in_token_section and line.strip() == "":
                        continue  # Skip empty lines in token section
                    elif in_token_section and not line.startswith(("   ", "⚡", "🔄")):
                        in_token_section = False
                        new_lines.append(line)
                    else:
                        new_lines.append(line)
                
                content = "\n".join(new_lines)
            else:
                # Add new section before closing border
                insertion_point = "═══════════════════════════════════════════════════════════════\n🔄"
                content = content.replace(
                    insertion_point,
                    token_info + "\n" + insertion_point
                )
            
            with open(".compass-status", "w") as f:
                f.write(content)
                
        except (OSError, FileNotFoundError) as e:
            self.log_error(f"Failed to update token status: {e}")
    
    def get_session_duration(self):
        """Get human-readable session duration"""
        duration = datetime.now() - self.session_start
        hours = int(duration.total_seconds() // 3600)
        minutes = int((duration.total_seconds() % 3600) // 60)
        
        if hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    
    def save_state(self):
        """Save current state to file for persistence"""
        state = {
            "session_start": self.session_start.isoformat(),
            "token_tracking": dict(self.token_tracking),
            "phase_status": self.phase_status,
            "last_updated": datetime.now().isoformat(),
            "total_events_processed": len(self.agent_activity)
        }
        
        try:
            with open(self.state_file, "w") as f:
                json.dump(state, f, separators=(',', ':'))
        except OSError:
            pass
    
    def periodic_cleanup(self):
        """Perform periodic cleanup"""
        now = datetime.now()
        
        # Cleanup every 15 minutes
        if now - self.last_cleanup > timedelta(minutes=15):
            self.cleanup_old_files()
            self.cleanup_memory()
            self.last_cleanup = now
    
    def cleanup_old_files(self):
        """Clean up old files"""
        # Clean up temporary files in .compass directory
        compass_dir = Path(".compass")
        cleanup_files_compass = [
            ("complete", timedelta(hours=1)),
            ("todo-updates", timedelta(hours=2))
        ]
        
        for filename, max_age in cleanup_files_compass:
            file_path = compass_dir / filename
            if file_path.exists():
                try:
                    file_age = datetime.now() - datetime.fromtimestamp(
                        file_path.stat().st_mtime
                    )
                    if file_age > max_age:
                        file_path.unlink()
                        self.log_info(f"Cleaned up old file: {filename}")
                except OSError:
                    pass
        
        # Clean up files in logs directory
        cleanup_files_logs = [
            ("compass-events.queue.backup", timedelta(days=1))
        ]
        
        for filename, max_age in cleanup_files_logs:
            file_path = self.logs_dir / filename
            if file_path.exists():
                try:
                    file_age = datetime.now() - datetime.fromtimestamp(
                        file_path.stat().st_mtime
                    )
                    if file_age > max_age:
                        file_path.unlink()
                        self.log_info(f"Cleaned up old log file: {filename}")
                except OSError:
                    pass
    
    def cleanup_memory(self):
        """Clean up in-memory structures"""
        # Reset token tracking if session is very old
        session_age = datetime.now() - self.session_start
        if session_age > timedelta(hours=8):
            # Archive current session and reset
            self.archive_session()
            self.token_tracking.clear()
            self.session_start = datetime.now()
            self.log_info("Reset session due to age")
    
    def archive_session(self):
        """Archive current session data"""
        archive_file = self.logs_dir / "compass-sessions.archive"
        
        session_summary = {
            "session_start": self.session_start.isoformat(),
            "session_end": datetime.now().isoformat(),
            "total_tokens": self.token_tracking.get("total", 0),
            "top_agents": dict(sorted(
                [(k, v) for k, v in self.token_tracking.items() if k != "total"],
                key=lambda x: x[1], reverse=True
            )[:10]),
            "total_events": len(self.agent_activity)
        }
        
        try:
            # Load existing archive
            if archive_file.exists():
                with open(archive_file, "r") as f:
                    archive = json.load(f)
            else:
                archive = {"sessions": []}
            
            # Add current session
            archive["sessions"].append(session_summary)
            
            # Keep only last 50 sessions
            if len(archive["sessions"]) > 50:
                archive["sessions"] = archive["sessions"][-50:]
            
            # Save archive
            with open(archive_file, "w") as f:
                json.dump(archive, f, separators=(',', ':'))
                
            self.log_info("Archived session data")
            
        except OSError as e:
            self.log_error(f"Failed to archive session: {e}")
    
    def summarize_event(self, event):
        """Create summary of event for logging"""
        event_type = event.get("event_type", "")
        data = event.get("data", {})
        
        if event_type == "PreToolUse":
            tool_name = data.get("tool_name", "")
            tool_input = data.get("tool_input", {})
            subagent = tool_input.get("subagent_type", "")
            
            if subagent:
                return f"Tool: {tool_name}, Agent: {subagent}"
            else:
                return f"Tool: {tool_name}"
                
        elif event_type == "UserPromptSubmit":
            prompt = data.get("prompt", "")
            return f"Prompt: {prompt[:50]}..."
        
        return event_type
    
    def log_info(self, message):
        """Log info message"""
        self.log_message("INFO", message)
    
    def log_error(self, message):
        """Log error message"""
        self.log_message("ERROR", message)
    
    def log_message(self, level, message):
        """Log message to file with rotation"""
        log_file = self.logs_dir / "compass-service.log"
        
        try:
            # Rotate log if too large (5MB)
            if log_file.exists() and log_file.stat().st_size > 5 * 1024 * 1024:
                old_log = self.logs_dir / "compass-service.log.old"
                if old_log.exists():
                    old_log.unlink()
                log_file.rename(old_log)
            
            # Write log entry
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with open(log_file, "a") as f:
                f.write(f"{timestamp} [{level}] {message}\n")
                
        except OSError:
            pass  # Fail silently if logging fails
    
    def shutdown(self, signum, frame):
        """Graceful shutdown"""
        self.log_info("Received shutdown signal")
        self.running = False
    
    def cleanup_and_exit(self):
        """Cleanup and exit"""
        try:
            self.save_state()
            
            if self.pid_file.exists():
                self.pid_file.unlink()
                
            self.log_info("COMPASS Background Service stopped")
            
        except OSError:
            pass

if __name__ == "__main__":
    service = CompassBackgroundService()
    service.start()
