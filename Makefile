.PHONY: help install dashboard test clean docs setup-n8n setup-youtube n8n-logs n8n-status n8n-restart n8n-stop

help:
	@echo "Krutrim Nexus Ops - Makefile Commands"
	@echo ""
	@echo "  Core:"
	@echo "    make install        - Run main installer"
	@echo "    make dashboard      - Install and start dashboard"
	@echo "    make status         - Show all service statuses"
	@echo "    make logs           - Tail all service logs"
	@echo ""
	@echo "  YouTube Shorts Automation:"
	@echo "    make setup-n8n      - Install n8n automation platform"
	@echo "    make setup-youtube  - Setup YouTube Shorts workflow"
	@echo "    make n8n-status     - Check n8n container status"
	@echo "    make n8n-logs       - Tail n8n container logs"
	@echo ""
	@echo "  Development:"
	@echo "    make test           - Run all tests"
	@echo "    make clean          - Clean temporary files"
	@echo "    make docs           - Generate documentation"
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

# ==========================================
# YouTube Shorts Automation
# ==========================================

setup-n8n:
	@echo "Setting up n8n automation platform..."
	@chmod +x scripts/setup-n8n.sh
	./scripts/setup-n8n.sh

setup-youtube:
	@echo "Setting up YouTube Shorts workflow..."
	@chmod +x scripts/setup-youtube-workflow.sh
	./scripts/setup-youtube-workflow.sh

n8n-status:
	@echo "=== n8n Container Status ==="
	@docker ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "n8n not running"
	@echo ""
	@echo "=== n8n Service Status ==="
	@systemctl status n8n-automation --no-pager 2>/dev/null || echo "n8n service not installed"

n8n-logs:
	@echo "Tailing n8n logs (Ctrl+C to stop)..."
	@cd /opt/n8n-automation && (docker compose logs -f 2>/dev/null || docker-compose logs -f 2>/dev/null) || docker logs -f n8n-shorts-automation 2>/dev/null || echo "n8n container not found"

n8n-restart:
	@echo "Restarting n8n..."
	@sudo systemctl restart n8n-automation 2>/dev/null || (cd /opt/n8n-automation && docker compose restart 2>/dev/null || docker-compose restart)
	@echo "n8n restarted"

n8n-stop:
	@echo "Stopping n8n..."
	@sudo systemctl stop n8n-automation 2>/dev/null || (cd /opt/n8n-automation && docker compose down 2>/dev/null || docker-compose down)
	@echo "n8n stopped"
