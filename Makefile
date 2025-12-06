.PHONY: help install dashboard test clean docs

help:
	@echo "Krutrim Nexus Ops - Makefile Commands"
	@echo ""
	@echo "  make install      - Run main installer"
	@echo "  make dashboard    - Install and start dashboard"
	@echo "  make test         - Run all tests"
	@echo "  make clean        - Clean temporary files"
	@echo "  make docs         - Generate documentation"
	@echo "  make status       - Show all service statuses"
	@echo "  make logs         - Tail all service logs"
	@echo ""

install:
	@echo "Running installer..."
	sudo ./install.sh

dashboard:
	@echo "Installing dashboard..."
	cd dashboard/backend && python3 -m venv venv
	cd dashboard/backend && venv/bin/pip install -r requirements.txt
	sudo cp config/systemd/nexus-dashboard.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable nexus-dashboard
	sudo systemctl start nexus-dashboard
	@echo "Dashboard installed! Access at http://localhost:9000"

test:
	@echo "Running tests..."
	cd tests && python3 -m pytest -v

clean:
	@echo "Cleaning temporary files..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.log" -delete

docs:
	@echo "Documentation available in docs/ folder"
	@ls -1 docs/

status:
	@echo "=== Service Status ==="
	@systemctl status consul --no-pager || true
	@systemctl status nexus-orchestrator --no-pager || true
	@systemctl status nexus-worker --no-pager || true
	@systemctl status nexus-dashboard --no-pager || true

logs:
	@echo "Tailing all service logs (Ctrl+C to stop)..."
	sudo journalctl -u nexus-dashboard -u nexus-orchestrator -u nexus-worker -u consul -f
