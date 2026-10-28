#!/bin/bash
# Copyright © 2026 Robert Hedin
# All Rights Reserved.
#
# Runs the code in each sample folder that run.sh wrote, in every language whose
# tools are installed, and compares what it prints with the sample's expected.txt.
#
# Usage: scripts/code-samples/check.sh [samples folder] [language ...]
set -u
samples=$(cd "${1:-build/code-samples}" && pwd) || exit 1
shift || true
languages=${*:-"swift6 swift5 csharp cpp go java javascript typescript kotlin kotlin-jvm perl php python r ruby rust"}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }

# Prints the output of running one language's code, or fails if it won't build or run.
run() {
    local language=$1 dir=$2
    case $language in
        swift6) swiftc -swift-version 6 -o "$work/swift6" "$dir/swift6.swift" 2>"$work/err" && "$work/swift6" ;;
        swift5) swiftc -swift-version 5 -o "$work/swift5" "$dir/swift5.swift" 2>"$work/err" && "$work/swift5" ;;
        csharp)
            [ -d "$work/cs" ] || dotnet new console -o "$work/cs" >/dev/null 2>&1
            cp "$dir/csharp.cs" "$work/cs/Program.cs" && dotnet run --project "$work/cs" 2>"$work/err" ;;
        cpp) g++ -std=c++17 -o "$work/cpp" "$dir/cpp.cpp" 2>"$work/err" && "$work/cpp" ;;
        go) go run "$dir/go.go" 2>"$work/err" ;;
        java) java -Dstdout.encoding=UTF-8 "$dir/Main.java" 2>"$work/err" ;;
        javascript) node "$dir/javascript.js" 2>"$work/err" ;;
        typescript)
            cp "$dir/javascript.js" "$work/check.ts" &&
                tsc --noEmit --strict --target es2022 --lib es2022,dom "$work/check.ts" >"$work/err" 2>&1 &&
                node "$dir/javascript.js" ;;
        kotlin) kotlinc-native "$dir/kotlin.kt" -o "$work/kotlin" >/dev/null 2>"$work/err" && "$work/kotlin.kexe" ;;
        # The same code on the JVM, whose regex engine differs from Kotlin/Native's.
        kotlin-jvm)
            kotlinc "$dir/kotlin.kt" -include-runtime -d "$work/kotlin.jar" 2>"$work/err" &&
                java -Dstdout.encoding=UTF-8 -jar "$work/kotlin.jar" ;;
        perl) perl "$dir/perl.pl" 2>"$work/err" ;;
        php) php "$dir/php.php" 2>"$work/err" ;;
        python) python3 "$dir/python.py" 2>"$work/err" ;;
        r) Rscript "$dir/r.R" 2>"$work/err" ;;
        ruby) ruby "$dir/ruby.rb" 2>"$work/err" ;;
        rust)
            if [ ! -d "$work/rs" ]; then
                cargo new --quiet "$work/rs" && (cd "$work/rs" && cargo add --quiet regex@1) || return 1
            fi
            cp "$dir/rust.rs" "$work/rs/src/main.rs" && cargo run --quiet --manifest-path "$work/rs/Cargo.toml" 2>"$work/err" ;;
    esac
}

tool_for() {
    case $1 in
        swift6 | swift5) echo swiftc ;; csharp) echo dotnet ;; cpp) echo g++ ;; go) echo go ;;
        java) echo java ;; javascript) echo node ;; typescript) echo tsc ;; kotlin) echo kotlinc-native ;; kotlin-jvm) echo kotlinc ;;
        perl) echo perl ;; php) echo php ;; python) echo python3 ;; r) echo Rscript ;;
        ruby) echo ruby ;; rust) echo cargo ;;
    esac
}

failures=0
for language in $languages; do
    if ! have "$(tool_for "$language")"; then
        echo "SKIP  $language (no $(tool_for "$language"))"
        continue
    fi
    for dir in "$samples"/*/; do
        sample=$(basename "$dir")
        : >"$work/err"
        if run "$language" "$dir" >"$work/out"; then
            if cmp -s "$work/out" "$dir/expected.txt"; then
                echo "PASS  $language  $sample"
            else
                echo "DIFF  $language  $sample"
                diff "$dir/expected.txt" "$work/out" | sed 's/^/      /' | head -20
                failures=$((failures + 1))
            fi
        else
            echo "FAIL  $language  $sample"
            sed 's/^/      /' "$work/err" | head -10
            failures=$((failures + 1))
        fi
    done
done
echo "$failures failed"
