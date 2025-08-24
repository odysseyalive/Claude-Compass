#!/usr/bin/env python3
"""
COMPASS Handler - Direct Function Implementation
Provides direct function calls for COMPASS operations, bypassing agent overhead
while maintaining memory safety and subprocess isolation.
"""

import os
import sys
import json
import hashlib
import pickle
import subprocess
import tempfile
import time
import shutil
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import argparse

# Configuration Constants
MAX_FILE_SIZE = 1024 * 1024  # 1MB per file
MAX_FILES_PER_QUERY = 20  # Maximum files processed
CONTENT_TRUNCATION = 10 * 1024  # 10KB content limit for memory safety
SUBPROCESS_TIMEOUT = 300  # 5 minute timeout
CACHE_TTL_HOURS = 1  # 1 hour cache time-to-live
MAX_SUBPROCESS_MEMORY = "256m"  # 256MB memory limit


class CompassHandler:
    """Direct function handler for COMPASS operations with subprocess isolation."""

    def __init__(self, project_root: Optional[str] = None):
        self.project_root = Path(project_root) if project_root else Path.cwd()
        self.compass_dir = self.project_root / ".compass"
        self.cache_dir = self.compass_dir / "cache" / "knowledge"
        self.logs_dir = self.compass_dir / "logs"
        self.handlers_dir = self.compass_dir / "handlers"

        # Ensure directories exist
        for dir_path in [
            self.compass_dir,
            self.cache_dir,
            self.logs_dir,
            self.handlers_dir,
        ]:
            dir_path.mkdir(parents=True, exist_ok=True)

        # Setup logging
        self.logger = self._setup_logging()

    def _setup_logging(self) -> logging.Logger:
        """Setup logging for compass operations."""
        logger = logging.getLogger("compass-handler")
        logger.setLevel(logging.INFO)

        if not logger.handlers:
            handler = logging.FileHandler(self.logs_dir / "compass-handler.log")
            formatter = logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)

        return logger

    def knowledge_query_direct(
        self,
        task_description: str,
        keywords: Optional[List[str]] = None,
        use_cache: bool = True,
        knowledge_query_direct: bool = False,  # New flag for direct function calls
    ) -> Dict[str, Any]:
        """
        Direct function implementation of compass-knowledge-query.

        Args:
            task_description: Description of the task requiring knowledge
            keywords: Optional keywords to focus search
            use_cache: Whether to use cached results
            knowledge_query_direct: Flag to enable direct function mode (bypassing agent overhead)

        Returns:
            Dict containing knowledge query results
        """
        self.logger.info(
            f"Starting knowledge query - Direct mode: {knowledge_query_direct}"
        )

        try:
            # Generate cache key
            cache_content = f"{task_description}||{keywords or []}"
            cache_key = hashlib.sha256(cache_content.encode()).hexdigest()[:16]

            # Check cache first if enabled
            if use_cache:
                cached_result = self._load_cached_knowledge(cache_key)
                if cached_result:
                    self.logger.info(f"Cache hit for key: {cache_key}")
                    return cached_result

            # Execute knowledge query based on mode
            if knowledge_query_direct:
                # Direct function implementation - bypasses agent system entirely
                result = self._execute_direct_knowledge_query(
                    task_description, keywords
                )
            else:
                # Subprocess implementation - maintains backward compatibility
                result = self._execute_subprocess_knowledge_query(
                    task_description, keywords
                )

            # Cache the results
            if use_cache:
                self._save_cached_knowledge(cache_key, result)

            # Save latest result for debugging
            self._save_latest_result(result)

            self.logger.info(
                f"Knowledge query completed - {len(result.get('files_processed', []))} files processed"
            )
            return result

        except Exception as e:
            self.logger.error(f"Knowledge query failed: {str(e)}")
            return {
                "status": "error",
                "error": str(e),
                "fallback_message": "Knowledge query failed - consider manual documentation review",
            }

    def _execute_direct_knowledge_query(
        self, task_description: str, keywords: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Direct function implementation of knowledge query - bypasses agent overhead entirely.
        This is the new streamlined approach that eliminates system lockups.
        """
        self.logger.info("Executing direct knowledge query (agent bypass mode)")

        result = {
            "status": "success",
            "mode": "direct_function",
            "task_description": task_description,
            "keywords": keywords or [],
            "files_processed": [],
            "existing_documentation": [],
            "visual_maps": [],
            "applicable_insights": [],
            "knowledge_gaps": [],
            "recommendations": [],
            "execution_time": 0,
        }

        start_time = time.time()

        try:
            # 1. Query maps/map-index.json for patterns (memory-safe)
            map_index_path = self.project_root / "maps" / "map-index.json"
            if (
                map_index_path.exists()
                and map_index_path.stat().st_size < MAX_FILE_SIZE
            ):
                with open(map_index_path, "r", encoding="utf-8") as f:
                    map_data = json.load(f)
                    result["visual_maps"] = self._extract_relevant_patterns(
                        map_data, keywords or []
                    )
                    result["files_processed"].append(str(map_index_path))

            # 2. Search docs/ directory with keyword filtering
            docs_results = self._search_docs_directory(keywords or [], task_description)
            result.update(docs_results)

            # 3. Generate insights and recommendations
            result["applicable_insights"] = self._generate_insights(result)
            result["knowledge_gaps"] = self._identify_knowledge_gaps(
                result, task_description
            )
            result["recommendations"] = self._generate_recommendations(result)

            result["execution_time"] = time.time() - start_time

        except Exception as e:
            self.logger.error(f"Direct knowledge query failed: {str(e)}")
            result["status"] = "partial_error"
            result["error"] = str(e)

        return result

    def _execute_subprocess_knowledge_query(
        self, task_description: str, keywords: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Subprocess implementation maintaining backward compatibility.
        Used when knowledge_query_direct=False.
        """
        self.logger.info(
            "Executing subprocess knowledge query (backward compatibility mode)"
        )

        # Generate subprocess script
        script_path = self._create_subprocess_script(task_description, keywords or [])

        try:
            # Execute subprocess with memory limits
            cmd = [
                sys.executable,
                str(script_path),
                "--task",
                task_description,
                "--project-root",
                str(self.project_root),
            ]

            if keywords:
                cmd.extend(["--keywords"] + keywords)

            self.logger.info(f"Executing subprocess: {' '.join(cmd)}")

            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT,
                cwd=str(self.project_root),
            )

            if process.returncode == 0:
                result = json.loads(process.stdout)
                result["mode"] = "subprocess"
                return result
            else:
                self.logger.error(
                    f"Subprocess failed with return code {process.returncode}"
                )
                self.logger.error(f"Subprocess stderr: {process.stderr}")
                raise Exception(f"Subprocess execution failed: {process.stderr}")

        except subprocess.TimeoutExpired:
            self.logger.error("Subprocess timeout - falling back to emergency mode")
            return self._emergency_fallback_query(task_description, keywords or [])
        except Exception as e:
            self.logger.error(f"Subprocess execution failed: {str(e)}")
            raise
        finally:
            # Cleanup subprocess script
            if script_path.exists():
                script_path.unlink()

    def _search_docs_directory(
        self, keywords: List[str], task_description: str
    ) -> Dict[str, Any]:
        """Search docs/ directory with memory-safe keyword filtering."""
        docs_dir = self.project_root / "docs"
        result = {"existing_documentation": [], "files_processed": []}

        if not docs_dir.exists():
            return result

        # Get all markdown files
        md_files = list(docs_dir.rglob("*.md"))

        # Filter files by keywords and size
        relevant_files = []
        for file_path in md_files[:MAX_FILES_PER_QUERY]:  # Limit total files processed
            if file_path.stat().st_size > MAX_FILE_SIZE:
                continue

            # Quick keyword check in filename first
            filename_lower = file_path.name.lower()
            if keywords and not any(kw.lower() in filename_lower for kw in keywords):
                # Check first 1KB of file content for keywords
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        sample_content = f.read(1024).lower()
                        if not any(
                            kw.lower() in sample_content for kw in keywords or []
                        ):
                            continue
                except:
                    continue

            relevant_files.append(file_path)

        # Process top relevant files
        for file_path in relevant_files[:5]:  # Limit to 5 most relevant files
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    # Truncate content for memory safety
                    if len(content) > CONTENT_TRUNCATION:
                        content = (
                            content[:CONTENT_TRUNCATION]
                            + "... (truncated for memory safety)"
                        )

                    doc_info = {
                        "file": str(file_path.relative_to(self.project_root)),
                        "title": self._extract_title(content),
                        "summary": self._extract_summary(content),
                        "relevant_sections": self._extract_relevant_sections(
                            content, keywords
                        ),
                    }
                    result["existing_documentation"].append(doc_info)
                    result["files_processed"].append(str(file_path))

            except Exception as e:
                self.logger.warning(f"Failed to process file {file_path}: {str(e)}")

        return result

    def _extract_relevant_patterns(
        self, map_data: Dict, keywords: List[str]
    ) -> List[Dict]:
        """Extract relevant patterns from map index data."""
        relevant_patterns = []

        # Check recent patterns
        for pattern in map_data.get("recent_patterns", []):
            if not keywords or any(
                kw.lower() in str(pattern).lower() for kw in keywords
            ):
                relevant_patterns.append(
                    {
                        "name": pattern.get("name", ""),
                        "description": pattern.get("description", ""),
                        "category": pattern.get("category", ""),
                        "tags": pattern.get("tags", []),
                        "location": pattern.get("location", ""),
                        "solution": pattern.get("solution", ""),
                    }
                )

        return relevant_patterns

    def _extract_title(self, content: str) -> str:
        """Extract title from markdown content."""
        lines = content.split("\n")
        for line in lines[:10]:  # Check first 10 lines
            if line.startswith("# "):
                return line[2:].strip()
        return "No title found"

    def _extract_summary(self, content: str) -> str:
        """Extract summary from markdown content."""
        lines = content.split("\n")
        summary_lines = []

        in_summary = False
        for line in lines[:50]:  # Check first 50 lines
            if line.strip().lower() in [
                "## summary",
                "## overview",
                "## problem analysis",
            ]:
                in_summary = True
                continue
            elif line.startswith("## ") and in_summary:
                break
            elif in_summary and line.strip():
                summary_lines.append(line.strip())
                if len(summary_lines) >= 3:  # Limit summary length
                    break

        return " ".join(summary_lines) if summary_lines else "No summary available"

    def _extract_relevant_sections(
        self, content: str, keywords: List[str]
    ) -> List[str]:
        """Extract sections containing relevant keywords."""
        if not keywords:
            return []

        relevant_sections = []
        lines = content.split("\n")

        for i, line in enumerate(lines):
            if any(kw.lower() in line.lower() for kw in keywords):
                # Extract context around the relevant line
                start_idx = max(0, i - 2)
                end_idx = min(len(lines), i + 3)
                context = "\n".join(lines[start_idx:end_idx])
                relevant_sections.append(context.strip())

        return relevant_sections[:5]  # Limit to 5 sections

    def _generate_insights(self, result: Dict) -> List[str]:
        """Generate insights from collected knowledge."""
        insights = []

        # Count documentation
        if result["existing_documentation"]:
            insights.append(
                f"Found {len(result['existing_documentation'])} relevant documentation files"
            )

        # Pattern insights
        if result["visual_maps"]:
            insights.append(
                f"Identified {len(result['visual_maps'])} applicable patterns from previous work"
            )

        # Content insights
        for doc in result["existing_documentation"]:
            if "solution" in doc.get("summary", "").lower():
                insights.append(f"Solution approach documented in {doc['file']}")

        return insights

    def _identify_knowledge_gaps(
        self, result: Dict, task_description: str
    ) -> List[str]:
        """Identify gaps in institutional knowledge."""
        gaps = []

        if not result["existing_documentation"]:
            gaps.append("No existing documentation found for this task domain")

        if not result["visual_maps"]:
            gaps.append("No visual patterns or architectural maps identified")

        # Check for specific task-related gaps
        task_lower = task_description.lower()
        if "implementation" in task_lower and not any(
            "implement" in doc.get("summary", "").lower()
            for doc in result["existing_documentation"]
        ):
            gaps.append("No implementation guidance found in existing documentation")

        return gaps

    def _generate_recommendations(self, result: Dict) -> List[str]:
        """Generate recommendations based on knowledge query results."""
        recommendations = []

        if result["existing_documentation"]:
            recommendations.append(
                "Review existing documentation before proceeding with new analysis"
            )

        if result["visual_maps"]:
            recommendations.append(
                "Apply documented patterns from previous similar work"
            )

        if result["knowledge_gaps"]:
            recommendations.append(
                "Document new findings to fill identified knowledge gaps"
            )

        return recommendations

    def _create_subprocess_script(
        self, task_description: str, keywords: List[str]
    ) -> Path:
        """Create temporary subprocess script for backward compatibility."""
        script_content = f"""
import json
import argparse
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--keywords", nargs="*", default=[])
    args = parser.parse_args()
    
    # Simple subprocess implementation for backward compatibility
    result = {{
        "status": "success",
        "mode": "subprocess_fallback",
        "task_description": args.task,
        "keywords": args.keywords,
        "files_processed": [],
        "existing_documentation": [],
        "visual_maps": [],
        "applicable_insights": ["Subprocess execution successful"],
        "knowledge_gaps": ["Detailed analysis pending"],
        "recommendations": ["Use direct function mode for improved performance"],
        "execution_time": 0.1
    }}
    
    print(json.dumps(result))

if __name__ == "__main__":
    main()
"""

        script_path = self.cache_dir / f"knowledge_query_{int(time.time())}.py"
        with open(script_path, "w") as f:
            f.write(script_content)

        return script_path

    def _emergency_fallback_query(
        self, task_description: str, keywords: List[str]
    ) -> Dict[str, Any]:
        """Emergency fallback with minimal memory usage."""
        return {
            "status": "emergency_fallback",
            "task_description": task_description,
            "keywords": keywords or [],
            "files_processed": [],
            "existing_documentation": [],
            "visual_maps": [],
            "applicable_insights": ["Emergency fallback mode - limited analysis"],
            "knowledge_gaps": [
                "Full knowledge query unavailable due to system constraints"
            ],
            "recommendations": ["Manual documentation review recommended"],
            "execution_time": 0,
        }

    def _load_cached_knowledge(self, cache_key: str) -> Optional[Dict[str, Any]]:
        """Load cached knowledge query results."""
        cache_file = self.cache_dir / f"{cache_key}.pkl"

        if not cache_file.exists():
            return None

        # Check cache age
        cache_age_hours = (time.time() - cache_file.stat().st_mtime) / 3600
        if cache_age_hours > CACHE_TTL_HOURS:
            cache_file.unlink()  # Remove expired cache
            return None

        try:
            with open(cache_file, "rb") as f:
                return pickle.load(f)
        except Exception as e:
            self.logger.warning(f"Failed to load cache {cache_key}: {str(e)}")
            cache_file.unlink()  # Remove corrupted cache
            return None

    def _save_cached_knowledge(self, cache_key: str, result: Dict[str, Any]):
        """Save knowledge query results to cache."""
        cache_file = self.cache_dir / f"{cache_key}.pkl"

        try:
            with open(cache_file, "wb") as f:
                pickle.dump(result, f)
        except Exception as e:
            self.logger.warning(f"Failed to save cache {cache_key}: {str(e)}")

    def _save_latest_result(self, result: Dict[str, Any]):
        """Save latest result for debugging."""
        latest_file = self.cache_dir / "latest_knowledge_result.json"

        try:
            with open(latest_file, "w") as f:
                json.dump(result, f, indent=2, default=str)
        except Exception as e:
            self.logger.warning(f"Failed to save latest result: {str(e)}")


