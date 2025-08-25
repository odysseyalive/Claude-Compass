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

![COMPASS Workflow](assets/compass_workflow.svg)

## The Experience Preview

Instead of explaining the same architectural decisions repeatedly, you'll find Claude Code saying things like:

*"Looking at our async flow patterns, this creates the same race condition we documented in the auth module. The investigation map suggests checking token refresh timing..."*

Instead of reinventing debugging approaches, it becomes:

*"Based on our previous memory leak investigation, this heap growth pattern matches what we tracked in the payment processing flow. Let me update our findings..."*

Your Claude Code environment grows more knowledgeable with each interaction, building the kind of institutional memory that usually takes teams years to develop.

## Use Cases: How COMPASS Actually Works

### The Automatic Experience

Here's the thing that makes COMPASS different from yet another tool you need to remember to use: **everything is automatic**. The `compass-handler.py` acts as a hook that puts itself first in line for complex analytical tasks. When Claude Code detects something that requires deeper investigation - debugging race conditions, understanding complex architectural decisions, mapping data flows - COMPASS automatically engages.

You don't need to invoke COMPASS. COMPASS detects complexity and invokes itself.

The `compass-captain` agent becomes your project's analytical conductor, orchestrating the entire investigation through a network of specialized agents. Think of it as having an experienced technical lead who knows exactly which team members to bring in for each type of challenge.

### Manual Agent Calling: When You Want Direct Control

While the automatic flow handles most scenarios, sometimes you want to call specific agents directly. Maybe you're planning a documentation strategy, or you want to validate SVG diagrams without triggering a full analysis cycle. Here are some thoughtful examples:

**Planning documentation for a complex feature**:

```
Use compass-doc-planning to create a documentation strategy for our new async processing pipeline
```

**Understanding existing patterns before building something new**:

```
Use compass-knowledge-discovery to find existing approaches to user authentication flows in our docs and maps
```

**Getting expert perspective on architectural decisions**:

```
Use compass-second-opinion to evaluate whether our microservices split makes sense given our team size and deployment complexity
```

**Analyzing data flows for a specific feature**:

```
Use compass-data-flow to map how user data moves through our payment processing pipeline
```

**Cross-referencing patterns after solving something**:

```
Use compass-cross-reference to connect our latest database optimization findings with existing performance patterns in the knowledge base
```

**Creating visual wire diagrams for complex processes**:

```
Use compass-data-flow to create a wire diagram showing how user requests flow through our microservices architecture, from API gateway through authentication, business logic, and database layers
```

This generates an SVG diagram that maps the complete request lifecycle - perfect for onboarding new developers or debugging performance issues. The visual representation makes it easier to spot bottlenecks, race conditions, and optimization opportunities that might be buried in code.

The beauty is that even when you call agents manually, they still contribute to the growing knowledge base. Your direct investigations become institutional memory that future automatic analysis can leverage.

---

