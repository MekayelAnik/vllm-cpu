#!/usr/bin/env python3
"""
CPU detection tool for vLLM CPU builds.
Recommends the optimal vLLM CPU package based on detected CPU features.
"""

import platform
import re
import subprocess
import sys
from typing import Dict, List, Optional


class CPUDetector:
    """Detect CPU features and recommend vLM CPU package."""

    def __init__(self):
        self.machine = platform.machine()
        self.system = platform.system()
        self.features: Dict[str, bool] = {}

    def detect(self) -> Dict[str, bool]:
        """Detect CPU features."""
        if self.system == "Linux":
            return self._detect_linux()
        elif self.system == "Darwin":
            return self._detect_macos()
        elif self.system == "Windows":
            return self._detect_windows()
        else:
            print(f"Unsupported operating system: {self.system}")
            return {}

    def _detect_linux(self) -> Dict[str, bool]:
        """Detect CPU features on Linux."""
        features = {
            "avx512f": False,
            "avx512_vnni": False,
            "avx512_bf16": False,
            "amx_bf16": False,
            "amx_tile": False,
            "amx_int8": False,
        }

        try:
            # Read /proc/cpuinfo
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read().lower()

            # Check for features
            if "avx512f" in cpuinfo:
                features["avx512f"] = True
            if "avx512_vnni" in cpuinfo or "avx512vnni" in cpuinfo:
                features["avx512_vnni"] = True
            if "avx512_bf16" in cpuinfo or "avx512bf16" in cpuinfo:
                features["avx512_bf16"] = True
            if "amx_bf16" in cpuinfo:
                features["amx_bf16"] = True
            if "amx_tile" in cpuinfo:
                features["amx_tile"] = True
            if "amx_int8" in cpuinfo:
                features["amx_int8"] = True

        except FileNotFoundError:
            print("Could not read /proc/cpuinfo")

        # Try lscpu as fallback
        try:
            result = subprocess.run(
                ["lscpu"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                lscpu_output = result.stdout.lower()
                if "avx512f" in lscpu_output:
                    features["avx512f"] = True
                if "avx512_vnni" in lscpu_output or "avx512vnni" in lscpu_output:
                    features["avx512_vnni"] = True
                if "avx512_bf16" in lscpu_output or "avx512bf16" in lscpu_output:
                    features["avx512_bf16"] = True
                if "amx_bf16" in lscpu_output:
                    features["amx_bf16"] = True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        self.features = features
        return features

    def _detect_macos(self) -> Dict[str, bool]:
        """Detect CPU features on macOS."""
        features = {
            "avx512f": False,
            "avx512_vnni": False,
            "avx512_bf16": False,
            "amx_bf16": False,
        }

        try:
            result = subprocess.run(
                ["sysctl", "-a"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                sysctl_output = result.stdout.lower()

                # Check for AVX512
                if "avx512" in sysctl_output:
                    features["avx512f"] = True

        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        self.features = features
        return features

    def _detect_windows(self) -> Dict[str, bool]:
        """Detect CPU features on Windows."""
        features = {
            "avx512f": False,
            "avx512_vnni": False,
            "avx512_bf16": False,
            "amx_bf16": False,
        }

        # On Windows, we'd need to use CPUID or WMI
        # For now, return empty features
        print("Windows CPU detection not yet implemented")
        print("Please check CPU features manually")

        self.features = features
        return features

    def get_cpu_info(self) -> str:
        """Get CPU model information."""
        if self.system == "Linux":
            try:
                with open("/proc/cpuinfo", "r") as f:
                    for line in f:
                        if line.startswith("model name"):
                            return line.split(":")[1].strip()
            except FileNotFoundError:
                pass

        # Fallback to platform
        return platform.processor() or "Unknown CPU"

    def recommend_package(self) -> str:
        """Recommend the best vLLM CPU package."""

        # ARM64 - use base package
        if self.machine in ["aarch64", "arm64"]:
            return "vllm-cpu"

        # x86_64 - check features
        if self.machine == "x86_64":
            # Check for AMX (best)
            if (
                self.features.get("amx_bf16")
                and self.features.get("avx512_bf16")
                and self.features.get("avx512_vnni")
            ):
                return "vllm-cpu-amxbf16"

            # Check for BF16
            if self.features.get("avx512_bf16") and self.features.get("avx512_vnni"):
                return "vllm-cpu-avx512bf16"

            # Check for VNNI
            if self.features.get("avx512_vnni"):
                return "vllm-cpu-avx512vnni"

            # Check for basic AVX512
            if self.features.get("avx512f"):
                return "vllm-cpu-avx512"

        # Default to base package
        return "vllm-cpu"

    def print_report(self):
        """Print detection report."""
        print("=" * 70)
        print("vLLM CPU Package Detector")
        print("=" * 70)
        print()

        print(f"System:       {self.system}")
        print(f"Architecture: {self.machine}")
        print(f"CPU Model:    {self.get_cpu_info()}")
        print()

        print("Detected CPU Features:")
        print("-" * 70)

        if not self.features:
            print("  (No features detected)")
        else:
            for feature, supported in sorted(self.features.items()):
                status = "✓" if supported else "✗"
                print(f"  {status} {feature.upper():<20} {'Supported' if supported else 'Not Supported'}")

        print()
        print("Recommended Package:")
        print("-" * 70)

        package = self.recommend_package()
        print(f"  {package}")
        print()

        print("Installation Command:")
        print("-" * 70)
        print(f"  pip install {package}")
        print()

        # Print alternative packages
        print("All Available Packages:")
        print("-" * 70)
        packages = [
            ("vllm-cpu", "Base package (no AVX512, supports ARM64 & x86_64)"),
            ("vllm-cpu-avx512", "AVX512 optimized (Intel Skylake-X and newer)"),
            ("vllm-cpu-avx512vnni", "AVX512 + VNNI (Intel Cascade Lake and newer)"),
            ("vllm-cpu-avx512bf16", "AVX512 + VNNI + BF16 (Intel Cooper Lake and newer)"),
            ("vllm-cpu-amxbf16", "AVX512 + VNNI + BF16 + AMX (Intel Sapphire Rapids and newer)"),
        ]

        for pkg, desc in packages:
            marker = "👉" if pkg == package else "  "
            print(f"  {marker} {pkg:<25} - {desc}")

        print()
        print("=" * 70)


def main():
    """Main entry point."""
    detector = CPUDetector()
    detector.detect()
    detector.print_report()

    # Return exit code based on detection success
    if detector.features or detector.machine in ["aarch64", "arm64"]:
        return 0
    else:
        print("\n⚠️  Warning: Could not detect CPU features reliably")
        print("   Defaulting to base package (vllm-cpu)")
        return 1


if __name__ == "__main__":
    sys.exit(main())
