# =============================================================================
# CPU Platform Fix - Injected into vllm/__init__.py during build
# =============================================================================
# This code creates a fake "vllm" package metadata entry with +cpu suffix
# so that vLLM's platform detection (vllm_version_matches_substr("cpu"))
# works correctly for pip-installed vllm-cpu packages.
#
# Why this is needed:
# - vLLM's cpu_platform_plugin() calls vllm_version_matches_substr("cpu")
# - This checks if "cpu" is in importlib.metadata.version("vllm")
# - PyPI doesn't allow +cpu suffix (PEP 440 forbids local version identifiers)
# - So we create a fake vllm dist-info with +cpu version at runtime
#
# This runs once on first import of vllm, creating the dist-info if needed.
# =============================================================================

def _ensure_cpu_platform_detection():
    """Create vllm package alias for CPU platform detection if needed."""
    import os
    import sys

    try:
        # Check if we're a vllm-cpu variant package
        from importlib.metadata import version, distributions

        # Find our actual package (vllm-cpu, vllm-cpu-avx512, etc.)
        cpu_version = None
        cpu_package = None
        cpu_dist_location = None
        for dist in distributions():
            name = dist.metadata.get('Name', '')
            if name.startswith('vllm-cpu'):
                cpu_version = dist.metadata.get('Version', '')
                cpu_package = name
                # Get the location of this distribution's metadata
                # dist._path is the path to the .dist-info directory
                try:
                    cpu_dist_location = str(dist._path.parent)
                except Exception:
                    pass
                break

        if not cpu_version:
            # Not a vllm-cpu package, skip
            return

        # Check if "vllm" already returns a cpu version
        try:
            vllm_ver = version("vllm")
            if "cpu" in vllm_ver.lower():
                # Already has cpu in version, nothing to do
                return
        except Exception:
            pass  # vllm package doesn't exist yet, we'll create it

        # Find site-packages directory - prefer the location where vllm-cpu is installed
        site_packages = cpu_dist_location
        if not site_packages or not os.path.isdir(site_packages):
            # Fallback: search sys.path for site-packages
            for path in sys.path:
                if 'site-packages' in path and os.path.isdir(path):
                    site_packages = path
                    break

        if not site_packages:
            return

        # Create fake vllm dist-info
        vllm_dist = os.path.join(site_packages, "vllm-0.0.0.dist-info")
        if os.path.exists(vllm_dist):
            return  # Already exists

        try:
            os.makedirs(vllm_dist, exist_ok=True)

            # Ensure version has +cpu suffix
            if "cpu" not in cpu_version.lower():
                cpu_version = f"{cpu_version}+cpu"

            # Write METADATA file
            metadata_path = os.path.join(vllm_dist, "METADATA")
            with open(metadata_path, "w") as f:
                f.write(f"Metadata-Version: 2.1\n")
                f.write(f"Name: vllm\n")
                f.write(f"Version: {cpu_version}\n")
                f.write(f"Summary: vLLM CPU package alias for platform detection\n")

            # Write minimal RECORD file (required for proper dist-info)
            record_path = os.path.join(vllm_dist, "RECORD")
            with open(record_path, "w") as f:
                f.write("vllm-0.0.0.dist-info/METADATA,,\n")
                f.write("vllm-0.0.0.dist-info/RECORD,,\n")

            # Invalidate importlib.metadata cache so it picks up the new dist-info
            try:
                from importlib import invalidate_caches
                invalidate_caches()
            except Exception:
                pass

        except (OSError, IOError):
            # Can't write to site-packages (e.g., system Python, no permissions)
            # This is fine - user can use the manual workaround or run in Docker
            pass

    except Exception:
        # Don't break vllm import if anything goes wrong
        pass

# Run the fix on import
_ensure_cpu_platform_detection()

# Clean up namespace
del _ensure_cpu_platform_detection

# =============================================================================
# End of CPU Platform Fix
# =============================================================================
