# COMPASS - Contextual Mapping & Pattern Analysis System

## The Hook: Why Leave Things to Chance?

Have you ever wanted your [Claude Code](https://github.com/anthropics/claude-code) environment to feel like a familiar friend with each session?

I built this kit because I was tired of watching brilliant AI get lost in the same mazes, iteration after iteration. Code presents us with endless puzzles - complex async flows, tangled dependencies, performance bottlenecks that seem to appear from nowhere. Without memory, without context, even the most sophisticated LLM can spiral into needless loops, suggesting the same debugging approaches that didn't work yesterday, or missing the patterns that would illuminate the path forward.

There's something almost tragic about watching an AI rediscover the same insights over and over, like a detective who burns their case notes each night. The breakthrough you had last week becomes tomorrow's mystery all over again.

## The Solution: What COMPASS Changes

COMPASS transforms Claude Code from a brilliant but forgetful assistant into something more like a seasoned colleague - one who remembers not just what you built, but *why* you built it that way. Who sees the subtle patterns that connect today's authentication bug to last month's race condition. Who builds institutional memory from every uncertainty, every investigation, every hard-won insight.

This isn't just about documentation. It's about creating a system that learns from its own limitations, that turns every "I need more information..." moment into permanent knowledge. When Claude Code hits the boundaries of what it can determine autonomously, COMPASS captures that uncertainty and transforms it into investigation frameworks for future encounters.

### What This Means For You

Instead of Claude Code starting fresh every time, COMPASS automatically:

1. **Remembers Previous Work** - Checks what you've already discovered about similar problems
2. **Applies Proven Patterns** - Uses approaches that worked before instead of reinventing solutions
3. **Identifies What's Missing** - Spots knowledge gaps that need investigation
4. **Provides Context-Rich Analysis** - Gives you answers informed by your project's history
5. **Builds Institutional Memory** - Captures everything for future use

**The result?** Your Claude Code environment becomes smarter with every interaction, like having a senior developer who never forgets lessons learned.

COMPASS operates on two foundational principles:

**Memory Through Documentation**: Every significant pattern, every architectural decision, every debugging breakthrough gets captured automatically. Not as static notes, but as living documentation that connects past insights to present challenges.

**Vision Through Mapping**: Complex code flows become visual landscapes. Race conditions reveal themselves as crossing paths. Bottlenecks appear as convergence points. The abstract becomes concrete, the invisible becomes navigable.

## Performance Optimization: Direct Function Architecture

COMPASS has been optimized with a high-performance direct function architecture that eliminates system lockups and provides near-instantaneous knowledge queries:

- **Direct Function Calls**: Knowledge queries now use direct Python function calls instead of agent overhead
- **Eliminated System Lockups**: No more memory crashes from parallel agent execution conflicts
- **Sub-Second Performance**: Cached knowledge queries return in <0.1 seconds
- **Memory Safety Preserved**: All file size limits, content truncation, and subprocess isolation maintained
- **Backward Compatibility**: Existing workflows continue to work while benefiting from performance improvements

The compass-knowledge-query system now operates as a streamlined direct function in `.compass/handlers/compass-handler.py`, providing the same institutional memory capabilities with dramatically improved reliability and speed.

### Quick Start with COMPASS

Instead of the standard installation, use the enhanced COMPASS launcher:

```sh
# Clone or download compass.sh
curl -O https://raw.githubusercontent.com/odysseyalive/claude-compass/main/compass.sh
chmod +x compass.sh

# Launch with automatic COMPASS + Serena MCP integration
./compass.sh
```

The COMPASS launcher automatically:
1. **Updates COMPASS**: Pulls latest methodology components from repository
2. **Memory Optimization**: Allocates 50% of system RAM (15.4GB on 31GB systems) 
3. **Serena MCP Server**: Automatic startup, health monitoring, and Claude registration
4. **Claude Code Management**: Installs/updates via uvx with dependency resolution
5. **Project Initialization**: Handles `.claude` directory setup and configuration
6. **Integrated Launch**: Starts Claude with optimized memory and all MCP integrations active

### Memory Optimization Details

COMPASS automatically detects and optimizes memory allocation to prevent the common 4GB JavaScript heap crashes:

- **Dynamic Detection**: Reads system memory from `/proc/meminfo` (Linux), `sysctl` (macOS), PowerShell (Windows)
- **Safe Allocation**: Uses 50% of available RAM with intelligent ceiling (max 15.4GB)
- **V8 Optimization**: Sets `NODE_OPTIONS="--max-old-space-size=X"` before Claude startup
- **Process Isolation**: Prevents memory conflicts with other applications and containers

### Serena MCP Integration Features

The Serena integration provides advanced semantic code analysis:

- **Automatic Server Management**: Starts `uvx --from git+https://github.com/oraios/serena serena start-mcp-server`
- **Health Monitoring**: Regular endpoint checks with automatic recovery
- **Port Detection**: Smart port allocation starting from 9121
- **Claude Registration**: Automatic `claude mcp add serena --transport sse http://localhost:9121/sse`
- **Background Processing**: Non-blocking execution with signal handling
- **Graceful Fallback**: Continues normally if Serena dependencies unavailable

**Learn more in the [official documentation](https://docs.anthropic.com/en/docs/claude-code/overview)**.

<img src="./demo.gif" />

## Installation Options

### Option 1: COMPASS Enhanced (Recommended)

For the full COMPASS experience with memory optimization and Serena integration:

```sh
# Download and run the unified launcher
curl -O https://raw.githubusercontent.com/odysseyalive/claude-compass/main/compass.sh
chmod +x compass.sh
./compass.sh
```

### Option 2: Standard Installation

1. Install Claude Code:

```sh
npm install -g @anthropic-ai/claude-code
```

2. Navigate to your project directory and run `claude`.

### System Requirements

**Minimum:**
- Node.js 18+
- 8GB system RAM
- Git (for COMPASS integration)

**Recommended for COMPASS:**
- 16GB+ system RAM for optimal memory allocation
- Python 3.8+ for methodology execution
- uvx for Serena MCP integration (`pip install uvx`)

### Troubleshooting

**Memory Issues:**
```sh
# Check current allocation
echo $NODE_OPTIONS

# Manual memory override
export NODE_OPTIONS="--max-old-space-size=15360"
claude
```

**Serena Integration Issues:**
```sh
# Check server status
curl -f http://localhost:9121/health

# Restart with Serena disabled
COMPASS_DISABLE_SERENA=1 ./compass.sh
```

## Reporting Bugs

We welcome your feedback. Use the `/bug` command to report issues directly within Claude Code, or file a [GitHub issue](https://github.com/anthropics/claude-code/issues).

## Data collection, usage, and retention

When you use Claude Code, we collect feedback, which includes usage data (such as code acceptance or rejections), associated conversation data, and user feedback submitted via the `/bug` command.

### How we use your data

We may use feedback to improve our products and services, but we will not train generative models using your feedback from Claude Code. Given their potentially sensitive nature, we store user feedback transcripts for only 30 days.

If you choose to send us feedback about Claude Code, such as transcripts of your usage, Anthropic may use that feedback to debug related issues and improve Claude Code's functionality (e.g., to reduce the risk of similar bugs occurring in the future).

### Privacy safeguards

We have implemented several safeguards to protect your data, including limited retention periods for sensitive information, restricted access to user session data, and clear policies against using feedback for model training.

For full details, please review our [Commercial Terms of Service](https://www.anthropic.com/legal/commercial-terms) and [Privacy Policy](https://www.anthropic.com/legal/privacy).
