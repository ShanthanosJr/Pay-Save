#!/usr/bin/env bash
# Run from the repository root after unzipping. Uses your own git credentials.
set -euo pipefail
git init -b main 2>/dev/null || true
git add .
git commit -m "chore: initial Pay&Save scaffold, master plan and design system" || true
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/ShanthanosJr/Pay-Save.git
git push -u origin main
