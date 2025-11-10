#!/bin/bash

echo "Starting all dotfiles installation scripts..."

find . -maxdepth 1 -name 'install_*.sh' -exec sh -c '{}' \;

echo "All installation scripts finished."
