#!/usr/bin/env python3
"""
proc_ipc.py - POSIX Process Management & IPC Module
Demonstrates: fork, exec, pipe, signals, non-blocking I/O, process groups.
"""

import os
import sys
import time
import signal
import fcntl
import errno
import logging
import select
from typing import List, Optional, Tuple, Dict, Callable

# Configure logging
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] [PROC] %(message)s')
logger = logging.getLogger(__name__)

class Process:
    def __init__(self, command: List[str], name: str = "worker"):
        self.command = command
        self.name = name
        self.pid: Optional[int] = None
        self.stdin_fd: Optional[int] = None  # Parent writes to this
        self.stdout_fd: Optional[int] = None # Parent reads from this
        self.stderr_fd: Optional[int] = None # Parent reads from this
        self.start_time: float = 0.0

    def start(self):
        """Starts the process using fork/exec and sets up pipes."""
        # Create pipes: (read_end, write_end)
        p_stdin_r, p_stdin_w = os.pipe()
        p_stdout_r, p_stdout_w = os.pipe()
        p_stderr_r, p_stderr_w = os.pipe()

        self.start_time = time.time()
        pid = os.fork()

        if pid == 0:
            # CHILD PROCESS
            try:
                # Close parent's ends
                os.close(p_stdin_w)
                os.close(p_stdout_r)
                os.close(p_stderr_r)

                # Dup2 to standard FDs
                os.dup2(p_stdin_r, sys.stdin.fileno())
                os.dup2(p_stdout_w, sys.stdout.fileno())
                os.dup2(p_stderr_w, sys.stderr.fileno())

                # Close original FDs after dup2
                os.close(p_stdin_r)
                os.close(p_stdout_w)
                os.close(p_stderr_w)

                # Create new process group
                os.setpgid(0, 0)

                # Execute
                os.execvp(self.command[0], self.command)
            except Exception as e:
                sys.stderr.write(f"Exec failed: {e}\n")
                sys.exit(1)
        else:
            # PARENT PROCESS
            self.pid = pid
            logger.info(f"Started {self.name} (PID: {self.pid})")

            # Close child's ends
            os.close(p_stdin_r)
            os.close(p_stdout_w)
            os.close(p_stderr_w)

            self.stdin_fd = p_stdin_w
            self.stdout_fd = p_stdout_r
            self.stderr_fd = p_stderr_r

            # Set non-blocking read
            self._set_nonblocking(self.stdout_fd)
            self._set_nonblocking(self.stderr_fd)

    def _set_nonblocking(self, fd: int):
        flags = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

    def read_output(self) -> Tuple[bytes, bytes]:
        """Reads available data from stdout/stderr without blocking."""
        out_data = b""
        err_data = b""

        # Check if FDs are ready
        rlist, _, _ = select.select([self.stdout_fd, self.stderr_fd], [], [], 0)

        if self.stdout_fd in rlist:
            try:
                chunk = os.read(self.stdout_fd, 4096)
                if chunk: out_data = chunk
            except OSError as e:
                if e.errno != errno.EAGAIN: raise

        if self.stderr_fd in rlist:
            try:
                chunk = os.read(self.stderr_fd, 4096)
                if chunk: err_data = chunk
            except OSError as e:
                if e.errno != errno.EAGAIN: raise

        return out_data, err_data

    def stop(self, timeout: int = 5):
        """Sends SIGTERM, waits, then SIGKILL if needed."""
        if self.pid is None: return

        logger.info(f"Stopping {self.name} (PID: {self.pid})...")
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            self.pid = None
            return

        # Wait loop
        start = time.time()
        while time.time() - start < timeout:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid != 0:
                logger.info(f"{self.name} exited with status {status}")
                self.pid = None
                return
            time.sleep(0.1)

        # Force kill
        logger.warning(f"{self.name} did not exit. Sending SIGKILL.")
        try:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        except OSError:
            pass
        self.pid = None

    def is_running(self) -> bool:
        if self.pid is None: return False
        pid, status = os.waitpid(self.pid, os.WNOHANG)
        if pid == 0:
            return True
        self.pid = None
        return False

def demo():
    """Demonstration of the Process class."""
    p = Process(["ping", "-c", "5", "127.0.0.1"], name="ping_demo")
    p.start()
    
    while p.is_running():
        out, err = p.read_output()
        if out: print(f"[STDOUT] {out.decode().strip()}")
        if err: print(f"[STDERR] {err.decode().strip()}")
        time.sleep(0.5)

if __name__ == "__main__":
    demo()
