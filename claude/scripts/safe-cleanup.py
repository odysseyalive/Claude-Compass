#!/usr/bin/env python3
"""
Safe Test File Cleanup Utility
Safely identifies and removes test files while preserving legitimate files.
"""

import os
import json
import re
import shutil
import argparse
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional

class SafeCleanup:
    def __init__(self, dry_run: bool = True, log_level: str = "INFO"):
        """Initialize the safe cleanup utility."""
        self.dry_run = dry_run
        self.backup_dir = Path(".cleanup_backup") / datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = Path(".claude/logs") / f"cleanup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        # Setup logging
        self.setup_logging(log_level)
        
        # Safe identification patterns
        self.test_patterns = {
            'filename_patterns': [
                r'.*test.*\.json$',           # Files with "test" in name
                r'.*_test_.*\.json$',         # Files with "_test_" pattern
                r'^test_.*\.json$',           # Files starting with "test_"
                r'.*test\.json$',             # Files ending with "test.json"
                r'real_test_.*\.json$',       # Files starting with "real_test_"
                r'user_prompt_test\.json$',   # Specific test file pattern
                r'.*\.tmp$',                  # Temporary files
                r'.*\.temp$',                 # Temp files
                r'.*_tmp_.*',                 # Files with tmp in middle
            ],
            'content_patterns': [
                r'"session_id":\s*"test-',    # Test session IDs
                r'"/test/path"',              # Test paths
                r'"/test/cwd"',              # Test working directories
                r'"Test COMPASS agent"',      # Test descriptions
                r'"hook_event_name":\s*".*Test"',  # Test hook events
            ],
            'location_patterns': [
                r'\.claude/temp/.*',          # Temp directory files
                r'\.claude/logs/.*\.tmp$',    # Temp log files
                r'\..*\.swp$',               # Vim swap files
                r'\..*\.swo$',               # Vim swap files
                r'#.*#$',                    # Emacs backup files
                r'.*~$',                     # Backup files
            ]
        }
        
        # Safelist patterns - files to NEVER delete
        self.safelist_patterns = [
            r'\.git/.*',                     # Git files
            r'\.claude/agents/.*\.md$',      # Agent definitions
            r'\.claude/handlers/.*\.py$',    # Handler scripts
            r'\.serena/memories/.*',         # Memory files
            r'maps/.*',                      # Map files
            r'README.*\.md$',                # README files
            r'CHANGELOG\.md$',               # Changelog
            r'LICENSE.*',                    # License files
            r'package\.json$',               # Package files
            r'requirements\.txt$',           # Requirements
            r'setup\.py$',                   # Setup files
            r'.*\.py$',                      # Python source (unless in temp)
            r'.*\.ts$',                      # TypeScript source
            r'.*\.js$',                      # JavaScript source
            r'.*\.md$',                      # Documentation (unless temp)
        ]
        
        # Files to analyze more carefully (require content analysis)
        self.careful_analysis_extensions = {'.json', '.log', '.txt', '.yaml', '.yml'}
        
        self.stats = {
            'scanned': 0,
            'identified_test': 0,
            'safelist_protected': 0,
            'cleaned': 0,
            'backed_up': 0,
            'errors': 0
        }
        
    def setup_logging(self, log_level: str):
        """Setup logging configuration."""
        # Ensure log directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def is_safelist_protected(self, file_path: Path) -> bool:
        """Check if file is protected by safelist patterns."""
        path_str = str(file_path)
        for pattern in self.safelist_patterns:
            if re.match(pattern, path_str, re.IGNORECASE):
                self.logger.debug(f"Safelist protected: {file_path} (pattern: {pattern})")
                return True
        return False
        
    def matches_filename_pattern(self, file_path: Path) -> Tuple[bool, Optional[str]]:
        """Check if filename matches test patterns."""
        filename = file_path.name
        path_str = str(file_path)
        
        for pattern in self.test_patterns['filename_patterns']:
            if re.match(pattern, filename, re.IGNORECASE) or re.match(pattern, path_str, re.IGNORECASE):
                return True, pattern
        
        for pattern in self.test_patterns['location_patterns']:
            if re.match(pattern, path_str, re.IGNORECASE):
                return True, pattern
                
        return False, None
        
    def analyze_file_content(self, file_path: Path) -> Tuple[bool, List[str]]:
        """Analyze file content for test patterns."""
        if not file_path.exists() or file_path.is_dir():
            return False, []
            
        if file_path.suffix not in self.careful_analysis_extensions:
            return False, []
            
        try:
            # Read file content safely
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            matches = []
            for pattern in self.test_patterns['content_patterns']:
                if re.search(pattern, content, re.IGNORECASE):
                    matches.append(pattern)
                    
            return len(matches) > 0, matches
            
        except Exception as e:
            self.logger.warning(f"Could not read {file_path}: {e}")
            return False, []
            
    def is_recent_file(self, file_path: Path, max_age_hours: int = 24) -> bool:
        """Check if file was created/modified recently."""
        try:
            stat = file_path.stat()
            file_time = datetime.fromtimestamp(max(stat.st_mtime, stat.st_ctime))
            age = datetime.now() - file_time
            return age < timedelta(hours=max_age_hours)
        except Exception:
            return False
            
    def backup_file(self, file_path: Path) -> bool:
        """Backup file before deletion."""
        try:
            self.backup_dir.mkdir(parents=True, exist_ok=True)
            backup_path = self.backup_dir / file_path.relative_to('.')
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            
            shutil.copy2(file_path, backup_path)
            self.stats['backed_up'] += 1
            self.logger.info(f"Backed up: {file_path} -> {backup_path}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to backup {file_path}: {e}")
            return False
            
    def is_test_file(self, file_path: Path) -> Tuple[bool, Dict]:
        """Comprehensive test file identification."""
        analysis = {
            'path': str(file_path),
            'is_test': False,
            'reasons': [],
            'safelist_protected': False,
            'confidence': 0.0
        }
        
        # Check safelist protection first
        if self.is_safelist_protected(file_path):
            analysis['safelist_protected'] = True
            analysis['reasons'].append("Protected by safelist")
            self.stats['safelist_protected'] += 1
            return False, analysis
            
        confidence_score = 0.0
        
        # Filename pattern matching
        filename_match, pattern = self.matches_filename_pattern(file_path)
        if filename_match:
            confidence_score += 0.7
            analysis['reasons'].append(f"Filename pattern: {pattern}")
            
        # Content analysis
        content_match, content_patterns = self.analyze_file_content(file_path)
        if content_match:
            confidence_score += 0.8
            analysis['reasons'].append(f"Content patterns: {content_patterns}")
            
        # File age consideration (recent files more likely to be test)
        if self.is_recent_file(file_path, max_age_hours=24):
            confidence_score += 0.1
            analysis['reasons'].append("Recently created/modified")
            
        # Special considerations for JSON files
        if file_path.suffix == '.json':
            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    
                # Check for hook event test data
                if isinstance(data, dict):
                    if 'hook_event_name' in data and 'test' in str(data).lower():
                        confidence_score += 0.5
                        analysis['reasons'].append("Hook event test data")
                        
            except Exception:
                pass
                
        analysis['confidence'] = confidence_score
        analysis['is_test'] = confidence_score >= 0.7  # Require high confidence
        
        return analysis['is_test'], analysis
        
    def scan_directory(self, directory: Path = None) -> List[Tuple[Path, Dict]]:
        """Scan directory for test files."""
        if directory is None:
            directory = Path('.')
            
        test_files = []
        
        for root, dirs, files in os.walk(directory):
            root_path = Path(root)
            
            # Skip hidden directories except .claude
            dirs[:] = [d for d in dirs if not d.startswith('.') or d == '.claude']
            
            for file in files:
                file_path = root_path / file
                self.stats['scanned'] += 1
                
                is_test, analysis = self.is_test_file(file_path)
                if is_test:
                    test_files.append((file_path, analysis))
                    self.stats['identified_test'] += 1
                    
        return test_files
        
    def cleanup_files(self, test_files: List[Tuple[Path, Dict]]) -> bool:
        """Clean up identified test files."""
        if not test_files:
            self.logger.info("No test files identified for cleanup")
            return True
            
        self.logger.info(f"{'DRY RUN: Would clean' if self.dry_run else 'Cleaning'} {len(test_files)} test files")
        
        success = True
        for file_path, analysis in test_files:
            try:
                self.logger.info(f"{'Would remove' if self.dry_run else 'Removing'}: {file_path}")
                self.logger.info(f"  Reasons: {', '.join(analysis['reasons'])}")
                self.logger.info(f"  Confidence: {analysis['confidence']:.2f}")
                
                if not self.dry_run:
                    # Backup before deletion
                    if not self.backup_file(file_path):
                        self.logger.error(f"Skipping {file_path} - backup failed")
                        continue
                        
                    # Remove the file
                    file_path.unlink()
                    self.stats['cleaned'] += 1
                    self.logger.info(f"Successfully removed: {file_path}")
                    
            except Exception as e:
                self.logger.error(f"Failed to remove {file_path}: {e}")
                self.stats['errors'] += 1
                success = False
                
        return success
        
    def rollback(self, backup_timestamp: str = None) -> bool:
        """Rollback from backup directory."""
        if backup_timestamp:
            backup_path = Path(".cleanup_backup") / backup_timestamp
        else:
            # Use most recent backup
            backup_root = Path(".cleanup_backup")
            if not backup_root.exists():
                self.logger.error("No backup directory found")
                return False
                
            backups = [d for d in backup_root.iterdir() if d.is_dir()]
            if not backups:
                self.logger.error("No backups found")
                return False
                
            backup_path = max(backups, key=lambda x: x.name)
            
        self.logger.info(f"Rolling back from: {backup_path}")
        
        try:
            for root, dirs, files in os.walk(backup_path):
                for file in files:
                    backup_file = Path(root) / file
                    relative_path = backup_file.relative_to(backup_path)
                    restore_path = Path('.') / relative_path
                    
                    # Create parent directories if needed
                    restore_path.parent.mkdir(parents=True, exist_ok=True)
                    
                    # Restore file
                    shutil.copy2(backup_file, restore_path)
                    self.logger.info(f"Restored: {restore_path}")
                    
            return True
        except Exception as e:
            self.logger.error(f"Rollback failed: {e}")
            return False
            
    def print_report(self):
        """Print cleanup report."""
        print("\n" + "="*60)
        print("SAFE CLEANUP REPORT")
        print("="*60)
        print(f"Files scanned: {self.stats['scanned']}")
        print(f"Test files identified: {self.stats['identified_test']}")
        print(f"Safelist protected: {self.stats['safelist_protected']}")
        print(f"Files backed up: {self.stats['backed_up']}")
        print(f"Files cleaned: {self.stats['cleaned']}")
        print(f"Errors: {self.stats['errors']}")
        print(f"Log file: {self.log_file}")
        if self.stats['backed_up'] > 0:
            print(f"Backup directory: {self.backup_dir}")
        print("="*60)

def main():
    parser = argparse.ArgumentParser(description='Safe test file cleanup utility')
    parser.add_argument('--execute', action='store_true', 
                        help='Actually delete files (default is dry run)')
    parser.add_argument('--directory', type=str, default='.',
                        help='Directory to scan (default: current)')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                        default='INFO', help='Logging level')
    parser.add_argument('--rollback', type=str, 
                        help='Rollback from backup (specify timestamp or leave empty for latest)')
    
    args = parser.parse_args()
    
    cleanup = SafeCleanup(dry_run=not args.execute, log_level=args.log_level)
    
    if args.rollback is not None:
        success = cleanup.rollback(args.rollback)
        exit(0 if success else 1)
    
    try:
        # Scan for test files
        test_files = cleanup.scan_directory(Path(args.directory))
        
        # Clean up files
        success = cleanup.cleanup_files(test_files)
        
        # Print report
        cleanup.print_report()
        
        if not args.execute and test_files:
            print("\nThis was a DRY RUN. Use --execute to actually clean files.")
            
        exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\nCleanup interrupted by user")
        exit(1)
    except Exception as e:
        cleanup.logger.error(f"Cleanup failed: {e}")
        exit(1)

if __name__ == '__main__':
    main()