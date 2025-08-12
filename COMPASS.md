## Project Documentation

Before making changes, review `docs/` directory and visual patterns in `maps/` directory. Use filenames to determine which guidelines apply to your current task.

## Documentation Architecture

### Index-Based System

- **Main docs files** (e.g., `docs/testing-standards.md`) serve as indexes
- **Subdirectory files** (e.g., `docs/testing-standards/unit-testing.md`) contain focused content
- **Load only relevant files** based on task context
- **Follow index guidance** to determine which specific files to reference

### Visual Maps System

- **Maps directory** (`maps/`) contains SVG flow diagrams showing code execution paths
- **Pattern-based naming**: `{pattern-type}_{date}_{context-scope}.svg`
- **Semantic structure**: SVGs include machine-readable metadata for pattern recognition
- **Cross-referenced with docs**: Visual patterns support textual documentation

### File Size Monitoring

Check file sizes before working with docs files. If >12k characters, suggest optimization first. Always wait for approval before optimizing.

## Maps Directory Architecture

### Pattern-Based Naming

```
maps/
├── async-patterns_2024-08-11_auth-module.svg
├── loop-complexity_2024-08-11_data-processing.svg  
├── error-handling_2024-08-11_api-endpoints.svg
└── investigation-paths_2024-08-11_memory-leak.svg
```

### Map Index File (`maps/map-index.json`)

```json
{
  "patterns": {
    "async-patterns": {
      "triggers": ["async/await", "Promise.all", "concurrent operations"],
      "files": ["async-patterns_2024-08-11_auth-module.svg"],
      "relevance": "Review when working with async code to avoid race conditions"
    }
  }
}
```

### SVG Standards

- **Machine-readable structure** with semantic grouping and metadata
- **Visual clarity**: Labels inside shapes (>60px width), connected callouts, no text overlap
- **Mandatory validation**: Every SVG creation/modification must be validated with `xmllint --noout [svg-file]`
- **Auto-correction**: When validation fails, fix common issues (unclosed tags, mismatched pairs, namespace problems) and re-validate

## Autonomous Documentation & Map Creation

### Creation Triggers

**Automatic Doc Creation**: Knowledge gaps, recurring patterns (3+ times), critical discoveries, architecture evolution, investigation required

**Automatic Map Creation**: Complex functions (>15 lines), pattern clusters (3+ similar structures), performance concerns, error-prone areas, investigation flows

### Investigation-Triggered Documentation

**Auto-Create When Claude Code Says**: "I need more information...", "Further testing would reveal...", "This depends on your specific setup...", etc.

**When Triggered**: Knowledge gaps, uncertainty markers, or analysis limitations automatically generate investigation frameworks using the template below.

**Investigation Template**:

```markdown
# [Issue Name] - Investigation Required
## Current Understanding
## Information Needed
## Hypotheses
## Investigation Map
## Follow-up Actions
## Resolution Updates
```

### Natural Reference Integration

Claude Code automatically weaves references into explanations by:

- **Pattern detection**: Matching current work to documented patterns in map-index.json
- **Smart context**: Including relevant docs/maps references in responses
- **Bidirectional linking**: Connecting related documentation and updating cross-references
- **Knowledge building**: Each reference strengthens the institutional memory network

## Documentation Optimization

### When to Optimize

- User requests explicitly: "optimize docs/filename.md"
- New large files created (approaching 12k characters)
- Never automatically

### Optimization Process

1. Check if already optimized (existing subdirectory)
2. Break down into logical, focused files if needed
3. Create index file and subdirectory structure
4. Ensure files stay within 10k-12k character limits
5. Use descriptive names and cross-reference appropriately

### Optimization Rules

- Only optimize files directly in `/docs/` directory
- Split by subject only, never arbitrarily by size
- Maintain complete subject coverage per file
- Cross-reference related subjects in index

## Proactive Documentation Management

### Required Actions

1. **Update Existing Documentation** when changes affect processes
2. **Create New Documentation** for gaps or new patterns
3. **Generate Visual Maps** when complexity patterns emerge
4. **Cross-Reference Systems** bidirectionally between docs and maps
5. **Maintain Documentation Quality** - current, accurate, helpful
6. **Respect Size Limits** for subdirectory files
7. **Work Iteratively** - one improvement at a time

### Documentation Triggers

**Coding**: New scripts/modules, performance issues, bugs/failures, testing patterns, deployment changes, coding patterns, git workflows, configuration changes, async patterns, dependency cycles

**Research**: Conflicting sources, research gaps, argument patterns, analytical blind spots

### Documentation Standards

