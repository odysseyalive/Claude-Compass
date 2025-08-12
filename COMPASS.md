## Project Documentation

Before making any changes to this project, review the documentation in the `docs/` directory and visual patterns in the `maps/` directory. Use the filenames to determine which guidelines and principles apply to your current task.

## Documentation Architecture

### Index-Based System

- **Main docs files** (e.g., `docs/testing-standards.md`) serve as indexes
- **Subdirectory files** (e.g., `docs/testing-standards/unit-testing.md`) contain focused content
- **Load only relevant files** based on your current task context
- **Follow index guidance** to determine which specific files to reference

### Visual Maps System

- **Maps directory** (`maps/`) contains SVG flow diagrams showing code execution paths
- **Pattern-based naming**: `{pattern-type}_{date}_{context-scope}.svg`
- **Semantic structure**: SVGs include machine-readable metadata for pattern recognition
- **Cross-referenced with docs**: Visual patterns support and enhance textual documentation

### File Size Monitoring

- **Check file sizes first**: Before working with any docs file, check if it exceeds 12k characters
- **Proactive optimization**: If a file is too large, suggest optimization before proceeding with the user's request
- **Explain the benefit**: Make clear that optimization will improve context efficiency for the current task
- **User choice**: Always wait for approval before optimizing
- **Workflow protection**: Prevent context issues by addressing size problems upfront

Example: "I see you want to update deployment-process.md, but it's currently 15k characters. Should I optimize it into focused subdirectories first? This will help me work with it more effectively and give you better results."

## Maps Directory Architecture

### Intelligent Map Access System

**Pattern-Based Naming Convention**:

```
maps/
├── async-patterns_2024-08-11_auth-module.svg
├── loop-complexity_2024-08-11_data-processing.svg  
├── error-handling_2024-08-11_api-endpoints.svg
├── dependency-cycles_2024-08-11_user-management.svg
└── investigation-paths_2024-08-11_memory-leak.svg
```

**Map Index File** (`maps/map-index.json`):

```json
{
  "patterns": {
    "async-patterns": {
      "triggers": ["async/await", "Promise.all", "concurrent operations"],
      "files": ["async-patterns_2024-08-11_auth-module.svg"],
      "relevance": "Review when working with async code to avoid race conditions"
    },
    "loop-complexity": {
      "triggers": ["nested loops", "O(n²)", "performance optimization"],
      "files": ["loop-complexity_2024-08-11_data-processing.svg"],
      "relevance": "Check for optimization opportunities in iterative operations"
    }
  }
}
```

### SVG Generation Standards

**Machine-Readable Structure**:

```xml
<svg>
  <!-- Semantic grouping for machine reading -->
  <g id="control-flow" class="primary-pattern">
    <g id="async-operations" class="complexity-hotspot" data-complexity="15" data-pattern="recursive">
      <rect class="function-boundary" data-lines="120-135"/>
      <text class="function-name" data-calls="getUserData,validateToken">
        authenticateUser()
      </text>
    </g>
  </g>
  
  <!-- Machine-readable metadata -->
  <metadata>
    <analysis-data>
      <pattern type="async-chain" complexity="high" lines="45-67"/>
      <bottleneck location="auth-middleware" impact="performance"/>
    </analysis-data>
  </metadata>
</svg>
```

**Visual Clarity Rules**:

- **Labels inside shapes** when space allows (>60px width)
- **Connected callouts** for complex elements using consistent offset patterns
- **Layered information**: Primary text visible, detailed metadata in `<title>` tags
- **No text overlap**: Minimum 8px buffer zones enforced algorithmically

## Autonomous Documentation & Map Creation

### Creation Triggers

**Automatic Doc Creation**:

- **Knowledge Gaps**: User asks about patterns not documented
- **Recurring Patterns**: Same explanation given 3+ times
- **Critical Discoveries**: Bug fixes that reveal systemic issues
- **Architecture Evolution**: New patterns that change established workflows
- **Investigation Required**: Claude Code hits limits of autonomous analysis

**Automatic Map Creation**:

