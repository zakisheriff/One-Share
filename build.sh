#!/bin/bash

# Navigate to the project directory
cd /Users/afraasheriff/Desktop/Projects_List/Lumen

# Compile all Swift files
swiftc -sdk $(xcrun --sdk macosx --show-sdk-path) \
  -import-objc-header Lumen/Lumen-Bridging-Header.h \
  -I /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ \
  -F /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ \
  -framework Foundation \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  Lumen/*.swift \
  -o Lumen.app

echo "Build completed!"