- Consistent markdown formatting
- Practical examples and troubleshooting sections
- Reference related files and visual maps
- Respect character limits and cross-reference systems

## COMPASS Initialization

### Directory Auto-Creation

**COMPASS automatically creates these components on first complex analysis:**

1. Check/create `docs/` directory
2. Check/create `maps/` directory  
3. Initialize `maps/map-index.json` if missing
4. Create starter documentation if `docs/` empty
5. **Initialize Enhanced Advisory Board** - create `~/.claude/agents/second-opinion.md`

### Enhanced Advisory Board Auto-Setup

**When COMPASS initializes, it automatically runs this setup:**

```bash
# Create Claude agents directory if it doesn't exist
mkdir -p ~/.claude/agents

# Create Enhanced Advisory Board subagent file
cat > ~/.claude/agents/second-opinion.md << 'EOF'
---
name: second-opinion
description: Enhanced expert advisory board with 22 specialist personas across analytical, strategic, cultural, and methodological domains. Auto-triggers for complex analysis, conflicting requirements, and cross-domain work.
---

You are the Enhanced Advisory Board - 22 expert personas spanning comprehensive analytical domains. When consulted, select the most relevant expert(s) and provide their specialized perspective:

**Expert Personas:** 

**Analytical Framework:**
- **Albert Einstein** (theoretical breakthroughs, paradigm shifts, thought experiments)
- **Leonardo da Vinci** (interdisciplinary innovation, systems thinking, creative problem-solving)
- **Marie Curie** (empirical research methodology, scientific rigor, breakthrough discovery)
- **Charles Darwin** (pattern evolution, patient observation, systematic investigation)

**Strategic & Decision-Making:**
- **José Raúl Capablanca** (strategic intuition, elegant simplification, long-term planning)
- **Peter Drucker** (management frameworks, organizational systems, strategic effectiveness)
- **Adam Smith** (systems analysis, economic thinking, market dynamics)

**Innovation & Implementation:**
- **Alan Turing** (computational logic, systematic thinking, mathematical foundations)
- **Thomas Edison** (iterative experimentation, practical solutions, persistent innovation)
- **Steve Jobs** (user experience design, market intuition, product vision)

**Philosophical & Ethical Framework:**
- **Socrates** (critical questioning, assumption challenging, dialectical method)
- **Immanuel Kant** (systematic critique, ethical frameworks, rational analysis)
- **John Rawls** (applied ethics, justice principles, fairness frameworks)

**Cultural & Spiritual Wisdom:**
- **Augustine of Hippo** (theological integration, faith-reason synthesis, moral complexity)
- **Confucius** (relational ethics, social harmony, practical wisdom)
- **Black Elk** (indigenous wisdom, cyclical thinking, visionary insight)
- **Lao Tzu** (paradoxical systems thinking, natural harmony, effortless action)

**Creative & Interpretive:**
- **Wolfgang Amadeus Mozart** (aesthetic synthesis, creative pattern recognition, harmonic relationships)
- **Clifford Geertz** (cultural interpretation, meaning-making, thick description)
- **Claude Lévi-Strauss** (structural patterns, anthropological analysis, symbolic systems)

**Methodological & Investigation:**
- **Francis Bacon** (empirical investigation, scientific method, systematic inquiry)
- **Jane Jacobs** (complex systems observation, urban dynamics, grassroots insight)

**Auto-Trigger Scenarios:**
- Technical: Architecture decisions, security-sensitive code, performance-critical paths, complex debugging
- Research: Conflicting sources (3+), cross-disciplinary work, methodological decisions, bias-sensitive claims
- Content: Sensitive topics, unfamiliar audiences, complex arguments, major creative direction
- Strategic: Business impact, ethical implications, legal/compliance, UX considerations, innovation opportunities

**Process:** Select 1-2 relevant experts, channel their cognitive approaches, provide perspective that challenges assumptions and offers unique angles.

## Response Format:
"**[Expert Name]'s Perspective:**
[Analysis focusing on their expertise and thinking patterns]

**Key Insights:**
- [What they would emphasize]
- [What they would question]  
- [Their unique angle]"

Always embody the expert's actual cognitive approach and specialized domain knowledge.
EOF

echo "✅ Enhanced Advisory Board initialized at ~/.claude/agents/second-opinion.md"
```

### Verification After Installation

**Run these commands to verify COMPASS is properly initialized:**

```bash
# Check all COMPASS directories exist
ls -la docs/ maps/ ~/.claude/agents/

# Verify Enhanced Advisory Board file
ls -la ~/.claude/agents/second-opinion.md

# Check map index was created
cat maps/map-index.json

# Preview Advisory Board content
head -15 ~/.claude/agents/second-opinion.md
```

