#!/bin/bash

# Lumen Build Script
# This script builds the Lumen application with proper linking for iOS support

echo "Building Lumen with iOS support..."

# Check if dependencies are installed
echo "Checking for required dependencies..."

if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

# Install required dependencies if not present
echo "Installing dependencies..."
brew install libmtp libimobiledevice

# Create build directory if it doesn't exist
mkdir -p build

# Build the project using xcodebuild
echo "Building project..."
xcodebuild -project Lumen.xcodeproj -scheme Lumen -configuration Release -derivedDataPath build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Application built in build/Build/Products/Release/"
else
    echo "Build failed!"
    exit 1
fi