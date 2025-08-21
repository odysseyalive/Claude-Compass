# Claude Code

![](https://img.shields.io/badge/Node.js-18%2B-brightgreen?style=flat-square) [![npm]](https://www.npmjs.com/package/@anthropic-ai/claude-code)

[npm]: https://img.shields.io/npm/v/@anthropic-ai/claude-code.svg?style=flat-square

Claude Code is an agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster by executing routine tasks, explaining complex code, and handling git workflows -- all through natural language commands. Use it in your terminal, IDE, or tag @claude on Github.

## COMPASS Enhanced Experience

This repository includes the [COMPASS methodology integration](https://github.com/odysseyalive/claude-compass) which provides:

- **Institutional Knowledge Management**: Automatic documentation and pattern recognition
- **Memory-Optimized Execution**: Automatic allocation of 50% system RAM to prevent 4GB heap crashes
- **Serena MCP Integration**: Seamless semantic code analysis with automatic server management
- **Systematic Methodology**: Six-step structured approach with specialized agent coordination
- **Background Process Management**: Health monitoring and graceful cleanup of integrated services

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
