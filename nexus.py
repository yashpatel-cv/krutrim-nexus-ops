#!/usr/bin/env python3
"""
nexus.py - Minimalist Cluster Manager
Just loops over SSH. No heavy libs.
"""

import argparse
import yaml
import os
import subprocess
import sys

INVENTORY = "/opt/nexus/inventory.yml"

def load_inventory():
    if not os.path.exists(INVENTORY):
        print(f"Error: {INVENTORY} not found.")
        sys.exit(1)
    with open(INVENTORY, 'r') as f:
        return yaml.safe_load(f)

def run_remote(host, cmd):
    print(f"[{host}] {cmd}")
    subprocess.run(["ssh", "-o", "StrictHostKeyChecking=no", f"root@{host}", cmd])

def sync(args):
    data = load_inventory()
    for worker in data.get('workers', []):
        print(f"Syncing to {worker}...")
        # Sync configs
        subprocess.run(["rsync", "-avz", "/opt/nexus/services.yml", f"root@{worker}:/opt/nexus/"])
        # Reload agent
        run_remote(worker, "systemctl restart nexus-agent")

def cmd(args):
    data = load_inventory()
    for worker in data.get('workers', []):
        run_remote(worker, args.command)

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    p_sync = subparsers.add_parser('sync')
    p_sync.set_defaults(func=sync)

    p_cmd = subparsers.add_parser('exec')
    p_cmd.add_argument('command')
    p_cmd.set_defaults(func=cmd)

    args = parser.parse_args()
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