**Expected output:**

```
✅ docs/ directory exists
✅ maps/ directory exists  
✅ ~/.claude/agents/second-opinion.md exists (should be ~6KB)
✅ maps/map-index.json contains pattern index
✅ Advisory Board shows 22 expert personas
```

### Manual Setup (Troubleshooting)

**If automatic initialization fails, run these commands manually:**

```bash
# 1. Create all required directories
mkdir -p docs maps ~/.claude/agents

# 2. Create basic map index
cat > maps/map-index.json << 'EOF'
{
  "patterns": {},
  "last_updated": "$(date -Iseconds)",
  "version": "1.0"
}
EOF

# 3. Run the Enhanced Advisory Board setup command from above
# (Use the full cat > ~/.claude/agents/second-opinion.md command)

# 4. Restart Claude Code to activate the subagent system
```

### Enhanced Advisory Board Integration

**Implementation**: The Enhanced Advisory Board operates through Claude Code's **second-opinion subagent system**. When auto-trigger scenarios are detected, Claude Code automatically invokes the second-opinion subagent to consult relevant expert personas.

**Auto-Trigger Scenarios**:

- **Technical complexity** → Automatically calls second-opinion subagent for architecture, security, performance, debugging
- **Research conflicts** → Automatically calls second-opinion subagent for contradictory sources, cross-domain analysis, methodological choices
- **Content sensitivity** → Automatically calls second-opinion subagent for ethical topics, audience alignment, complex arguments
- **Strategic decisions** → Automatically calls second-opinion subagent for business impact, innovation opportunities, compliance

**Expert Selection Process**: The second-opinion subagent automatically selects 1-2 relevant expert personas from the 22-expert roster based on domain expertise matching the specific problem type.

**Workflow Integration**:

- **During documentation creation**: When documenting new discoveries or patterns, mandatory second-opinion subagent consultation for triggered scenarios
- **During cross-referencing**: When linking docs and maps, includes expert validation through second-opinion subagent
- **Documentation capture**: All second-opinion subagent consultations documented in investigation files and visual maps for institutional knowledge building

**Usage**: Claude Code users can also explicitly invoke expert consultation with phrases like "I'd like a second opinion" or "get expert perspective" to manually trigger the second-opinion subagent.

**For writing projects specifically**, the system auto-triggers when detecting:

- Complex arguments requiring validation
- Unfamiliar audiences needing perspective
- Sensitive topics requiring careful framing  
- Major creative direction decisions

This ensures your writing projects automatically benefit from expert consultation without manual intervention.

## COMPASS Update Routine

### User-Triggered Updates Only

Updates only when explicitly requested: "update COMPASS", "get latest COMPASS version", "refresh COMPASS"

### Update Process

1. **Backup current**: Save existing COMPASS.md as COMPASS.md.backup
2. **Remove old subagent**: Delete `~/.claude/agents/second-opinion.md` for clean recreation
3. **Fetch latest**: Download from GitHub repository
4. **Replace file**: Overwrite with latest version
5. **Log update**: Record timestamp and version info

```bash
# Remove old subagent file for clean update
rm -f ~/.claude/agents/second-opinion.md

# Update COMPASS.md with latest version
curl -s https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/COMPASS.md -o COMPASS.md.new && mv COMPASS.md.new COMPASS.md

# Log update
mkdir -p .compass
echo "$(date): COMPASS.md updated from official repository" >> .compass/update.log
```

## General Workflow

1. **Initialize COMPASS directories** if they don't exist
2. **Check `docs/` for relevant guidelines** before starting
3. **Query `maps/map-index.json`** - match current task to documented patterns and load relevant visual maps
4. **Load specific subdirectory files** based on index guidance
5. **Reference both docs and maps** in explanations using smart context detection
6. **Apply appropriate principles** based on file naming and content
7. **Proactively update or create documentation and maps** as needed
8. **Optimize large documentation files** when requested
9. **Generate investigation docs** for unresolved issues using auto-triggered templates
10. **Engage enhanced advisory board** - second-opinion subagent automatically activates for complex analysis based on trigger scenarios
11. **Maintain documentation standards** throughout development with cross-referencing and institutional knowledge building

## Priority

Documentation guidelines take precedence over general coding practices when conflicts arise. Keep textual documentation, visual maps, and advisory board consultations current and comprehensive - they are core project responsibilities building institutional knowledge that evolves autonomously with the codebase.
