# Krutrim Nexus Ops - Installation Guide

## Quick Start

```bash
# On your server
cd /opt/krutrim-nexus-ops
git pull origin main
sudo ./install.sh
# Select: 3 (Manager + Worker)
# Answer: Y (Dashboard)
```

## What's New

### ✅ Production Ready Hardening
- **Configuration Management**: All settings configurable via environment variables
- **Dependency Locking**: All versions locked to stable releases  
- **Error Handling**: Comprehensive error handling with graceful degradation
- **Validation**: Pre-flight checks, input validation, environment validation
- **Security**: No hardcoded secrets, configurable CORS, input sanitization

### ✅ New Files
- `dashboard/backend/config.py` - Centralized configuration system
- `dashboard/backend/.env.example` - Environment configuration template
- `docs/COMPREHENSIVE_HARDENING_REPORT.md` - Complete analysis (580 lines)

### ✅ Enhanced Files
- `dashboard/backend/app.py` - Config integration, exception handlers
- `services/consul_service.py` - Input validation, timeout, degradation
- `services/metrics_service.py` - Granular error handling
- `requirements.txt` - All versions locked

## Configuration

### Environment Variables (Optional)

Create `.env` file in `dashboard/backend/`:

```bash
# Copy example
cp dashboard/backend/.env.example dashboard/backend/.env

# Edit with your values
nano dashboard/backend/.env
```

### Key Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXUS_DEBUG` | `false` | Debug mode (enable for development) |
| `NEXUS_PORT` | `9000` | Dashboard port |
| `NEXUS_CONSUL_HOST` | `localhost` | Consul host |
| `NEXUS_CONSUL_PORT` | `8500` | Consul port |
| `NEXUS_SECRET_KEY` | ⚠️ **CHANGE THIS** | Secret key (32+ chars) |
| `NEXUS_CORS_ORIGINS` | `*` | CORS origins (restrict in production) |
| `NEXUS_LOG_LEVEL` | `INFO` | Log level (DEBUG/INFO/WARNING/ERROR) |

## Access Points

After successful installation:

- **Consul UI**: http://YOUR_SERVER_IP:8500
- **Dashboard**: http://YOUR_SERVER_IP:9000
- **API Docs**: http://YOUR_SERVER_IP:9000/api/docs (if debug=true)

## Verification

```bash
# Check all services
systemctl status consul
systemctl status nexus-orchestrator
systemctl status nexus-worker
systemctl status nexus-dashboard

# Check Consul cluster
consul members

# Test dashboard
curl http://localhost:9000/api/health
```

## Troubleshooting

### Services Not Starting

```bash
# Check logs
journalctl -u consul -n 50
journalctl -u nexus-dashboard -n 50

# Run fix script
sudo ./fix-services.sh
```

### Configuration Issues

```bash
# Test configuration
cd dashboard/backend
source venv/bin/activate
python3 -c "from config import settings; print(settings)"
```

### Environment Validation

```bash
# Test environment
cd dashboard/backend
source venv/bin/activate
python3 -c "from config import validate_environment; print(validate_environment())"
```

## Documentation

Complete documentation in `docs/`:

- **COMPREHENSIVE_HARDENING_REPORT.md** - Full analysis and hardening details
- **VALIDATION_REPORT.md** - Initial validation and Consul crash-loop fix
- **SETUP_GUIDE.md** - Detailed setup instructions
- **ARCHITECTURE.md** - System architecture
- **API_REFERENCE.md** - API documentation
- **TROUBLESHOOTING.md** - Common issues and solutions

## Production Deployment Checklist

- [ ] Create `.env` file from `.env.example`
- [ ] Set `NEXUS_SECRET_KEY` (generate with `openssl rand -hex 32`)
- [ ] Set `NEXUS_DEBUG=false`
- [ ] Configure `NEXUS_CORS_ORIGINS` (specific domains only)
- [ ] Set `NEXUS_CONSUL_TOKEN` (if using Consul ACLs)
- [ ] Review all `NEXUS_*` environment variables
- [ ] Test configuration before deployment
- [ ] Run environment validation
- [ ] Verify all services start successfully
- [ ] Test dashboard accessibility
- [ ] Check logs for any warnings

## Support

For issues or questions, check:
1. `docs/TROUBLESHOOTING.md`
2. `docs/COMPREHENSIVE_HARDENING_REPORT.md`
3. Service logs: `journalctl -u service-name`

---

**Status**: ✅ PRODUCTION READY  
**Last Updated**: December 7, 2025
