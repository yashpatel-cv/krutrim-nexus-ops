#!/usr/bin/env python3
"""
services.py - Tier 2 Service Orchestrator
Reads services.yml and manages application services using proc_ipc.
"""

import yaml
import time
import signal
import sys
import os
from .process import Process, logger

# Global registry
SERVICES: list[Process] = []

def load_config(path: str = "services.yml"):
    if not os.path.exists(path):
        logger.warning(f"Config {path} not found.")
        return {}
    with open(path, "r") as f:
        return yaml.safe_load(f)

def signal_handler(sig, frame):
    logger.info("Received shutdown signal. Stopping services...")
    for svc in SERVICES:
        svc.stop()
    sys.exit(0)

def main():
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    config = load_config()
    apps = config.get("services", {})

    for name, cmd_list in apps.items():
        if not cmd_list: continue
        # cmd_list is expected to be a list of strings, e.g. ["python3", "-m", "http.server"]
        svc = Process(cmd_list, name=name)
        svc.start()
        SERVICES.append(svc)

    logger.info("Orchestrator running. Press Ctrl+C to stop.")

    # Supervision Loop
    while True:
        for svc in SERVICES:
            if not svc.is_running():
                logger.warning(f"Service {svc.name} died. Restarting...")
                svc.start()
            
            # Drain logs
            out, err = svc.read_output()
            if out:
                for line in out.splitlines():
                    logger.info(f"[{svc.name}] {line.decode(errors='replace')}")
            if err:
                for line in err.splitlines():
                    logger.error(f"[{svc.name}] {line.decode(errors='replace')}")

        time.sleep(1)

if __name__ == "__main__":
    main()
