#!/bin/bash

set -e

# Clean up files
echo "🧹 Cleaning files..."
rm -f *.zip
find . -name ".DS_Store" -delete

# Zip frameworks
echo "📦 Creating VLCKit.xcframework.zip..."
zip -q -r -y VLCKit.xcframework.zip VLCKit.xcframework -x "*.DS_Store" -x "__MACOSX"

echo "📦 Creating MobileVLCKit.xcframework.zip..."
zip -q -r -y MobileVLCKit.xcframework.zip MobileVLCKit.xcframework -x "*.DS_Store" -x "__MACOSX"

echo "📦 Creating TVVLCKit.xcframework.zip..."
zip -q -r -y TVVLCKit.xcframework.zip TVVLCKit.xcframework -x "*.DS_Store" -x "__MACOSX"

# Generate checksums
echo ""
echo "✅ Checksums:"
echo "   VLCKit: $(swift package compute-checksum VLCKit.xcframework.zip)"
echo "   MobileVLCKit: $(swift package compute-checksum MobileVLCKit.xcframework.zip)"
echo "   TVVLCKit: $(swift package compute-checksum TVVLCKit.xcframework.zip)"

