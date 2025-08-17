#!/bin/bash

# Build script for lambda_build_worker

echo "Installing dependencies..."
npm install

echo "Creating deployment package..."
zip -r ../lambda_build_worker.zip . -x "*.git*" "*.md" "build.sh"

echo "Build complete! Package created at: ../lambda_build_worker.zip"
