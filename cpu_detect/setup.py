#!/usr/bin/env python3
"""Setup script for vllm-cpu-detect."""

from setuptools import setup

setup(
    name="vllm-cpu-detect",
    version="0.1.0",
    description="CPU detection tool for vLLM CPU builds",
    long_description=open("README.md").read() if __name__ == "__main__" else "",
    long_description_content_type="text/markdown",
    author="vLLM Team",
    url="https://github.com/vllm-project/vllm",
    py_modules=["vllm_cpu_detect"],
    entry_points={
        "console_scripts": [
            "vllm-cpu-detect=vllm_cpu_detect:main",
        ],
    },
    python_requires=">=3.8",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
    ],
)
