#!/usr/bin/env bash

# Build and deploy Jolt DevTools Extension
# This script builds the extension and copies it to the jolt package

set -e

echo "Building Jolt DevTools Extension..."
cd "$(dirname "$0")"

flutter create . --platforms web

# Build the extension
flutter build web --pwa-strategy=none --no-tree-shake-icons

# Copy to jolt package
echo "Copying build files to jolt package..."
dart run devtools_extensions build_and_copy --source=. --dest=../jolt/extension/devtools

# Validate
echo "Validating extension..."
dart run devtools_extensions validate --package=../jolt

echo "✅ Extension built and deployed successfully!"