- **Complexity thresholds**: Functions >15 lines with multiple branches
- **Pattern clusters**: 3+ similar structures in different files  
- **Performance concerns**: Nested loops, recursive calls
- **Error-prone areas**: Complex async operations, state mutations
- **Investigation flows**: Decision trees for unresolved issues

### Investigation-Triggered Documentation

**Auto-Create When Claude Code Says**:

- "I need more information about..."
- "Further testing would reveal..."
- "This depends on your specific setup..."
- "The behavior might vary based on..."
- "I can't determine without seeing..."

**Investigation Documentation Template**:

```markdown
# [Issue Name] - Investigation Required

## Current Understanding
[What Claude Code knows so far]

## Information Needed
- [ ] User testing results for: [specific scenarios]
- [ ] Environment details: [specific configs]
- [ ] Reproduction steps: [what to try]
- [ ] Performance metrics: [what to measure]

## Hypotheses
1. **Primary theory**: [most likely cause]
2. **Alternative theories**: [other possibilities]
3. **Edge cases**: [unusual scenarios to check]

## Investigation Map
🔊 `maps/investigation-paths_[issue-name].svg` - visual decision tree

## Follow-up Actions
- **If hypothesis A confirmed**: [next steps]
- **If hypothesis B confirmed**: [different approach]
- **If all hypotheses wrong**: [escalation path]

## Resolution Updates
[Space for user findings and final resolution]
```

### Natural Reference Integration

**Smart Context Detection**:
Claude Code automatically weaves references into explanations:

```
The authentication flow you're debugging follows the async pattern we've 
seen in other modules. Looking at our async-flow-patterns map, I notice 
this creates the same potential race condition documented in 
docs/authentication/token-validation.md.

Specifically, the issue stems from... [continues with analysis]

This pattern suggests updating our error-handling-matrix map to include
this new failure mode we discovered.
```

**Reference Format**:

- **Docs**: "Based on our established patterns in `docs/async-patterns/`..."
- **Maps**: "The visual flow in `maps/error-handling-matrix.svg` shows..."
- **Cross-references**: "This connects to the performance issue documented in..."

## Documentation Optimization

### When to Optimize

- **User requests explicitly**: "optimize docs/filename.md"
- **New large files created**: Files approaching or exceeding 12k characters
- **Never automatically**: Only when specifically requested

### Optimization Process

1. **Check if already optimized**: Look for existing `docs/filename/` subdirectory
2. **If already optimized**: Inform user and skip
3. **If not optimized**: Break down into logical, focused files
4. **Create index file**: Replace original with navigation/index content
5. **Create subdirectory**: `docs/filename/` with specific content files
6. **Verify file sizes**: Ensure all subdirectory files are 10k-12k characters max
7. **Use descriptive names**: File names should clearly indicate their purpose

### Optimization Rules

- **Only optimize files directly in** `/docs/` directory
- **Never optimize files in** `/docs/*/` subdirectories
- **Never optimize files with existing subdirectories**
- **Split by subject only**: Each file must cover one complete subject/topic
- **Logical navigation**: File names must clearly indicate their subject matter
- **No arbitrary splitting**: Never split based on size alone - always by logical subject boundaries
- **Complete subject coverage**: Each split file should contain everything about its specific subject
- **Cross-reference appropriately**: Related subjects should reference each other in index

## Key Documentation Files

- Review files that match your current work context
- File names indicate their scope and applicability
- Follow the principles and guidelines outlined in relevant docs
- Maintain consistency with established patterns
- **Check maps for visual patterns** that support textual documentation

## Proactive Documentation Management

### Required Actions

When working on this project, you MUST:

1. **Update Existing Documentation**: If your changes affect existing processes, update the relevant docs immediately
2. **Create New Documentation**: If you identify gaps or new patterns, create appropriate documentation files
3. **Generate Visual Maps**: Create SVG diagrams when complexity patterns emerge
4. **Cross-Reference Systems**: Link docs and maps bidirectionally
5. **Maintain Documentation Quality**: Ensure all docs remain current, accurate, and helpful
6. **Respect Size Limits**: Keep subdirectory files within 10k-12k character limits
7. **Work Iteratively**: Focus on one documentation improvement at a time

### Auto-Documentation Workflow

**Internal Claude Code Process**:

