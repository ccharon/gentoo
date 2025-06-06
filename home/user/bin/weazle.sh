#!/bin/env bash

# Launches an interactive shell in the Greaseweazle image directory,
# activates the Python virtual environment, and runs `gw reset` and `gw info`.
# Useful for quickly entering a ready-to-use Greaseweazle working environment.

cd /disketten/greaseweazle/images || exit 1
bash --init-file <(echo "source $HOME/greaseweazle/venv/bin/activate ; gw reset ; gw info")

