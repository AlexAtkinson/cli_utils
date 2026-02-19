#!/bin/bash

# Define the target installation directory
DEFAULT_INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$HOME/.local/bin" # Common for user-local installs

echo "This script will install the 'fmt-table' utility."
echo "The 'fmt-table' script will be copied to a directory in your PATH."

INSTALL_DIR=""

# Check if .local/bin exists and is in PATH
if [[ -d "$LOCAL_BIN_DIR" && ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
    DEFAULT_INSTALL_DIR="$LOCAL_BIN_DIR"
fi

read -p "Enter the installation directory (default: $DEFAULT_INSTALL_DIR): " USER_INSTALL_DIR

if [[ -z "$USER_INSTALL_DIR" ]]; then
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
else
    INSTALL_DIR="$USER_INSTALL_DIR"
fi

echo "Installing 'fmt-table' to $INSTALL_DIR..."

# Create the directory if it doesn't exist
if ! mkdir -p "$INSTALL_DIR"; then
    echo "Error: Could not create directory $INSTALL_DIR."
    exit 1
fi

# Copy the script
if ! cp fmt-table "$INSTALL_DIR/fmt-table"; then
    echo "Error: Could not copy fmt-table to $INSTALL_DIR/fmt-table."
    exit 1
fi

# Make it executable
if ! chmod +x "$INSTALL_DIR/fmt-table"; then
    echo "Error: Could not make $INSTALL_DIR/fmt-table executable."
    exit 1
fi

echo "'fmt-table' installed successfully!"

# Check if the install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Warning: '$INSTALL_DIR' is not currently in your system's PATH."
    echo "You may need to add it to your shell's configuration file (e.g., ~/.bashrc, ~/.zshrc) like this:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo "After adding, run 'source ~/.bashrc' (or your respective shell config file) to update your PATH."
fi