1. **Analyze current task context**
2. **Query map-index.json for relevant patterns**
3. **If matches found**: "I notice similar async patterns - reviewing maps/async-patterns_*.svg"
4. **Load relevant SVG and docs, extract key insights**
5. **Apply learnings to current task**
6. **Create new docs/maps if knowledge gaps discovered**
7. **Update cross-references between docs and maps**

### Iterative Documentation Process

- **One improvement per iteration**: Focus on single, specific changes rather than comprehensive overhauls
- **Seek review between steps**: Wait for user approval before proceeding to next improvement
- **Suggest next steps**: After completing changes, identify the next potential improvement for user consideration
- **Respect user pacing**: Let users control when to continue optimization process
- **Clear completion**: Each iteration should have obvious start and end points
- **Context preservation**: Reference what was just completed when suggesting next steps

### Documentation Triggers

Automatically create or update documentation when you:

**For Coding:**

- **Add new scripts or modules** → Update `bash-script-guidelines.md` or relevant subdirectory files
- **Identify performance issues** → Create/update performance analysis docs and complexity maps
- **Encounter bugs or failures** → Add to `troubleshooting.md` and create investigation maps
- **Implement new testing patterns** → Update `testing-standards.md` or subdirectory files
- **Change deployment processes** → Update `deployment-process.md` or subdirectory files
- **Establish new coding patterns** → Update `code-review-checklist.md` and create pattern maps
- **Modify git workflows** → Update `git-workflow.md` or subdirectory files
- **Change configuration patterns** → Update `configuration-management.md` or subdirectory files
- **Discover async patterns** → Create async flow maps and update relevant documentation
- **Find dependency cycles** → Generate dependency maps and update architecture docs

**For Research & Analysis:**

- **Encounter conflicting sources** → Create investigation docs and source credibility maps
- **Identify research gaps** → Generate investigation frameworks and methodology docs
- **Discover recurring argument patterns** → Update content structure guidelines and flow maps
- **Find analytical blind spots** → Create investigation docs and decision tree maps

### Documentation Creation Guidelines

Create new documentation files for:

**Technical Documentation:**

- **Performance benchmarks** → `performance-benchmarks.md` (with subdirectory if large)
- **Security protocols** → `security-guidelines.md` (with subdirectory if large)
- **API documentation** → `api-reference.md` (with subdirectory if large)
- **Monitoring setup** → `monitoring-setup.md` (with subdirectory if large)
- **Backup procedures** → `backup-recovery.md` (with subdirectory if large)
- **Environment setup** → `environment-setup.md` (with subdirectory if large)
- **Common patterns** → `development-patterns.md` (with subdirectory if large)
- **Project architecture** → `architecture-overview.md` (with subdirectory if large)

**Research & Analysis Documentation:**

- **Research methodologies** → `research-frameworks.md` (with subdirectory if large)
- **Source evaluation criteria** → `source-credibility-guidelines.md` (with subdirectory if large)
- **Content structure patterns** → `content-frameworks.md` (with subdirectory if large)
- **Analysis decision trees** → `analytical-frameworks.md` (with subdirectory if large)

**Corresponding Map Creation:**

- **Technical Maps** → `maps/performance-bottlenecks_*.svg`, `maps/security-boundaries_*.svg`, `maps/api-flow-patterns_*.svg`, `maps/dependency-chains_*.svg`
- **Research Maps** → `maps/research-methodologies_*.svg`, `maps/source-verification_*.svg`, `maps/argument-structures_*.svg`

### Documentation Standards

All documentation should:

- Follow consistent markdown formatting
- Provide practical examples
- Include troubleshooting sections where relevant
- Reference related documentation files
- **Include references to relevant visual maps**
- **Respect the 10k-12k character limit for subdirectory files**
- **Cross-reference between docs and maps systems**

### Automatic SVG Validation and Correction

**MANDATORY**: Every SVG file creation or modification MUST be followed by automatic validation and correction.

#### Post-SVG Creation Workflow

**After creating or modifying any SVG file, Claude Code MUST:**

