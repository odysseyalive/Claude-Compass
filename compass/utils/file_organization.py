#!/usr/bin/env python3
"""
COMPASS File Organization Utility
Provides centralized file path management and organization for COMPASS agents
Prevents root directory cluttering by enforcing proper directory structure
"""

import os
from pathlib import Path
from datetime import datetime
import json


class CompassFileOrganizer:
    """Centralized file organization utility for COMPASS system"""
    
    def __init__(self, project_root=None):
        self.project_root = Path(project_root or os.getcwd())
        self.docs_dir = self.project_root / "docs"
        self.maps_dir = self.project_root / "maps"
        self.compass_dir = self.project_root / ".compass"
        self.tests_dir = self.compass_dir / "tests"
        self.logs_dir = self.compass_dir / "logs"
        self.temp_dir = self.compass_dir / "temp"
        
        # Ensure directory structure exists
        self._ensure_directories()
    
    def _ensure_directories(self):
        """Ensure all required directories exist"""
        directories = [
            self.docs_dir,
            self.docs_dir / "agents",
            self.docs_dir / "investigations", 
            self.docs_dir / "validations",
            self.maps_dir,
            self.tests_dir,
            self.logs_dir,
            self.temp_dir
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
    
    def get_documentation_path(self, filename, category="general"):
        """Get proper path for documentation files
        
        Args:
            filename: Name of the file (with .md extension)
            category: Type of documentation (agents, investigations, validations, general)
        
        Returns:
            Path object for the documentation file
        """
        if not filename.endswith('.md'):
            filename += '.md'
        
        category_map = {
            "agents": self.docs_dir / "agents",
            "investigations": self.docs_dir / "investigations", 
            "validations": self.docs_dir / "validations",
            "general": self.docs_dir
        }
        
        base_dir = category_map.get(category, self.docs_dir)
        return base_dir / filename
    
    def get_test_path(self, filename):
        """Get proper path for test files
        
        Args:
            filename: Name of the test file
        
        Returns:
            Path object for the test file
        """
        if not filename.endswith('.md'):
            filename += '.md'
        
        return self.tests_dir / filename
    
    def get_temp_path(self, filename):
        """Get proper path for temporary files
        
        Args:
            filename: Name of the temporary file
        
        Returns:
            Path object for the temporary file
        """
        return self.temp_dir / filename
    
    def get_map_path(self, filename):
        """Get proper path for map/SVG files
        
        Args:
            filename: Name of the map file (with .svg extension)
        
        Returns:
            Path object for the map file
        """
        if not filename.endswith('.svg'):
            filename += '.svg'
        
        return self.maps_dir / filename
    
    def validate_path_safety(self, filepath):
        """Validate that a file path doesn't write to project root
        
        Args:
            filepath: Path to validate (string or Path object)
        
        Returns:
            bool: True if path is safe, False if it would write to root
        """
        path = Path(filepath)
        
        # Check if path is absolute and outside project
        if path.is_absolute() and not str(path).startswith(str(self.project_root)):
            return True  # Outside project, assume safe
        
        # Resolve relative paths
        if not path.is_absolute():
            path = self.project_root / path
        
        # Check if resolved path is directly in project root
        try:
            relative_to_root = path.relative_to(self.project_root)
            # If there are no path parts beyond filename, it's in root
            return len(relative_to_root.parts) > 1
        except ValueError:
            # Path is outside project root
            return True
    
    def redirect_root_path(self, filepath, file_type="documentation"):
        """Redirect a root-level path to proper directory
        
        Args:
            filepath: Original file path that would be in root
            file_type: Type of file (documentation, test, temp, map)
        
        Returns:
            Path object for the properly organized location
        """
        filename = Path(filepath).name
        
        if file_type == "documentation":
            return self.get_documentation_path(filename)
        elif file_type == "test":
            return self.get_test_path(filename)
        elif file_type == "temp":
            return self.get_temp_path(filename)
        elif file_type == "map":
            return self.get_map_path(filename)
        else:
            # Default to docs for unknown types
            return self.get_documentation_path(filename)
    
    def cleanup_temp_files(self, max_age_hours=24):
        """Clean up temporary files older than specified age
        
        Args:
            max_age_hours: Maximum age in hours before deletion
        """
        cutoff_time = datetime.now().timestamp() - (max_age_hours * 3600)
        
        for temp_file in self.temp_dir.glob("*"):
            if temp_file.is_file() and temp_file.stat().st_mtime < cutoff_time:
                try:
                    temp_file.unlink()
                    print(f"Cleaned up old temp file: {temp_file}")
                except Exception as e:
                    print(f"Failed to clean up {temp_file}: {e}")
    
    def log_file_operation(self, operation, filepath, redirected_path=None):
        """Log file operations for audit trail
        
        Args:
            operation: Type of operation (create, move, redirect)
            filepath: Original file path
            redirected_path: New path if redirected
        """
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "operation": operation,
            "original_path": str(filepath),
            "redirected_path": str(redirected_path) if redirected_path else None,
            "utility": "compass_file_organizer"
        }
        
        log_file = self.logs_dir / "file_organization.log"
        try:
            with open(log_file, "a") as f:
                f.write(json.dumps(log_entry) + "\n")
        except Exception:
            # Fail silently if logging fails
            pass


def get_safe_file_path(filename, file_type="documentation", category="general"):
    """Convenience function to get properly organized file path
    
    Args:
        filename: Name of the file
        file_type: Type of file (documentation, test, temp, map)
        category: Category for documentation files
    
    Returns:
        String path for the properly organized file location
    """
    organizer = CompassFileOrganizer()
    
    if file_type == "documentation":
        return str(organizer.get_documentation_path(filename, category))
    elif file_type == "test":
        return str(organizer.get_test_path(filename))
    elif file_type == "temp":
        return str(organizer.get_temp_path(filename))
    elif file_type == "map":
        return str(organizer.get_map_path(filename))
    else:
        return str(organizer.get_documentation_path(filename))


def validate_file_path_safety(filepath):
    """Convenience function to validate file path safety
    
    Args:
        filepath: Path to validate
    
    Returns:
        bool: True if path is safe, False if it writes to root
    """
    organizer = CompassFileOrganizer()
    return organizer.validate_path_safety(filepath)


if __name__ == "__main__":
    # Example usage and testing
    organizer = CompassFileOrganizer()
    
    # Test path validation
    safe_paths = [
        "docs/test.md",
        "maps/diagram.svg", 
        ".compass/tests/test.md"
    ]
    
    unsafe_paths = [
        "test.md",
        "validation.md",
        "jung-integration.md"
    ]
    
    print("Testing path validation:")
    for path in safe_paths:
        result = organizer.validate_path_safety(path)
        print(f"  {path}: {'SAFE' if result else 'UNSAFE'}")
    
    for path in unsafe_paths:
        result = organizer.validate_path_safety(path)
        print(f"  {path}: {'SAFE' if result else 'UNSAFE'}")
        if not result:
            redirected = organizer.redirect_root_path(path, "documentation")
            print(f"    -> Redirect to: {redirected}")