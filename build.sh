#!/usr/bin/env bash

# ZMK Local Build Script with Docker
# Builds firmware for Cradio (Sweep) split keyboard

set -e

BOARD="${1:-nice_nano_v2}"
SHIELDS=("cradio_left" "cradio_right")
BUILD_DIR="build"
WORKSPACE_DIR="zmk-workspace"
DOCKER_IMAGE="zmkfirmware/zmk-build-arm:4.1-branch"

echo "Building ZMK firmware for Cradio (board: $BOARD)"

# Create directories if they don't exist
mkdir -p "$BUILD_DIR"
mkdir -p "$WORKSPACE_DIR"

# Copy config to workspace directory so it's accessible inside Docker
cp -r config "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r boards "$WORKSPACE_DIR/" 2>/dev/null || true
cp -r zephyr "$WORKSPACE_DIR/" 2>/dev/null || true

# Pull latest Docker image
echo "Pulling Docker image..."
docker pull "$DOCKER_IMAGE"

for SHIELD in "${SHIELDS[@]}"; do
  echo ""
  echo "========================================="
  echo "Building $SHIELD..."
  echo "========================================="

  docker run --rm -it \
    -v "$(pwd)/$WORKSPACE_DIR:/workspace" \
    -v "$(pwd)/$BUILD_DIR:/workspace/artifacts" \
    "$DOCKER_IMAGE" \
    sh -c "
      set -e
      cd /workspace

      # Trust all directories to avoid git 'dubious ownership' errors in Docker
      git config --global --add safe.directory '*'

      # Initialize west workspace if needed
      if [ ! -d .west ] || [ ! -d zephyr/zephyr ]; then
        echo 'Initializing west workspace...'
        rm -rf .west
        west init -l config
        echo 'Updating dependencies (this may take a while on first run)...'
        west update
      fi

      # Always run zephyr-export to ensure CMake can find Zephyr
      echo 'Exporting Zephyr CMake package...'
      west zephyr-export

      # Clean previous build
      rm -rf build

      # Build firmware
      west build -s zmk/app -b $BOARD -- \
        -DZMK_CONFIG=/workspace/config \
        -DSHIELD=$SHIELD

      # Copy artifacts to build directory
      if [ -f build/zephyr/zmk.uf2 ]; then
        cp build/zephyr/zmk.uf2 /workspace/artifacts/${BOARD}_${SHIELD}.uf2
        echo ''
        echo 'Build successful for $SHIELD!'
      else
        echo 'Build failed for $SHIELD: UF2 file not found'
        exit 1
      fi
    "
done

echo ""
echo "========================================="
echo "Build complete!"
echo "Firmware files:"
for SHIELD in "${SHIELDS[@]}"; do
  echo "  $BUILD_DIR/${BOARD}_${SHIELD}.uf2"
done
echo "========================================="
echo ""
echo "To flash:"
echo "1. Put each half in bootloader mode (double-press reset)"
echo "2. Copy the matching UF2 file to the mounted drive"
echo "   - Left half:  ${BUILD_DIR}/${BOARD}_cradio_left.uf2"
echo "   - Right half: ${BUILD_DIR}/${BOARD}_cradio_right.uf2"
