# YouTube Shorts Automation Guide

Complete guide to setting up AI-powered YouTube Shorts automation on your Oracle Ampere server.

## Overview

This system automates the creation of YouTube Shorts using:
- **n8n** - Workflow automation platform
- **Groq AI** - Free LLM for script generation (14,400 req/day)
- **Pexels API** - Free stock video footage
- **Crikk TTS** - Free text-to-speech
- **Optional**: Creatomate/Remotion for video rendering

### Cost Breakdown

| Component | Cost | Limit |
|-----------|------|-------|
| Oracle Server | FREE | 4 OCPU ARM64, 24GB RAM |
| n8n | FREE | Self-hosted |
| Groq AI | FREE | 14,400 requests/day |
| Pexels | FREE | Unlimited |
| Crikk TTS | FREE | Unlimited |
| **Total** | **$0/month** | 4-8 videos/day |

With video rendering (Creatomate): **$39-49/month** for 300-500 videos

---

## Quick Start

### Prerequisites

Ensure your Oracle server is set up with Krutrim Nexus Ops:

```bash
cd /opt/krutrim-nexus-ops
sudo ./install.sh  # Select option 3 (Both)
```

### Step 1: Install n8n

```bash
cd /opt/krutrim-nexus-ops
make setup-n8n
```

This will:
- Install Docker and Docker Compose (if needed)
- Deploy n8n container
- Generate secure credentials
- Register with Consul for monitoring
- Create systemd service for auto-start

### Step 2: Setup YouTube Workflow

```bash
make setup-youtube
```

This creates the automation workflow with:
- 6-hour schedule trigger
- Groq AI script generation
- Pexels stock video fetching
- Crikk TTS voiceover
- Video data preparation

### Step 3: Get API Keys

| Service | URL | Notes |
|---------|-----|-------|
| Groq | https://console.groq.com/keys | Free, 14,400 req/day |
| Pexels | https://www.pexels.com/api/ | Free, unlimited |
| YouTube | https://console.cloud.google.com | Enable YouTube Data API v3 |

### Step 4: Configure n8n

1. Access n8n: `http://YOUR_SERVER_IP:5678`
2. Login with credentials from `/opt/n8n-automation/ACCESS_INFO.txt`
3. Go to **Workflows → Import from File**
4. Select: `/opt/n8n-automation/workflows/youtube-shorts-automation.json`
5. Edit workflow nodes to add your API keys
6. Toggle **Active** switch (top-right)

---

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SCHEDULE TRIGGER                         │
│                    (Every 6 hours)                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 GROQ AI (Script Agent)                      │
│   • Generates viral script                                  │
│   • Topics: science, what-if, war, physics                  │
│   • Output: Title | Script | Keywords                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   PARSE SCRIPT                              │
│   • Extracts title, script, keywords                        │
│   • Prepares data for parallel agents                       │
└──────────┬──────────────────────────────────┬───────────────┘
           │                                  │
           ▼                                  ▼
┌─────────────────────────┐    ┌─────────────────────────────┐
│   CRIKK TTS (Voice)     │    │   PEXELS API (Video)        │
│   • Converts to speech  │    │   • Fetches stock footage   │
│   • Neural voice        │    │   • Portrait orientation    │
└──────────┬──────────────┘    └──────────────┬──────────────┘
           │                                  │
           └──────────────┬───────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                 PREPARE VIDEO DATA                          │
│   • Combines voiceover + video clips                        │
│   • Prepares for rendering                                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              VIDEO RENDERING (Optional)                     │
│   • Creatomate ($39/mo) OR                                  │
│   • Remotion (free, self-hosted)                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 YOUTUBE UPLOAD                              │
│   • YouTube Data API v3                                     │
│   • Auto-publish to channel                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Management Commands

```bash
# Check n8n status
make n8n-status

# View logs
make n8n-logs

# Restart n8n
make n8n-restart

# Stop n8n
make n8n-stop

# View credentials
cat /opt/n8n-automation/ACCESS_INFO.txt

# Manual workflow test
# Access n8n UI → Open workflow → Click "Execute Workflow"
```

---

## Customization

### Change Schedule

Edit the "Schedule Every 6 Hours" node in n8n:
- Every 4 hours = 6 videos/day
- Every 3 hours = 8 videos/day
- Every 8 hours = 3 videos/day

### Modify Topics

Edit the Groq AI system prompt:

```
You are a viral YouTube Shorts scriptwriter. 
Generate 1 engaging 45-second script about:
- YOUR_TOPIC_1
- YOUR_TOPIC_2
- YOUR_TOPIC_3
```

### Add Video Rendering

For fully automated video generation, add one of these:

**Option 1: Creatomate ($39/month)**
- Best for beginners
- Cloud-based, no setup
- 300 videos/month

**Option 2: Remotion (Free)**
- Self-hosted on your Oracle server
- Requires Node.js setup
- Unlimited videos

---

## Troubleshooting

### n8n not starting

```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
docker logs n8n-shorts-automation

# Restart service
sudo systemctl restart n8n-automation
```

### Workflow not executing

1. Ensure workflow is **Active** (toggle in top-right)
2. Check schedule trigger is configured
3. View execution history in n8n UI

### API errors

1. Verify API keys are correct
2. Check rate limits (Groq: 14,400/day)
3. Test individual nodes in n8n

### Port conflicts

```bash
# Find what's using port 5678
sudo ss -tulpn | grep 5678

# Change port in docker-compose.yml if needed
```

---

## Security

- n8n is bound to `127.0.0.1` (local only)
- For remote access, use Caddy reverse proxy with HTTPS
- Credentials stored in `/opt/n8n-automation/ACCESS_INFO.txt` (chmod 600)
- API keys encrypted with AES-256 in n8n

### Enable HTTPS Access

Edit `/etc/caddy/conf.d/n8n.caddy` and uncomment the domain config:

```caddy
krutrimseva.cbu.net/n8n/* {
    reverse_proxy localhost:5678 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
}
```

Then reload Caddy: `sudo systemctl reload caddy`

---

## Files Reference

| File | Purpose |
|------|---------|
| `/opt/n8n-automation/docker-compose.yml` | n8n container config |
| `/opt/n8n-automation/ACCESS_INFO.txt` | Credentials and access info |
| `/opt/n8n-automation/API_KEYS_REQUIRED.txt` | API key setup guide |
| `/opt/n8n-automation/workflows/youtube-shorts-automation.json` | Main workflow |
| `/opt/n8n-automation/workflows/README.md` | Workflow documentation |

---

## Support

- n8n Docs: https://docs.n8n.io
- Groq Docs: https://console.groq.com/docs
- Pexels Docs: https://www.pexels.com/api/documentation/

For issues with Krutrim Nexus Ops, check the main documentation in `docs/`.
