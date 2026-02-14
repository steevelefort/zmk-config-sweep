#!/usr/bin/env bash

# Build all halves of Cradio (Ferris Sweep) firmware

set -e

echo "Building both Cradio halves..."
echo ""

./build.sh

echo ""
echo "========================================="
echo "All builds complete!"
echo "========================================="
echo ""
ls -lh build/*.uf2
