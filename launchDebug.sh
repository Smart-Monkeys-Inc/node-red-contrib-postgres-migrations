#!/bin/bash

# This script automates the setup of the Node-RED development environment.
# It starts the Docker containers, installs the custom node's dependencies, and tails the logs.
# Press Ctrl+C to stop the containers and clean up.

# --- Configuration ---
CONTAINER_NAME="nodered-migrations-dev"
# The path where we mount YOUR custom node's source code inside the container
LOCAL_NODE_CONTAINER_PATH="/usr/src/app"
# The directory where Node-RED expects its modules to be found
NODERED_MODULES_PATH="/data/node_modules"

# --- Cleanup function to run on exit ---
cleanup() {
    echo ""
    echo "Stopping Docker containers..."
    docker-compose down
    echo "Cleanup complete."
}

# Trap SIGINT (Ctrl+C) and TERM signals to run the cleanup function
trap cleanup INT TERM

# --- Main script logic ---

# 1. Start Docker containers in detached (background) mode
echo "Starting Docker containers..."
docker-compose up -d

# 2. Wait for the Node-RED server to be ready inside the container
echo "Waiting for Node-RED server ($CONTAINER_NAME) to be ready..."
until docker exec $CONTAINER_NAME curl -s http://localhost:1880 > /dev/null; do
    printf '.'
    sleep 1
done
echo "" # Newline after dots
echo "Node-RED server is ready."

# 3. Create the node_modules directory if it doesn't exist
# This is crucial as /data/node_modules might not be there on fresh run
echo "Ensuring Node-RED modules directory ($NODERED_MODULES_PATH) exists..."
docker exec $CONTAINER_NAME mkdir -p $NODERED_MODULES_PATH

# 4. Install dependencies for your custom node at its mounted location
echo "Installing dependencies for your custom node in $LOCAL_NODE_CONTAINER_PATH..."
if ! docker exec $CONTAINER_NAME sh -c "cd $LOCAL_NODE_CONTAINER_PATH && npm install"; then
    echo "ERROR: Failed to install node dependencies inside the container."
    cleanup
    exit 1
fi
echo "Dependencies installed successfully at $LOCAL_NODE_CONTAINER_PATH/node_modules."

# 5. Create a symbolic link from your node's source to Node-RED's expected module path
# This makes Node-RED find your node and its local node_modules
echo "Creating symbolic link for your custom node..."
# Get the base name of your node's directory (e.g., node-red-contrib-postgres-migrations)
NODE_DIR_NAME=$(basename "$PWD") # This assumes dev.sh is run from your node's root directory

# Command to create the symlink inside the container
if ! docker exec $CONTAINER_NAME ln -sfn "$LOCAL_NODE_CONTAINER_PATH" "$NODERED_MODULES_PATH/$NODE_DIR_NAME"; then
    echo "ERROR: Failed to create symbolic link for the custom node."
    cleanup
    exit 1
fi
echo "Symbolic link created: $NODERED_MODULES_PATH/$NODE_DIR_NAME -> $LOCAL_NODE_CONTAINER_PATH"

# 6. Stop and restart Node-RED to pick up the new node/symlink.
#    Node-RED only scans for nodes at startup.
echo "Restarting Node-RED to load the custom node..."
docker exec $CONTAINER_NAME pkill -f "node-red" # Kill the existing process
# This will cause Node-RED to restart via its init system, or manually launch if that's preferred.
# For simplicity and reliability in Docker, restarting the container is often easier:
docker-compose restart nodered
# Wait for it to be ready again
until docker exec $CONTAINER_NAME curl -s http://localhost:1880 > /dev/null; do
    printf '.'
    sleep 1
done
echo "" # Newline after dots
echo "Node-RED restarted."


# 7. Tail the logs to see the output. The script will wait here.
echo "Setup complete. Tailing logs. Press Ctrl+C to stop and clean up."
docker-compose logs -f