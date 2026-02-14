#!/bin/bash

set -e

BUILD_DIR="build/x86_64-linux-gnu/lib"
LIB_DIR="/usr/local/lib"
PROJECT_DIR="/home/sebas/flite/flite"

# Array of libraries to manage
LIBRARIES=(
  "libflite.so.1"
  "libflite_cmu_grapheme_lang.so.1"
  "libflite_cmu_grapheme_lex.so.1"
  "libflite_cmu_indic_lang.so.1"
  "libflite_cmu_indic_lex.so.1"
  "libflite_cmu_time_awb.so.1"
  "libflite_cmu_us_awb.so.1"
  "libflite_cmu_us_kal.so.1"
  "libflite_cmu_us_kal16.so.1"
  "libflite_cmu_us_rms.so.1"
  "libflite_cmu_us_slt.so.1"
  "libflite_cmulex.so.1"
  "libflite_usenglish.so.1"
)

up() {
  echo "Starting flite installation..."
  
  cd "$PROJECT_DIR"
  
  if [ ! -f "Makefile" ]; then
    echo "Running ./configure --enable-shared..."
    ./configure --enable-shared
  fi
  
  echo "Building flite..."
  make
  
  if command -v wget &> /dev/null; then
    echo "Downloading voices..."
    make get_voices
  else
    echo "wget not found, skipping voice download"
  fi
  
  echo "Installing libraries to $LIB_DIR..."
  sudo mkdir -p "$LIB_DIR"
  
  for lib in "${LIBRARIES[@]}"; do
    src="$BUILD_DIR/$lib"
    if [ -L "$src" ]; then
      echo "  Copying $lib..."
      sudo cp -P "$src" "$LIB_DIR/"
    fi
  done
  
  sudo ldconfig
  
  echo "Installation complete!"
}

down() {
  echo "Removing flite installation..."
  
  cd "$PROJECT_DIR"
  
  echo "Removing libraries from $LIB_DIR..."
  for lib in "${LIBRARIES[@]}"; do
    if [ -e "$LIB_DIR/$lib" ]; then
      echo "  Removing $lib..."
      sudo rm -f "$LIB_DIR/$lib"
    fi
  done
  
  sudo ldconfig
  
  echo "Cleaning build artifacts..."
  make clean 2>/dev/null || true
  
  echo "Removal complete!"
}

main() {
  case "${1:-}" in
    --down|-d)
      down
      ;;
    --up|-u)
      up
      ;;
    *)
      up
      ;;
  esac
}

main "$@"
