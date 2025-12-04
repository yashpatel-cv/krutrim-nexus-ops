#!/usr/bin/env python3
"""
nexus.py - Krutrim Nexus Ops Manager
"""

import argparse
import yaml
import os
import subprocess
import sys

NEXUS_HOME = "/opt/nexus"
INVENTORY = f"{NEXUS_HOME}/inventory.yml"

def load_inventory():
    if not os.path.exists(INVENTORY):
        print(f"Error: {INVENTORY} not found.")
        sys.exit(1)
    with open(INVENTORY, 'r') as f:
        return yaml.safe_load(f)

def run_remote(host, cmd):
    print(f"[{host}] EXEC: {cmd}")
    subprocess.run(["ssh", "-o", "StrictHostKeyChecking=no", f"root@{host}", cmd], check=True)

def push_file(host, src, dest):
    print(f"[{host}] PUSH: {src} -> {dest}")
    subprocess.run(["scp", "-o", "StrictHostKeyChecking=no", src, f"root@{host}:{dest}"], check=True)

def bootstrap(args):
    """Bootstraps all workers."""
    data = load_inventory()
    workers = data.get('workers', [])
    for worker in workers:
        print(f"\n--- Bootstrapping {worker} ---")
        try:
            push_file(worker, f"{NEXUS_HOME}/bootstrap_worker.sh", "/tmp/bootstrap_worker.sh")
            push_file(worker, f"{NEXUS_HOME}/nftables.conf", "/tmp/nftables.conf")
            push_file(worker, f"{NEXUS_HOME}/99-hardening.conf", "/tmp/99-hardening.conf")
            
            run_remote(worker, "mkdir -p /opt/nexus")
            push_file(worker, f"{NEXUS_HOME}/run-services.sh", "/opt/nexus/run-services.sh")
            push_file(worker, f"{NEXUS_HOME}/services.py", "/opt/nexus/services.py")
            push_file(worker, f"{NEXUS_HOME}/proc_ipc.py", "/opt/nexus/proc_ipc.py")
            
            run_remote(worker, "chmod +x /tmp/bootstrap_worker.sh && /tmp/bootstrap_worker.sh")
        except Exception as e:
            print(f"Error: {e}")

def deploy(args):
    """Deploys a service."""
    target = args.target
    service = args.service
    script = f"setup-{service}.sh"
    src_path = f"{NEXUS_HOME}/{script}"
    
    if not os.path.exists(src_path):
        print(f"Script {script} not found.")
        return

    print(f"Deploying {service} to {target}...")
    try:
        push_file(target, src_path, f"/tmp/{script}")
        cmd_args = " ".join(args.args)
        run_remote(target, f"chmod +x /tmp/{script} && /tmp/{script} {cmd_args}")
    except Exception as e:
        print(f"Error: {e}")

def create_user(args):
    target = args.target
    username = args.username
    try:
        run_remote(target, f"useradd -m -s /usr/sbin/nologin {username}")
        print(f"Set password for {username}:")
        run_remote(target, f"passwd {username}")
        if args.type == 'storage':
            run_remote(target, f"mkdir -p /home/{username}/public && chown {username}:{username} /home/{username}/public && chmod 755 /home/{username}")
    except Exception as e:
        print(f"Error: {e}")

def sync(args):
    data = load_inventory()
    for worker in data.get('workers', []):
        try:
            push_file(worker, f"{NEXUS_HOME}/services.yml", "/opt/nexus/services.yml")
            run_remote(worker, "systemctl restart nexus-agent")
        except:
            print(f"Failed to sync {worker}")

def monitor(args):
    """Sets up monitoring on Manager and all Workers."""
    print(">>> Setting up Manager Monitoring (Parent)...")
    subprocess.run([f"{NEXUS_HOME}/setup-monitoring.sh"], check=False)
    
    manager_ip = subprocess.getoutput("hostname -I | awk '{print $1}'")
    print(f"Manager IP detected as: {manager_ip}")
    
    data = load_inventory()
    workers = data.get('workers', [])
    for worker in workers:
        print(f">>> Setting up Worker {worker} (Child)...")
        try:
            push_file(worker, f"{NEXUS_HOME}/setup-monitoring.sh", "/tmp/setup-monitoring.sh")
            run_remote(worker, f"chmod +x /tmp/setup-monitoring.sh && /tmp/setup-monitoring.sh {manager_ip}")
        except Exception as e:
            print(f"Error on {worker}: {e}")
            
    print(f"\n>>> Dashboard available at: http://{manager_ip}:19999")

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    subparsers.add_parser('bootstrap').set_defaults(func=bootstrap)
    
    p_deploy = subparsers.add_parser('deploy')
    p_deploy.add_argument('service')
    p_deploy.add_argument('target')
    p_deploy.add_argument('args', nargs='*')
    p_deploy.set_defaults(func=deploy)
    
    p_user = subparsers.add_parser('create-user')
    p_user.add_argument('type')
    p_user.add_argument('target')
    p_user.add_argument('username')
    p_user.set_defaults(func=create_user)
    
    subparsers.add_parser('sync').set_defaults(func=sync)
    
    # New Monitor Command
    subparsers.add_parser('monitor').set_defaults(func=monitor)

    args = parser.parse_args()
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
