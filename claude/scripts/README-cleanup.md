# Safe Test File Cleanup System

A comprehensive, safety-first approach to cleaning up test files generated throughout the system while protecting legitimate project files.

## Quick Start

```bash
# Analyze what would be cleaned (safe, dry-run mode)
./.claude/.claude/scripts/cleanup

# Actually clean files (creates backups first)
./.claude/.claude/scripts/cleanup execute

# Rollback if something went wrong
./.claude/.claude/scripts/cleanup rollback
```

## Features

### 🛡️ Safety-First Design
- **Dry-run by default** - shows what would be cleaned before doing anything
- **Comprehensive safelist** - protects critical files (source code, docs, configs)
- **Automatic backups** - creates timestamped backups before any deletion
- **Rollback capability** - restore files if cleanup goes wrong
- **Confidence scoring** - requires high confidence (≥0.7) before considering cleanup

### 🔍 Smart Identification
- **Filename patterns**: `*test*.json`, `real_test_*`, temp files, swap files
- **Content analysis**: Detects test session IDs, test paths, hook event data
- **Location-based**: Identifies files in temp directories, backup patterns
- **Multi-criteria scoring**: Combines multiple heuristics for accurate detection

### 📊 Comprehensive Logging
- **Detailed operation logs** in `.claude/logs/cleanup_*.log`
- **Confidence scores** and reasoning for each file
- **Statistics tracking** - scanned, identified, protected, cleaned, errors
- **Timestamped entries** for audit trail

## Detected Test File Patterns

### Current Test Files (as of analysis)
1. `test_input.json` - COMPASS hook test data (confidence: 1.20)
2. `user_prompt_test.json` - User prompt test file (confidence: 0.70) 
3. `real_test_input.json` - Real test input with test session data (confidence: 2.00)
4. `real_test_pretool.json` - Pre-tool test data (confidence: 2.00)
5. Cleanup logs containing test data (confidence: 0.90)

### Protected Files (37 files safeguarded)
- **Source code**: `*.py`, `*.ts`, `*.js` files
- **Documentation**: `README*.md`, `CHANGELOG.md`
- **Configuration**: `package.json`, `requirements.txt`, `setup.py`
- **COMPASS agents**: `.claude/agents/*.md`
- **Handlers**: `.claude/handlers/*.py`
- **Memory system**: `.serena/memories/*`
- **Maps**: `maps/*`
- **Git files**: `.git/*`

## Usage Examples

### Basic Analysis
```bash
./.claude/scripts/cleanup
# Shows: 5 test files identified, 37 protected, confidence scores
```

### Execute Cleanup
```bash
./.claude/scripts/cleanup execute
# Creates backup in .cleanup_backup/TIMESTAMP/
# Deletes identified test files
# Provides rollback instructions
```

### Rollback Operations
```bash
# Rollback from latest backup
./.claude/scripts/cleanup rollback

# Rollback from specific backup
./.claude/scripts/cleanup rollback 20250831_143022
```

### Advanced Options
```bash
# Use Python script directly for more control
python .claude/scripts/safe-cleanup.py --help
python .claude/scripts/safe-cleanup.py --log-level DEBUG
python .claude/scripts/safe-cleanup.py --directory .claude/logs
```

## Confidence Scoring System

The cleanup system uses a multi-criteria confidence scoring approach:

- **Filename patterns**: +0.7 (strong indicator)
- **Content patterns**: +0.8 (very strong indicator)  
- **Recent creation**: +0.1 (mild indicator)
- **Hook event test data**: +0.5 (strong indicator)
- **Minimum threshold**: 0.7 (high confidence required)

## Safety Mechanisms

### 1. Safelist Protection
Files matching these patterns are NEVER deleted:
- Git repository files
- Source code files
- Documentation files
- Configuration files
- COMPASS system files
- Memory and knowledge files

### 2. Backup System
- **Automatic backups** before any deletion
- **Timestamped backup directories** (.cleanup_backup/YYYYMMDD_HHMMSS/)
- **Complete directory structure** preserved
- **Verification** of backup success before deletion

### 3. Error Handling
- **Graceful degradation** - continues with other files if one fails
- **Comprehensive error logging** 
- **Rollback on backup failure** - aborts cleanup if backup fails
- **User confirmation** required for actual cleanup

## Integration with COMPASS

### COMPASS Cleanup Coordinator Agent
The system includes `compass-cleanup-coordinator` agent for integration:
- Follows COMPASS methodology phases
- Provides user interaction guidelines
- Integrates with memory system
- Supports automated workflows

### Memory Integration
Results are documented in `.serena/memories/` for:
- Pattern learning and improvement
- Historical cleanup tracking
- Integration with other COMPASS agents

## File Structure

```
.claude/scripts/
├── safe-cleanup.py          # Main cleanup utility
├── cleanup                  # Simple wrapper script
└── README-cleanup.md        # This documentation

.claude/
├── agents/
│   └── compass-cleanup-coordinator.md  # COMPASS agent integration
└── logs/
    └── cleanup_*.log        # Operation logs

.cleanup_backup/             # Created during cleanup
└── YYYYMMDD_HHMMSS/        # Timestamped backups
```

## Troubleshooting

### No Files Identified
- Check if test files exist: `ls *test*.json`
- Review patterns in `safe-cleanup.py`
- Adjust confidence threshold if needed

### Backup Failures
- Check disk space: `df -h`
- Verify permissions: `ls -la .`
- Create backup directory manually if needed

### Rollback Issues
- List available backups: `ls .cleanup_backup/`
- Check backup integrity before rollback
- Use specific timestamp for rollback

### False Positives
- Review confidence scores and reasoning
- Add patterns to safelist in `safe-cleanup.py`
- Report issues for pattern refinement

## Best Practices

1. **Always run dry-run first** to review what would be cleaned
2. **Review confidence scores** - investigate low confidence files
3. **Keep backups** until you're sure cleanup was successful
4. **Test rollback** in safe environment before production use
5. **Monitor logs** for patterns and improvements
6. **Run regularly** to prevent accumulation of test files

## Future Enhancements

- **Scheduled cleanup** - automatic periodic cleaning
- **Pattern learning** - improve detection based on usage
- **Integration testing** - automated test suite
- **Performance optimization** - faster scanning for large codebases
- **Configuration file** - user-customizable patterns and settings