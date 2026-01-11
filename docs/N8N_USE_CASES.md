# n8n Automation Use Cases

n8n is a powerful workflow automation platform. While the YouTube Shorts workflow is pre-configured, you can use n8n for **hundreds of other automation tasks**.

## What is n8n?

n8n is like Zapier or Make.com, but:
- **Self-hosted** - Runs on your Oracle server (free)
- **No limits** - Unlimited workflows, executions, and nodes
- **400+ integrations** - Connect any service with an API
- **Visual editor** - Drag-and-drop workflow builder

---

## Popular Use Cases

### 1. Social Media Automation

```
Schedule Post → Generate Content (AI) → Post to Twitter/Instagram/LinkedIn
```

**Example workflow:**
- Trigger: Every day at 9 AM
- AI generates motivational quote
- Post to multiple platforms simultaneously

### 2. Email Marketing

```
New Subscriber → Welcome Email → Drip Campaign → Track Opens
```

**Integrations:** Mailchimp, SendGrid, ConvertKit, Gmail

### 3. Lead Generation

```
Form Submission → Enrich Data → Add to CRM → Notify Sales
```

**Example:**
- Typeform captures lead
- Clearbit enriches company data
- Add to HubSpot/Salesforce
- Slack notification to sales team

### 4. Content Repurposing

```
Blog Post → Generate Tweets → Create LinkedIn Post → Make Short Video
```

**AI-powered content transformation across platforms**

### 5. Customer Support

```
Support Ticket → Classify (AI) → Route to Team → Auto-Response
```

**Example:**
- Zendesk ticket created
- GPT classifies urgency/category
- Route to appropriate team
- Send acknowledgment email

### 6. E-commerce Automation

```
New Order → Update Inventory → Generate Invoice → Ship Notification
```

**Integrations:** Shopify, WooCommerce, Stripe, QuickBooks

### 7. Data Pipeline

```
API Fetch → Transform Data → Store in Database → Generate Report
```

**Example:**
- Fetch stock prices hourly
- Calculate metrics
- Store in PostgreSQL
- Weekly summary email

### 8. DevOps Alerts

```
Server Alert → Check Status → Restart Service → Notify Team
```

**Integrations:** Prometheus, Grafana, PagerDuty, Slack

### 9. Research Automation

```
RSS Feed → Filter Articles → Summarize (AI) → Email Digest
```

**Stay updated on industry news automatically**

### 10. Invoice Processing

```
Email with PDF → Extract Data (AI) → Add to Accounting → Archive
```

**Automate accounts payable workflow**

---

## Free AI APIs for n8n

| Service | Purpose | Free Tier |
|---------|---------|-----------|
| **Groq** | LLM (Llama 3.3) | 14,400 req/day |
| **Google Gemini** | Multimodal AI | 60 req/min |
| **Hugging Face** | ML Models | 30,000 req/month |
| **OpenRouter** | Multi-model access | $5 free credit |
| **Cohere** | Text generation | 100 req/min |
| **Mistral** | LLM | Limited free tier |

---

## How to Create a New Workflow

### Step 1: Access n8n

```bash
# Get your n8n URL and credentials
cat /opt/n8n-automation/ACCESS_INFO.txt
```

### Step 2: Create New Workflow

1. Click **"+ New Workflow"** button
2. Name your workflow (e.g., "Social Media Scheduler")
3. Drag nodes from the left panel

### Step 3: Add Trigger

Every workflow needs a trigger:
- **Schedule** - Run at specific times
- **Webhook** - Triggered by HTTP request
- **App trigger** - When something happens in an app (new email, form submission)

### Step 4: Add Action Nodes

Connect nodes to perform actions:
- HTTP Request - Call any API
- Code - Custom JavaScript/Python
- AI nodes - Groq, OpenAI, etc.
- App nodes - Gmail, Slack, etc.

### Step 5: Test & Activate

1. Click **"Execute Workflow"** to test
2. Check each node's output
3. Toggle **"Active"** to enable automation

---

## Example: Daily News Digest Workflow

```json
{
  "trigger": "Schedule (8 AM daily)",
  "steps": [
    {
      "node": "HTTP Request",
      "action": "Fetch RSS from TechCrunch, HackerNews"
    },
    {
      "node": "Code",
      "action": "Filter articles from last 24h"
    },
    {
      "node": "Groq AI",
      "action": "Summarize top 5 articles"
    },
    {
      "node": "Gmail",
      "action": "Send digest email"
    }
  ]
}
```

---

## Example: Slack Bot with AI

```json
{
  "trigger": "Slack - New message mentioning @bot",
  "steps": [
    {
      "node": "Code",
      "action": "Extract question from message"
    },
    {
      "node": "Groq AI",
      "action": "Generate response"
    },
    {
      "node": "Slack",
      "action": "Reply in thread"
    }
  ]
}
```

---

## Useful n8n Nodes

### Triggers
- `Schedule Trigger` - Cron-like scheduling
- `Webhook` - HTTP endpoint
- `Email Trigger (IMAP)` - New email received
- `RSS Feed Read` - New RSS items

### AI & LLM
- `HTTP Request` - Call Groq, OpenAI, etc.
- `Code` - Custom processing
- `OpenAI` - Built-in GPT integration
- `LangChain` - Advanced AI workflows

### Data
- `Postgres/MySQL` - Database operations
- `Google Sheets` - Spreadsheet automation
- `Airtable` - No-code database
- `Redis` - Caching

### Communication
- `Gmail/Outlook` - Email
- `Slack/Discord` - Team messaging
- `Telegram` - Bot integration
- `Twilio` - SMS/Voice

### Productivity
- `Notion` - Notes/Database
- `Todoist` - Task management
- `Google Calendar` - Scheduling
- `Trello` - Project boards

---

## Importing Community Workflows

n8n has a community library of pre-built workflows:

1. Visit: https://n8n.io/workflows/
2. Find a workflow you like
3. Click "Use workflow"
4. Copy the JSON
5. In n8n: Workflows → Import from JSON

---

## Tips for Building Workflows

1. **Start simple** - Get basic flow working first
2. **Test each node** - Click node and check output
3. **Use variables** - `{{ $json.fieldName }}` syntax
4. **Error handling** - Add error workflow for failures
5. **Logging** - Use "Set" node to log data
6. **Credentials** - Store API keys in Credentials, not in nodes

---

## Monitoring Your Workflows

```bash
# Check all workflow executions
make n8n-logs

# View in n8n UI
# Go to: Executions tab (left sidebar)
# See success/failure for each run

# Consul health check
curl http://localhost:8500/v1/catalog/service/n8n
```

---

## Resources

- **n8n Documentation**: https://docs.n8n.io
- **Workflow Templates**: https://n8n.io/workflows/
- **Community Forum**: https://community.n8n.io
- **YouTube Tutorials**: Search "n8n tutorial"

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `make setup-n8n` | Install n8n |
| `make n8n-status` | Check if running |
| `make n8n-logs` | View logs |
| `make n8n-restart` | Restart n8n |
| `make n8n-stop` | Stop n8n |

**Access n8n**: Check `/opt/n8n-automation/ACCESS_INFO.txt` for URL and credentials
