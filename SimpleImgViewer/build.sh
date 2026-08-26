// Build script for SimpleImgViewer
#!/bin/bash
set -eo pipefail

echo "Building SimpleImgViewer..."
cd "$(dirname "$0")/.."
swift build

echo "Build complete. Running app..."
# Note: SPM executable needs to be wrapped or run directly
.build/debug/SimpleImgViewer
