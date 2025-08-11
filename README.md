![COMPASS Logo](assets/compass_logo.svg)

# COMPASS - Contextual Mapping & Pattern Analysis System

Why leave things to chance? Have you ever wanted your Claude Code environment to feel like a familiar friend with each iteration?

## The Motivation

I built this kit because I was tired of watching brilliant AI get lost in the same mazes, iteration after iteration. Code presents us with endless puzzles - complex async flows, tangled dependencies, performance bottlenecks that seem to appear from nowhere. Without memory, without context, even the most sophisticated LLM can spiral into needless loops, suggesting the same debugging approaches that didn't work yesterday, or missing the patterns that would illuminate the path forward.

There's something almost tragic about watching an AI rediscover the same insights over and over, like a detective who burns their case notes each night. The breakthrough you had last week becomes tomorrow's mystery all over again.

## What COMPASS Changes

COMPASS transforms Claude Code from a brilliant but forgetful assistant into something more like a seasoned colleague - one who remembers not just what you built, but *why* you built it that way. Who sees the subtle patterns that connect today's authentication bug to last month's race condition. Who builds institutional memory from every uncertainty, every investigation, every hard-won insight.

This isn't just about documentation. It's about creating a system that learns from its own limitations, that turns every "I need more information..." moment into permanent knowledge. When Claude Code hits the boundaries of what it can determine autonomously, COMPASS captures that uncertainty and transforms it into investigation frameworks for future encounters.

## How It Works

![COMPASS Workflow](assets/compass_workflow.svg)

COMPASS operates on two foundational principles:

**Memory Through Documentation**: Every significant pattern, every architectural decision, every debugging breakthrough gets captured automatically. Not as static notes, but as living documentation that connects past insights to present challenges.

**Vision Through Mapping**: Complex code flows become visual landscapes. Race conditions reveal themselves as crossing paths. Bottlenecks appear as convergence points. The abstract becomes concrete, the invisible becomes navigable.

### The Two-Directory Approach

```
docs/          # Textual institutional memory
maps/          # Visual pattern recognition
```

Your `docs/` directory evolves organically, growing smarter with each iteration. Claude Code automatically creates investigation documentation when it encounters uncertainty - those "I need more information..." moments become structured knowledge-gathering frameworks.

Your `maps/` directory captures the flows that text struggles to convey. SVG diagrams with machine-readable metadata let Claude Code recognize patterns visually, connecting similar flows across different parts of your codebase.

## The Experience

Instead of explaining the same architectural decisions repeatedly, you'll find Claude Code saying things like:

*"Looking at our async flow patterns, this creates the same race condition we documented in the auth module. The investigation map suggests checking token refresh timing..."*

Instead of reinventing debugging approaches, it becomes:

*"Based on our previous memory leak investigation, this heap growth pattern matches what we tracked in the payment processing flow. Let me update our findings..."*

Your Claude Code environment grows more knowledgeable with each interaction, building the kind of institutional memory that usually takes teams years to develop.

## Installation

### Quick Setup (2 steps)

1. **Initialize Claude Code project**:

   ```bash
   claude code /init
   ```

   Exit Claude Code after initialization

2. **Install COMPASS**:

   ```bash
   curl -s https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/CLAUDE.md >> CLAUDE.md && curl -s https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/COMPASS.md > COMPASS.md
   ```

Your Claude Code environment now has COMPASS capabilities and will automatically initialize the `docs/` and `maps/` directories on first complex analysis.

## Serena Integration

**COMPASS is significantly more powerful with Serena** - a local toolset that gives Claude Code fast access to your filesystem through `grep`, `find`, and other essential commands. Without Serena, Claude Code can't efficiently navigate your codebase or build the comprehensive maps that make COMPASS truly effective.

Serena transforms Claude Code from a text-processing tool into a genuine development partner that can:

- **Search your entire codebase** instantly with `grep`
- **Navigate file structures** efficiently with `find`
- **Analyze patterns across files** without token-heavy file loading
- **Build comprehensive maps** based on actual code relationships

**Project**: <https://github.com/oraios/serena>

### Installing Serena

1. **Start Serena MCP server**:

   ```bash
   uvx --from git+https://github.com/oraios/serena serena start-mcp-server --transport sse --port 9121
   ```

2. **Connect Claude Code to Serena**:

   ```bash
   claude mcp add serena --transport sse http://localhost:9121/sse
   ```

With Serena installed, restart Claude Code in your project. You now have the complete COMPASS system with full local file intelligence.

## The Philosophy

COMPASS embodies a simple belief: that every challenge overcome should make the next challenge easier. That uncertainty should transform into knowledge. That the mazes we navigate today should become the maps that guide us tomorrow.

Because why leave things to chance when you can leave things to memory?

---

*"The path through complexity isn't about avoiding the maze - it's about building better maps."*
