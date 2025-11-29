#!/usr/bin/env python3
"""
Generate package metadata files for each vLLM CPU variant.
Creates pyproject.toml and README.md for each build variant.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict


def load_config(config_path: str = "build_config.json") -> Dict[str, Any]:
    """Load build configuration with error handling."""
    try:
        config_file = Path(config_path)
        if not config_file.exists():
            print(f"Error: Configuration file not found: {config_path}", file=sys.stderr)
            sys.exit(1)

        if not config_file.is_file():
            print(f"Error: Configuration path is not a file: {config_path}", file=sys.stderr)
            sys.exit(1)

        with open(config_file, encoding="utf-8") as f:
            config = json.load(f)

        # Validate config structure
        if "builds" not in config:
            print("Error: 'builds' key not found in configuration", file=sys.stderr)
            sys.exit(1)

        if not isinstance(config["builds"], dict):
            print("Error: 'builds' must be a dictionary", file=sys.stderr)
            sys.exit(1)

        return config

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in configuration file: {e}", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Error: Permission denied reading: {config_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error loading configuration: {e}", file=sys.stderr)
        sys.exit(1)


def load_template(template_path: str) -> str:
    """Load template file with error handling."""
    try:
        template_file = Path(template_path)
        if not template_file.exists():
            print(f"Error: Template file not found: {template_path}", file=sys.stderr)
            sys.exit(1)

        with open(template_file, encoding="utf-8") as f:
            return f.read()

    except PermissionError:
        print(f"Error: Permission denied reading: {template_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error loading template: {e}", file=sys.stderr)
        sys.exit(1)


def validate_variant_config(variant_name: str, config: Dict[str, Any]) -> None:
    """Validate variant configuration."""
    required_keys = ["package_name", "description", "flags", "platforms", "keywords"]

    for key in required_keys:
        if key not in config:
            print(f"Error: '{key}' missing in variant '{variant_name}'", file=sys.stderr)
            sys.exit(1)

    # Validate package_name format
    package_name = config["package_name"]
    if not isinstance(package_name, str) or not package_name:
        print(f"Error: Invalid package_name in variant '{variant_name}'", file=sys.stderr)
        sys.exit(1)

    # Basic validation for PyPI package names
    if not all(c.isalnum() or c in "-_" for c in package_name):
        print(f"Error: Invalid characters in package_name '{package_name}'", file=sys.stderr)
        sys.exit(1)

    # Validate flags
    required_flags = ["disable_avx512", "enable_avx512vnni", "enable_avx512bf16", "enable_amxbf16"]
    if not isinstance(config["flags"], dict):
        print(f"Error: 'flags' must be a dictionary in variant '{variant_name}'", file=sys.stderr)
        sys.exit(1)

    for flag in required_flags:
        if flag not in config["flags"]:
            print(f"Error: Flag '{flag}' missing in variant '{variant_name}'", file=sys.stderr)
            sys.exit(1)


def sanitize_for_format(text: str) -> str:
    """Sanitize text for safe use in str.format()."""
    # Escape curly braces to prevent template injection
    return text.replace("{", "{{").replace("}", "}}")


def generate_readme(variant_name: str, config: Dict[str, Any], vllm_version: str) -> str:
    """Generate README.md for a variant."""

    validate_variant_config(variant_name, config)

    # Load template
    template = load_template("package_templates/README_template.md")

    # Build CPU requirements list
    flags = config["flags"]
    requirements = []

    if flags["disable_avx512"]:
        requirements.append("- **No special requirements** (base x86_64 or ARM64 CPU)")
    else:
        requirements.append("- **AVX512**: Advanced Vector Extensions 512")
        if flags["enable_avx512vnni"]:
            requirements.append("- **VNNI**: Vector Neural Network Instructions")
        if flags["enable_avx512bf16"]:
            requirements.append("- **BF16**: BFloat16 hardware acceleration")
        if flags["enable_amxbf16"]:
            requirements.append("- **AMX**: Advanced Matrix Extensions")

    cpu_req_text = "\n".join(requirements)

    # Build ISA features string
    isa_features = []
    if not flags["disable_avx512"]:
        isa_features.append("AVX512")
    if flags["enable_avx512vnni"]:
        isa_features.append("VNNI")
    if flags["enable_avx512bf16"]:
        isa_features.append("BF16")
    if flags["enable_amxbf16"]:
        isa_features.append("AMX")

    if not isa_features:
        isa_features_text = "baseline CPU features"
    else:
        isa_features_text = ", ".join(isa_features)

    # Build environment variables
    env_vars = []
    if flags["disable_avx512"]:
        env_vars.append("- `VLLM_CPU_DISABLE_AVX512=1`")
    if flags["enable_avx512vnni"]:
        env_vars.append("- `VLLM_CPU_AVX512VNNI=1`")
    if flags["enable_avx512bf16"]:
        env_vars.append("- `VLLM_CPU_AVX512BF16=1`")
    if flags["enable_amxbf16"]:
        env_vars.append("- `VLLM_CPU_AMXBF16=1`")

    env_vars_text = "\n".join(env_vars) if env_vars else ""

    # Sanitize user-controlled strings to prevent template injection
    safe_package_name = sanitize_for_format(config["package_name"])
    safe_description = sanitize_for_format(config["description"])

    # Replace placeholders
    try:
        content = template.format(
            PACKAGE_NAME=safe_package_name,
            DESCRIPTION=safe_description,
            ISA_FEATURES=isa_features_text,
            CPU_REQUIREMENTS=cpu_req_text,
            ENV_VARS=env_vars_text,
            VLLM_VERSION=vllm_version,
        )
        return content
    except KeyError as e:
        print(f"Error: Missing template placeholder: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error formatting README template: {e}", file=sys.stderr)
        sys.exit(1)


def generate_pyproject_toml(variant_name: str, config: Dict[str, Any], vllm_version: str) -> str:
    """Generate pyproject.toml for a variant."""

    validate_variant_config(variant_name, config)

    package_name = config["package_name"]
    description = config["description"]
    keywords = config["keywords"]

    # Validate keywords is a list
    if not isinstance(keywords, list):
        print(f"Error: 'keywords' must be a list in variant '{variant_name}'", file=sys.stderr)
        sys.exit(1)

    # Base dependencies
    dependencies = [
        'torch>=2.8.0',
        'transformers>=4.36.0',
        'numpy',
        'fastapi',
        'uvicorn[standard]',
        'pydantic',
    ]

    # Add Intel extensions for x86_64 builds
    if "x86_64" in config["platforms"]:
        dependencies.append('intel-extension-for-pytorch>=2.8.0')
        dependencies.append('intel-openmp>=2024.2.1')

    # Escape description for TOML (double quotes and backslashes)
    safe_description = description.replace('\\', '\\\\').replace('"', '\\"')

    # Use json.dumps for safe keyword serialization
    keywords_json = json.dumps(keywords, indent=2)

    content = f'''[build-system]
requires = ["setuptools>=77.0.3", "wheel", "cmake>=3.21", "ninja"]
build-backend = "setuptools.build_meta"

[project]
name = "{package_name}"
version = "{vllm_version}"
description = "{safe_description}"
readme = "README.md"
requires-python = ">=3.9"
license = {{text = "Apache-2.0"}}
authors = [
    {{name = "vLLM Team", email = "vllm-dev@lists.berkeley.edu"}},
]
keywords = {keywords_json}
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "Intended Audience :: Science/Research",
    "License :: OSI Approved :: Apache Software License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
    "Topic :: Scientific/Engineering :: Artificial Intelligence",
]

dependencies = {json.dumps(dependencies, indent=2)}

[project.urls]
Homepage = "https://github.com/vllm-project/vllm"
Documentation = "https://docs.vllm.ai/"
Repository = "https://github.com/vllm-project/vllm"
Changelog = "https://github.com/vllm-project/vllm/releases"

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "mypy>=1.0.0",
    "ruff>=0.1.0",
]

[tool.setuptools.packages.find]
where = ["."]
include = ["vllm*"]

[tool.setuptools.package-data]
vllm = ["*.so", "*.pyd", "*.dylib"]
'''

    return content


def generate_build_script(variant_name: str, config: Dict[str, Any]) -> str:
    """Generate a build script for the variant."""

    validate_variant_config(variant_name, config)

    flags = config["flags"]
    package_name = config["package_name"]

    env_exports = []
    env_exports.append("export VLLM_TARGET_DEVICE=cpu")

    if flags["disable_avx512"]:
        env_exports.append("export VLLM_CPU_DISABLE_AVX512=1")
    else:
        env_exports.append("export VLLM_CPU_DISABLE_AVX512=0")

    if flags["enable_avx512vnni"]:
        env_exports.append("export VLLM_CPU_AVX512VNNI=1")

    if flags["enable_avx512bf16"]:
        env_exports.append("export VLLM_CPU_AVX512BF16=1")

    if flags["enable_amxbf16"]:
        env_exports.append("export VLLM_CPU_AMXBF16=1")

    env_section = "\n".join(env_exports)

    # Sanitize package_name for use in script
    safe_package_name = package_name.replace("'", "'\\''")

    script = f'''#!/usr/bin/env bash
# Build script for {safe_package_name}

set -euo pipefail

echo "Building {safe_package_name}..."

# Set build flags
{env_section}

# Build wheel
python setup.py bdist_wheel --dist-dir=dist

echo "Build complete: {safe_package_name}"
ls -lh dist/
'''

    return script


def write_file_safely(file_path: Path, content: str) -> None:
    """Write file with error handling."""
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
    except PermissionError:
        print(f"Error: Permission denied writing to: {file_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error writing file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate package metadata for vLLM CPU variants"
    )
    parser.add_argument(
        "--vllm-version",
        default="0.11.2",
        help="vLLM version to use (default: 0.11.2)",
    )
    parser.add_argument(
        "--config",
        default="build_config.json",
        help="Path to build configuration file (default: build_config.json)",
    )
    parser.add_argument(
        "--output-dir",
        default="package_metadata",
        help="Output directory for generated files (default: package_metadata)",
    )
    return parser.parse_args()


def main():
    """Main function."""

    args = parse_args()

    # Load configuration
    config = load_config(args.config)
    vllm_version = args.vllm_version

    # Validate vllm_version format (basic check)
    if not vllm_version or not all(c.isdigit() or c == "." for c in vllm_version):
        print(f"Error: Invalid version format: {vllm_version}", file=sys.stderr)
        sys.exit(1)

    # Create output directory
    try:
        output_dir = Path(args.output_dir)
        output_dir.mkdir(exist_ok=True, parents=True)
    except Exception as e:
        print(f"Error creating output directory: {e}", file=sys.stderr)
        sys.exit(1)

    # Generate metadata for each variant
    for variant_name, variant_config in config["builds"].items():
        print(f"Generating metadata for {variant_name}...")

        try:
            # Create variant directory
            variant_dir = output_dir / variant_name
            variant_dir.mkdir(exist_ok=True, parents=True)

            # Generate files
            readme = generate_readme(variant_name, variant_config, vllm_version)
            pyproject = generate_pyproject_toml(variant_name, variant_config, vllm_version)
            build_script = generate_build_script(variant_name, variant_config)

            # Write files
            write_file_safely(variant_dir / "README.md", readme)
            write_file_safely(variant_dir / "pyproject.toml", pyproject)
            write_file_safely(variant_dir / "build.sh", build_script)

            # Make build script executable
            try:
                os.chmod(variant_dir / "build.sh", 0o755)
            except Exception as e:
                print(f"Warning: Failed to make build script executable: {e}", file=sys.stderr)

            print(f"  ✓ Created {variant_dir}/README.md")
            print(f"  ✓ Created {variant_dir}/pyproject.toml")
            print(f"  ✓ Created {variant_dir}/build.sh")

        except Exception as e:
            print(f"Error processing variant {variant_name}: {e}", file=sys.stderr)
            sys.exit(1)

    print("\nMetadata generation complete!")
    print(f"Output directory: {output_dir.absolute()}")


if __name__ == "__main__":
    main()