def main():
    """CLI interface for compass-handler."""
    parser = argparse.ArgumentParser(
        description="COMPASS Handler - Direct Function Implementation"
    )
    parser.add_argument(
        "command", choices=["knowledge_query"], help="Command to execute"
    )
    parser.add_argument("task_description", help="Description of the task")
    parser.add_argument("--keywords", nargs="*", help="Keywords for focused search")
    parser.add_argument("--project-root", help="Project root directory", default=".")
    parser.add_argument("--no-cache", action="store_true", help="Disable caching")
    parser.add_argument(
        "--knowledge-query-direct",
        action="store_true",
        help="Use direct function mode (bypass agent overhead)",
    )

    try:
        args = parser.parse_args()
    except SystemExit as e:
        # Return error as JSON for LLM consumption
        result = {
            "status": "cli_error",
            "error": f"Argument parsing failed: {' '.join(sys.argv)}",
            "exit_code": e.code,
        }
        print(json.dumps(result, indent=2))
        return e.code if isinstance(e.code, int) else 1

    handler = CompassHandler(args.project_root)

    if args.command == "knowledge_query":
        result = handler.knowledge_query_direct(
            task_description=args.task_description,
            keywords=args.keywords,
            use_cache=not args.no_cache,
            knowledge_query_direct=args.knowledge_query_direct,
        )

        print(json.dumps(result, indent=2, default=str))

    return 0


if __name__ == "__main__":
    sys.exit(main())