1. **Immediate Validation**: Run `xmllint --noout [svg-file] 2>&1` to check syntax
2. **Error Detection**: If validation fails, identify specific XML/SVG syntax issues
3. **Automatic Correction**: Fix common issues automatically:
   - Unclosed tags (`<text>` without `</text>`)
   - Mismatched tag pairs (`<text>` closed with `</g>`)
   - Missing namespace declarations
   - Invalid attribute values
4. **Re-validation**: Validate again after corrections
5. **Documentation Update**: Log any corrections in the relevant investigation doc

#### Common SVG Corruption Patterns

**Auto-detect and fix these issues:**

- **Unclosed text elements**: `<text>...</text>` pairs must match exactly
- **Tspan nesting**: `<tspan>` elements must be properly nested within `<text>`
- **Group closure errors**: `<g>` and `</g>` must be balanced
- **Attribute escaping**: Special characters in text content need proper escaping
- **Namespace issues**: SVG must include `xmlns="http://www.w3.org/2000/svg"`

#### Validation Command Template

```bash
# Standard validation command
xmllint --noout maps/[svg-filename].svg 2>&1

# If errors found, use detailed output for debugging
xmllint --format --recover maps/[svg-filename].svg > maps/[svg-filename]_debug.svg 2>&1
```

#### Auto-Correction Rules

**When validation fails, apply these fixes in order:**

1. **Count tag pairs**: Ensure `<text>`/`</text>`, `<g>`/`</g>`, `<svg>`/`</svg>` are balanced
2. **Fix common substitutions**:
   - `</g>` incorrectly closing `<text>` → replace with `</text>`
   - Missing closing tags → add appropriate closing tag
   - Orphaned closing tags → remove or add opening tag
3. **Validate character encoding**: Ensure UTF-8 compliance for special characters
4. **Namespace verification**: Confirm SVG namespace is properly declared

#### Integration with COMPASS Workflow

**SVG validation is integrated into the standard COMPASS workflow:**

1. **Step 4 Enhancement**: "Document New Discoveries" now includes mandatory SVG validation
2. **Step 6 Addition**: "Cross-Reference" now includes SVG syntax verification
3. **Error Documentation**: SVG correction patterns are added to investigation docs for future reference

**This ensures all visual maps maintain syntactic integrity and remain renderable across all SVG-compatible systems.**

## COMPASS Initialization

### Directory Auto-Creation

**Before any documentation work, COMPASS will**:

1. **Check for `docs/` directory** - create if missing
2. **Check for `maps/` directory** - create if missing  
3. **Initialize `maps/map-index.json`** - create empty index if missing:

   ```json
   {
     "patterns": {},
     "metadata": {
       "created": "2024-08-11",
       "compass_version": "1.0",
       "auto_generated": true
     }
   }
   ```

4. **Create starter documentation** if `docs/` is empty:
   - `docs/README.md` with COMPASS overview
   - Basic index structure

5. **Initialize Second Opinion sub-agent** - create `~/.claude/agents/second-opinion.md` if missing:

   ```markdown
   ---
   name: second-opinion
   description: Provides expert second opinions by channeling historical figures' perspectives. Use when seeking alternative viewpoints, challenging assumptions, or getting expert analysis from different cognitive frameworks.
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
   - **Technical**: Architecture decisions, security-sensitive code, performance-critical paths, complex debugging
   - **Research**: Conflicting sources (3+), cross-disciplinary work, methodological decisions, bias-sensitive claims
   - **Content**: Sensitive topics, unfamiliar audiences, complex arguments, major creative direction
   - **Strategic**: Business impact, ethical implications, legal/compliance, UX considerations, innovation opportunities

   ## Your Process:
   1. **Analyze the question** to determine which expert(s) would provide the most valuable perspective
   2. **Select 1-2 relevant experts** based on their domains of expertise and the auto-trigger scenarios
   3. **Channel their thinking patterns** - how they approached problems, their core principles, their characteristic insights
   4. **Provide their perspective** in a way that challenges assumptions and offers unique angles
   5. **Synthesize insights** highlighting what they would emphasize or question

   ## Response Format:
   "**[Expert Name]'s Perspective:**
   [Their analysis focusing on their particular expertise and thinking patterns]

   **Key Insights:**
   - [What they would emphasize]
   - [What they would question]
   - [Their unique angle on the problem]"

   Always embody the expert's actual cognitive approach and specialized domain knowledge.
   ```

