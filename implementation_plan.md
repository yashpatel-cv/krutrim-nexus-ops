# Krutrim Nexus Ops - HA & Monitoring Plan

## Goal Description
Enhance the platform to support:
1.  **Web Dashboard**: Visual analytics for all nodes.
2.  **Decentralization (HA)**: Services survive single-node failures.
3.  **Interactive Setup**: `install.sh` asks the user for their intent.

## Architecture Updates

### 1. Monitoring & Dashboard
*   **Tool**: **Netdata**. It's lightweight, real-time, and decentralized.
*   **Implementation**:
    *   `setup-monitoring.sh`: Installs Netdata on a node.
    *   **Unified View**: The Manager will host a simple "Nexus Dashboard" (static HTML) that embeds the Netdata charts of all workers, OR we configure Netdata to stream to the Manager.
    *   *Decision*: Streaming to Manager is cleaner. Manager runs a Netdata parent; Workers run Netdata children.

### 2. High Availability (Decentralization)
*   **Load Balancing**: The `setup-lb.sh` (Caddy) already supports multiple backends. We will explicitly document/script how to add multiple worker IPs for redundancy.
*   **Service Redundancy**: `nexus deploy` will be updated to easily deploy the same service to multiple nodes.
*   **Manager Resilience**: The Manager is already decoupled. If it goes down, workers keep running.

### 3. Interactive Installer
*   **`install.sh`**:
    *   Check if running interactively.
    *   Ask: "Install Nexus Manager? (y/n)"
    *   If yes, proceed with Manager setup.
    *   If no, ask: "Is this a Worker node? (y/n)" -> If yes, print instructions on how to bootstrap it from the Manager (sticking to the Push model as it's more robust, but acknowledging the user's mental model).

## Proposed Changes

### [MODIFY] `install.sh`
*   Add `read -p` prompts for role selection.

### [NEW] `setup-monitoring.sh`
*   Installs Netdata.
*   Configures streaming (Child -> Parent) if it's a worker.

### [MODIFY] `nexus.py`
*   Add `deploy monitoring` command.
*   Add `dashboard` command to generate/open the dashboard URL.

### [MODIFY] `README.md`
*   Add "High Availability" section.
*   Add "Monitoring" section.