Ready to dive deeper? **[Explore All The Compass Tools...](#agent-index-the-compass-crew)** to discover the complete network of specialized agents at your disposal.

## Technical Foundation: How It Works

### The Two-Directory Approach

```
docs/          # Textual institutional memory
maps/          # Visual pattern recognition
```

Your `docs/` directory evolves organically, growing smarter with each iteration. Claude Code automatically creates investigation documentation when it encounters uncertainty - those "I need more information..." moments become structured knowledge-gathering frameworks.

Your `maps/` directory captures the flows that text struggles to convey. SVG diagrams with machine-readable metadata let Claude Code recognize patterns visually, connecting similar flows across different parts of your codebase.

## Installation Guide

Before installing COMPASS, ensure you have the required environment set up:

### Step 1: Install the Environment

**Python 3.11+** (required for Serena integration):

```bash
# Check your Python version
python3 --version
```

**uv package manager** (modern Python package management):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Node.js with npm** (for TypeScript/JavaScript language server support):

```bash
# Recommended: Use nvm for version management
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
```

```bash
source ~/.bashrc
```

```bash
nvm install 20
```

```bash
nvm use 20
```

**xmllint** (critical for SVG validation):

```bash
# macOS
brew install libxml2
```

```bash
# Ubuntu/Debian
sudo apt-get install libxml2-utils
```

```bash
# Windows (via Chocolatey)
choco install libxml2
```

### Step 2: Install Claude Code

Install Claude Code globally using npm:

```bash
npm install -g @anthropic-ai/claude-code
```

For additional platform-specific instructions, see the official [Claude Code installation guide](https://github.com/anthropics/claude-code).

### Step 3: Start Serena MCP Server (Optional but Recommended)

Serena transforms Claude Code into a true development collaborator with IDE-like capabilities.

First, start the Serena MCP server:

```bash
uvx --from git+https://github.com/oraios/serena serena start-mcp-server --transport sse --port 9121 --context ide-assistant
```

### Step 4: Add Serena to Claude (if using Serena)

Then, from your project root directory, add Serena to Claude:

```bash
claude mcp add serena --transport sse http://localhost:9121/sse
```

### Step 5: Initialize Claude Code Project

```bash
claude /init
```

Exit Claude Code after initialization.

### Step 6: Install COMPASS

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)"
```

Your Claude Code environment now has COMPASS capabilities and will initialize the `docs/` and `maps/` directories for the first complex analysis.

### Updating COMPASS

Keeping your COMPASS installation current ensures you have access to the latest agents, capabilities, and improvements to the methodology. The setup script handles updates intelligently, preserving your existing `docs/` and `maps/` directories while refreshing all agents and technical enforcement systems.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/odysseyalive/claude-compass/main/setup.sh)" -- update
```

**What the update accomplishes:**

- **Refreshes all 26+ COMPASS agents** with latest behavioral improvements and new capabilities
- **Updates technical enforcement systems** including the compass-handler.py and hook configurations  
- **Validates your installation** ensuring all components work together seamlessly
- **Preserves your institutional knowledge** - your existing `docs/` and `maps/` directories remain untouched
- **Maintains configuration** while updating to the latest settings and optimizations

Your navigation tools stay sharp, your institutional memory stays intact, and your COMPASS grows more capable with each update.

## Enhanced Capabilities: Integration with Serena

**COMPASS reaches its full potential when paired with Serena** - an open-source coding agent toolkit that transforms Claude Code into a true development collaborator through Language Server Protocol (LSP) integration.

**Project**: <https://github.com/oraios/serena>

### What Serena Provides

Serena operates as an **MCP server** that gives Claude Code IDE-like capabilities:

- **Semantic code analysis** - understands your code structure, not just text patterns
- **LSP-powered navigation** - find definitions, references, and completions across your entire codebase
- **Multi-language support** - Python, TypeScript/JavaScript, PHP, Go, Rust, C#, Ruby, Swift, Java, and more
- **Symbolic code editing** - precise edits at the symbol level using tools like `insert_after_symbol`
- **Universal compatibility** - works with Claude Code, Claude Desktop, and any MCP client
- **Free and open source** - no subscriptions required

### Language Server Integration

Serena automatically manages language servers based on your project's languages, providing semantic analysis and intelligent navigation for polyglot codebases.

**Optional language-specific setup**:

**PHP with Intelephense premium features**:

```bash
export INTELEPHENSE_LICENSE_KEY="your-license-key-here"
```

**Java projects**: JDK 11+ recommended for optimal language server performance.

### Why This Integration Matters for COMPASS

With Serena providing semantic code understanding, COMPASS transforms from a documentation system into a true **institutional knowledge engine**:

- **Precise pattern recognition** - COMPASS can map architectural patterns accurately with code structure understanding
- **Symbolic code analysis** - knows exactly how your code is organized rather than guessing at boundaries  
- **Cross-reference precision** - reliable links between documentation and actual code
- **Architecture evolution tracking** - updates understanding as Serena edits code symbolically

The combination means Claude Code doesn't just remember what you talked about - it understands how your actual codebase evolved and can make connections between abstract discussions and concrete implementation details.

## Applications: Beyond the Codebase

COMPASS works beyond just coding. The same patterns that make sense of tangled code can organize complex research. The memory that stops you from debugging the same issue twice can stop you from chasing the same research rabbit holes.

Think about the researcher lost in conflicting sources, the analyst hitting the same dead ends, the writer starting from scratch with each new project. COMPASS turns these struggles into organized knowledge-building, whether you're tracking research papers, following policy changes, or pulling together insights from different fields.

### Expanding the Framework

**Research Projects**: Complex topics become easier to navigate. Different studies, changing methods, and connections between fields turn into clear visual frameworks.

**Document Work**: Large sets of documents reveal their patterns. Policy changes, contract comparisons, and tracking how things evolve become manageable instead of overwhelming.

**Business Analysis**: Market research, competitor tracking, and business intelligence build lasting knowledge that goes beyond individual reports.

**Writing Projects**: Your writing develops its own memory. Argument structures, story flows, and editorial decisions become reusable tools.

> **Artifact Integration Workflow**
>
> - **Create valuable insights** in Claude conversations
> - **Generate artifacts** for significant analysis or frameworks
>   - *"ex. Generate an artifact from the key takeaways of this conversation, including all relevant citations and URL references"*
> - **Download artifacts** as markdown files
> - **Place in `docs/` directory** with descriptive filenames
> - **Let COMPASS organize** into searchable, cross-referenced knowledge
>
> *Why this matters*: Your breakthrough insights from one conversation become permanent knowledge. The framework you developed for understanding market trends doesn't disappear when the chat ends - it becomes part of your growing toolkit.

The same visual mapping that shows code bottlenecks can show gaps in arguments. The same documentation that prevents technical problems can prevent knowledge problems. Every complex challenge you work through becomes a path for future understanding.

COMPASS doesn't care if you're debugging code or untangling policy contradictions. Both are patterns waiting to be recognized, mapped, and remembered.

## Agent Index: The COMPASS Crew

The `compass-captain` orchestrates a network of specialized agents, each focused on a specific aspect of analysis. Think of them as different experts you might call in for a complex project - each brings their own perspective and can also be called manually when you need targeted help.

### Core Methodology Agents

**compass-complexity-analyzer** - Task complexity assessment and methodology selection. Analyzes task requirements with institutional knowledge to determine the optimal approach (light, medium, or full methodology) for execution.

**compass-knowledge-discovery** - Institutional memory access. Searches existing `docs/` and `maps/` directories to understand what you already know before starting new analysis.

**compass-pattern-apply** - Pattern matching specialist. Takes documented approaches from your knowledge base and applies them to current challenges.

**compass-gap-analysis** - Knowledge gap identification. Finds what's missing from your current understanding and creates investigation frameworks.

**compass-enhanced-analysis** - Complete analysis execution. Performs the actual analysis with full institutional context and all discovered patterns.

**compass-cross-reference** - Pattern library maintenance. Links new findings with existing knowledge and updates the searchable pattern connections.

**compass-coder** - Implementation bridge. Connects analytical findings to actual code implementation when development work is needed.

### Specialist Analysis Agents

**compass-data-flow** - Data flow visualization. Maps how data moves through your systems, identifying bottlenecks and transformation points.

**compass-doc-planning** - Documentation strategy. Plans how to capture and organize new knowledge for future reference.

**compass-second-opinion** - Expert consultation. Provides historical expert perspectives when facing uncertain technical decisions.

**compass-todo-sync** - Progress tracking. Integrates COMPASS methodology with task management systems.

**compass-breakthrough-doc** - Innovation capture. Automatically documents significant breakthroughs and successful approaches.

**compass-upstream-validator** - Repository validation. Checks findings against upstream repositories when verification is needed.

### Domain Specialists

**Authentication & Security Trio**:

- **compass-auth-performance-analyst** - Authentication performance optimization
- **compass-auth-security-validator** - Security compliance and vulnerability assessment  
- **compass-auth-optimization-specialist** - Authentication implementation strategy

**Writing & Documentation Specialists**:

- **compass-writing-analyst** - Content analysis and voice consistency
- **compass-academic-analyst** - Academic memory palace integration
- **compass-memory-enhanced-writer** - Voice preservation across different content types

**Development Infrastructure**:

- **compass-dependency-tracker** - Dependency lifecycle management and compliance analysis

Each agent can be called individually when you need specific expertise, but they work together automatically when the `compass-captain` orchestrates a full analysis. The system scales from quick targeted help to comprehensive institutional analysis depending on what your project needs.

## The Philosophy

COMPASS embodies a simple belief: that every challenge overcome should make the next challenge easier. That uncertainty should transform into knowledge. That the mazes we navigate today should become the maps that guide us tomorrow.

Because why leave things to chance when you can leave things to memory?

---

*"The path through complexity isn't about avoiding the maze - it's about building better maps."*

![COMPASS Logo](assets/compass_logo.svg)
