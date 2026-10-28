#!/bin/sh
# Copyright © 2026 Robert Hedin
#
# Builds main.swift with the app's model and code generators, and writes the code each
# language generates for the samples into build/code-samples (or the folder you give).
set -eu
cd "$(dirname "$0")/../.."
app=src/RegexExplorer
mkdir -p build
swiftc -O -o build/code-samples-tool \
    "$app"/Model/SavedRegex.swift "$app"/Model/RegexOptions.swift \
    "$app"/Matching/*.swift scripts/code-samples/main.swift
build/code-samples-tool "${1:-build/code-samples}"
