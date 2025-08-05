#!/bin/bash

set -euo pipefail

readonly VERSION_STRING=$(./tools/get-version)
readonly TEMPORARY_FOLDER="/tmp/SwiftLint.dst"
readonly ARTIFACT_BUNDLE_PATH="$TEMPORARY_FOLDER/SwiftLintBinary.artifactbundle"
readonly LICENSE_PATH="$(pwd)/LICENSE"

echo "Building SwiftLint for macOS..."
make clean
make .build/universal/swiftlint

echo "Creating artifact bundle structure..."
mkdir -p "$ARTIFACT_BUNDLE_PATH/swiftlint-$VERSION_STRING-macos/bin"

echo "Copying files to artifact bundle..."
sed 's/__VERSION__/'"$VERSION_STRING"'/g' tools/info.json.template > "$ARTIFACT_BUNDLE_PATH/info.json"
cp -f ".build/universal/swiftlint" "$ARTIFACT_BUNDLE_PATH/swiftlint-$VERSION_STRING-macos/bin/swiftlint"
cp -f "$LICENSE_PATH" "$ARTIFACT_BUNDLE_PATH"

echo "Creating artifact bundle zip..."
(cd "$TEMPORARY_FOLDER"; zip -yr - "SwiftLintBinary.artifactbundle") > "./SwiftLintBinary.artifactbundle.zip"

echo "Calculating checksum..."
readonly checksum=$(shasum -a 256 "SwiftLintBinary.artifactbundle.zip" | cut -d " " -f1 | xargs)

echo "Artifact bundle created: SwiftLintBinary.artifactbundle.zip"
echo "Checksum: $checksum"
echo "Version: $VERSION_STRING" 