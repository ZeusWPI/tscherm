#!/usr/bin/env bash

set -e

componentName=$(basename "${PWD}")

# Config
DFLAGS+=" --linkonce-templates"
DFLAGS+=" --preview=in"
DFLAGS+=" --preview=bitfields"
DFLAGS+=" --preview=fixImmutableConv"
#DFLAGS+=" --gc"
DFLAGS+=" --release --O3 --boundscheck=off"

# Append default flags based on target
DFLAGS+=" $(cd "$(dirname "${BASH_SOURCE[0]}")" && dflags.py)"
export DFLAGS

# Build static libraries the project and each dependency
dub build --build=plain --deep --color=always

# Get built static library locations
artifacts=$(dub describe --build=plain | jq -r '.targets[].cacheArtifactPath')

# Combine artifacts
rm "lib${componentName}.a"
ar -rcT "lib${componentName}.a" $artifacts
