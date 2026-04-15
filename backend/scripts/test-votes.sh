#!/bin/bash
# test-votes.sh

# We use a small Node.js script to simulate the Socket.io clients natively because 
# Socket.io's Engine.IO protocol (sending '40', '42', '2', '3') is very difficult 
# to automate safely in plain bash / wscat.
# This script installs socket.io-client if missing, then runs the test.

cd "$(dirname "$0")"

echo "Installing socket.io-client for the test script if not present..."
npm install socket.io-client --no-save > /dev/null 2>&1

node run-votes-simulation.js
