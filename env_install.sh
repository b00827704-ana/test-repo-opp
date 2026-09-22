#!/usr/bin/env bash
#
# env_install.sh - set up a basic Python development environment.
#
# What it does:
#   1. Detects the operating system (Linux / macOS) using $OSTYPE
#   2. Checks that python3 is installed (installs it if missing)
#   3. Checks that pip is available (installs it if missing)
#   4. Installs Jupyter Notebook
#   5. On macOS, runs `brew doctor` to check Homebrew is healthy
#
# Usage:
#   chmod +x env_install.sh
#   ./env_install.sh

# =============================================
# Functions
# =============================================

# Feature 1: pretty printing.
# Prints a message with a blank line before and after so each step
# stands out in the output. printf is used instead of echo because it
# behaves the same on every system (echo's options differ between shells).
pretty_print() {
  printf "\n==> %s\n\n" "$1"
}

# Prints an error message on stderr and stops the script.
# Used when a step fails and it makes no sense to continue.
fail() {
  printf "\n[ERROR] %s\n\n" "$1" >&2
  exit 1
}

# Returns success (0) if the given command exists on this system.
# `command -v` is the portable way to check this in bash.
command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# Feature 2: operating system detection.
# $OSTYPE is set automatically by bash, e.g. "linux-gnu" or "darwin23".
# We store a simple name in OS so the rest of the script can branch on it.
detect_os() {
  case "$OSTYPE" in
    linux*)  OS="linux" ;;
    darwin*) OS="macos" ;;
    *)       fail "Unsupported operating system: $OSTYPE (use Linux, WSL or macOS)" ;;
  esac
  pretty_print "Detected operating system: $OS ($OSTYPE)"
}

# On macOS everything is installed with Homebrew, so it must exist first.
check_brew() {
  if ! command_exists brew; then
    fail "Homebrew is not installed. Install it from https://brew.sh and run this script again."
  fi
}

# Feature 3: Python install check.
install_python() {
  if command_exists python3; then
    pretty_print "Python is already installed: $(python3 --version)"
    return
  fi

  pretty_print "python3 not found - installing it..."
  if [ "$OS" = "linux" ]; then
    sudo apt update && sudo apt install -y python3 || fail "Python installation failed."
  else
    brew install python || fail "Python installation failed."
  fi

  pretty_print "Python installed: $(python3 --version)"
}

# Feature 4: pip version verification.
# We call pip through `python3 -m pip` so we are sure it is the pip that
# belongs to the python3 we just checked, not another Python on the system.
check_pip() {
  if python3 -m pip --version > /dev/null 2>&1; then
    pretty_print "pip is available: $(python3 -m pip --version)"
    return
  fi

  pretty_print "pip not found - installing it..."
  if [ "$OS" = "linux" ]; then
    # On Ubuntu/Debian, pip comes in a separate package.
    sudo apt install -y python3-pip || fail "pip installation failed."
  else
    # Homebrew's Python ships with pip; reinstalling fixes a missing pip.
    brew reinstall python || fail "pip installation failed."
  fi

  pretty_print "pip installed: $(python3 -m pip --version)"
}

# Feature 5: Jupyter Notebook installation.
# Recent Ubuntu and Homebrew Pythons refuse a plain `pip install` into the
# system Python ("externally-managed-environment"), so we try each OS's own
# package manager first and only fall back to pip if that does not work.
install_jupyter() {
  if command_exists jupyter-notebook || command_exists jupyter; then
    pretty_print "Jupyter is already installed: $(jupyter --version 2>/dev/null | head -n 1)"
    return
  fi

  pretty_print "Installing Jupyter Notebook..."
  if [ "$OS" = "linux" ]; then
    # Plan A: the system package. Plan B: pip into the user's own folder.
    sudo apt install -y jupyter-notebook \
      || python3 -m pip install --user --break-system-packages notebook \
      || fail "Jupyter installation failed."
  else
    brew install jupyterlab || fail "Jupyter installation failed."
  fi

  pretty_print "Jupyter installed. Start it with: jupyter notebook"
}

# Feature 6: macOS-specific health check.
# `brew doctor` reports common Homebrew problems (bad permissions,
# outdated tools...). It only warns, so we don't stop the script on it.
brew_health_check() {
  pretty_print "Running Homebrew health check (brew doctor)..."
  if brew doctor; then
    pretty_print "Homebrew is healthy."
  else
    pretty_print "brew doctor reported warnings - read them above."
  fi
}

# =============================================
# Main logic
# =============================================

main() {
  pretty_print "Starting development environment setup"

  detect_os

  # Refresh the apt package catalogue once, so every install step below
  # can rely on it. Without this, apt says "Unable to locate package".
  if [ "$OS" = "linux" ]; then
    pretty_print "Refreshing the package lists (sudo apt update)..."
    sudo apt update || fail "Could not refresh the package lists. Are you online?"
  fi

  if [ "$OS" = "macos" ]; then
    check_brew
    brew_health_check
  fi

  install_python
  check_pip
  install_jupyter

  pretty_print "All done! Your environment is ready."
}

main "$@"
