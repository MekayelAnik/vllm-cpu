#!/usr/bin/env python3
"""
Reorganize wheel files in dist/ directory to the structure:
vllm-<version>/python-<version>/<related whl files>
"""

import os
import shutil
import re
from pathlib import Path
from collections import defaultdict

# Configuration
DIST_DIR = Path("dist")
VERSION = "0.10.0"
TARGET_BASE = f"vllm-{VERSION}"

# Mapping from cpXYZ to python version
CP_TO_PY = {
    "cp310": "3.10",
    "cp311": "3.11",
    "cp312": "3.12",
}

def extract_python_version(filename):
    """Extract Python version from wheel filename (e.g., cp310, cp311)"""
    match = re.search(r'cp(\d)(\d+)', filename)
    if match:
        cp_version = f"cp{match.group(1)}{match.group(2)}"
        return CP_TO_PY.get(cp_version)
    return None

def find_all_wheels(base_dir):
    """Find all .whl files recursively in the directory"""
    wheels = []
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file.endswith('.whl'):
                wheels.append(Path(root) / file)
    return wheels

def organize_wheels():
    """Organize wheels into the target structure"""

    # Find all wheel files
    all_wheels = find_all_wheels(DIST_DIR)

    print(f"Found {len(all_wheels)} wheel files")

    # Group wheels by their target location
    target_groups = defaultdict(list)

    for wheel_path in all_wheels:
        filename = wheel_path.name
        py_version = extract_python_version(filename)

        if py_version:
            target_dir = DIST_DIR / TARGET_BASE / f"python-{py_version}"
            target_path = target_dir / filename
            target_groups[target_path].append(wheel_path)
        else:
            print(f"Warning: Could not determine Python version for {filename}")

    # Create target directories and move files
    moved_files = set()

    for target_path, source_paths in target_groups.items():
        # Create target directory
        target_path.parent.mkdir(parents=True, exist_ok=True)

        # Use the first source (they should all be the same file)
        source_path = source_paths[0]

        # Only move if not already in the correct location
        if source_path != target_path:
            if target_path.exists():
                print(f"Target already exists: {target_path}")
            else:
                print(f"Moving: {source_path} -> {target_path}")
                shutil.copy2(source_path, target_path)

        moved_files.add(source_path)

        # Mark duplicates
        if len(source_paths) > 1:
            print(f"Found {len(source_paths)} copies of {target_path.name}")

    return moved_files

def cleanup_old_structure(moved_files):
    """Remove old directories and duplicate files"""

    # Remove all old wheel files
    for wheel_path in moved_files:
        # Only remove if it's not in the target structure
        if not str(wheel_path).startswith(str(DIST_DIR / TARGET_BASE)):
            try:
                print(f"Removing: {wheel_path}")
                wheel_path.unlink()
            except Exception as e:
                print(f"Error removing {wheel_path}: {e}")

    # Remove empty directories and old version directories
    dirs_to_check = [
        DIST_DIR / "vllm-v0.10.0",
        DIST_DIR / "vllm-0.10.0",
    ]

    for dir_path in dirs_to_check:
        if dir_path.exists() and dir_path != DIST_DIR / TARGET_BASE:
            try:
                # Only remove if empty or not our target
                if dir_path.name != TARGET_BASE:
                    print(f"Removing old directory: {dir_path}")
                    shutil.rmtree(dir_path)
            except Exception as e:
                print(f"Error removing {dir_path}: {e}")

def print_final_structure():
    """Print the final directory structure"""
    print("\n" + "="*60)
    print("Final structure:")
    print("="*60)

    target_dir = DIST_DIR / TARGET_BASE
    if target_dir.exists():
        for py_dir in sorted(target_dir.iterdir()):
            if py_dir.is_dir():
                print(f"\n{py_dir.relative_to(DIST_DIR)}/")
                wheels = sorted(py_dir.glob("*.whl"))
                for wheel in wheels:
                    print(f"  - {wheel.name}")
    else:
        print(f"Target directory not found: {target_dir}")

if __name__ == "__main__":
    print("Starting reorganization of dist/ directory...")
    print(f"Target structure: {TARGET_BASE}/python-<version>/\n")

    # Organize wheels
    moved_files = organize_wheels()

    print(f"\nOrganization complete. Processed {len(moved_files)} files.")

    # Ask for confirmation before cleanup
    print("\n" + "="*60)
    response = input("Do you want to remove old files and directories? (yes/no): ")

    if response.lower() in ['yes', 'y']:
        cleanup_old_structure(moved_files)
        print("\nCleanup complete.")
    else:
        print("\nSkipping cleanup. Old files remain.")

    # Print final structure
    print_final_structure()