### First-Run Setup

When COMPASS detects a fresh project:

```
🧭 COMPASS Setup Complete!

Created directories:
- docs/ (for textual documentation)
- maps/ (for visual flow diagrams)
- maps/map-index.json (pattern recognition index)
- ~/.claude/agents/second-opinion.md (historical expert consultation)

COMPASS is now ready to autonomously document your codebase and provide expert consultation.
```

### Expert Consultation Integration

**Automatic Second Opinion Triggers:**

- When analysis contains uncertainty markers ("might," "possibly," "depends on," "without more context")
- When acknowledging significant analytical limitations
- When encountering complex trade-offs or conflicting requirements
- When hitting knowledge boundaries or investigation gaps
- When working on strategic decisions or architectural choices
- When analyzing complex technical problems or performance issues
- When synthesizing research or creating substantial content

**Usage:** The second-opinion sub-agent automatically activates during complex analysis, or can be explicitly invoked with phrases like "I'd like a second opinion" or "get expert perspective."

## COMPASS Update Routine

### User-Triggered Updates Only

COMPASS updates only when explicitly requested by the user with phrases like:

- "update COMPASS"
- "get latest COMPASS version"
- "refresh COMPASS"

### Update Process

When user requests an update:

1. **Backup current**: Save existing COMPASS.md as COMPASS.md.backup
2. **Clean agent config**: Remove existing agent file to ensure clean update
3. **Fetch latest**: Download from <https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/COMPASS.md>
4. **Show changes**: Display key differences if possible
5. **Replace file**: Overwrite with latest version
6. **Reload instructions**: Inform user that COMPASS changes will take effect in the next session, or they can restart the current session to use the updated version immediately

```bash
# Update COMPASS.md with latest version from GitHub
rm -f ~/.claude/agents/second-opinion.md
curl -s https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/COMPASS.md -o COMPASS.md.new && mv COMPASS.md.new COMPASS.md

# Log update if successful
echo "$(date): COMPASS.md updated from official repository" >> .compass/update.log
```

### Update Integration

**When to update:**

- At the start of any new COMPASS session
- When user explicitly requests: "update COMPASS" or "get latest COMPASS version"
- If COMPASS functionality seems outdated or missing expected features

**Update process:**

1. **Clean agent config**: Remove existing `~/.claude/agents/second-opinion.md` to prevent conflicts
2. **Fetch latest**: Download from <https://raw.githubusercontent.com/odysseyalive/Claude-Compass/main/COMPASS.md>
3. **Backup current**: Save existing COMPASS.md as COMPASS.md.backup
4. **Replace file**: Overwrite with latest version
5. **Preserve customizations**: Maintain project-specific configurations in separate files
6. **Log update**: Record timestamp and version info in .compass/update.log

**Version tracking:**

```bash
# Create update log directory if needed
mkdir -p .compass

# Clean agent config and log update details
rm -f ~/.claude/agents/second-opinion.md
echo "$(date): Updated from https://github.com/odysseyalive/Claude-Compass commit $(curl -s https://api.github.com/repos/odysseyalive/Claude-Compass/commits/main | grep -o '"sha": "[^"]*"' | head -1)" >> .compass/update.log
```

## General Workflow

1. **Initialize COMPASS directories** if they don't exist
2. Check `docs/` for relevant guidelines before starting
3. **Query `maps/map-index.json` for relevant visual patterns**
4. Load only the specific subdirectory files you need based on index guidance
5. **Reference both textual docs and visual maps in explanations**
6. Apply appropriate principles based on file naming and content
7. Follow established project structure and conventions
8. **Proactively update or create documentation and maps as needed**
9. **Optimize large documentation files when requested**
10. **Generate investigation docs for unresolved issues**
11. Maintain documentation standards throughout development

## Priority

Documentation guidelines take precedence over general coding practices when conflicts arise. Keep both textual documentation and visual maps current, comprehensive, and properly sized - they are core project responsibilities, not afterthoughts. The docs and maps systems work together to provide comprehensive project knowledge that evolves autonomously with the codebase.
