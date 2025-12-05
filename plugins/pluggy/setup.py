"""Setup configuration for Pluggy."""

from setuptools import setup, find_packages
from pathlib import Path

# Read the README file
readme_path = Path(__file__).parent / "README.md"
long_description = readme_path.read_text() if readme_path.exists() else ""

setup(
    name="pluggy",
    version="1.3.0",
    packages=find_packages(),
    python_requires=">=3.7",
    author="Anthony Costanzo",
    author_email="mail@acostanzo.com",
    description="Your plugin development assistant - build, test, and maintain Claude Code plugins",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/acostanzo/quickstop",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Code Generators",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    keywords="plugin development scaffolding claude-code marketplace validation",
    license="MIT",
)
