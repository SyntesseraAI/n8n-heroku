#!/bin/bash
set -e

# Execute Claude Code using the Node.js wrapper with node-pty
exec node /app/run-claude.js
