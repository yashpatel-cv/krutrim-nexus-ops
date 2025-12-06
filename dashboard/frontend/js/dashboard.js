// Krutrim Nexus Ops - Dashboard Main Logic

const API_BASE = window.location.origin;
let currentFilters = { status: 'all', type: 'all' };

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
    console.log('[Dashboard] Initializing...');
    setupFilterButtons();
    loadDashboardData();
    
    // Refresh every 30 seconds if not using WebSocket
    setInterval(() => {
        if (!window.wsConnected) {
            loadDashboardData();
        }
    }, 30000);
});

// Setup filter button handlers
function setupFilterButtons() {
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const filterType = e.target.dataset.filter;
            const filterValue = e.target.dataset.value;
            
            // Update active state
            document.querySelectorAll(`[data-filter="${filterType}"]`).forEach(b => {
                b.classList.remove('active');
            });
            e.target.classList.add('active');
            
            // Update filter
            currentFilters[filterType] = filterValue;
            applyFilters();
        });
    });
}

// Load all dashboard data
async function loadDashboardData() {
    try {
        await Promise.all([
            loadOverview(),
            loadManagers(),
            loadWorkers()
        ]);
        
        updateLastUpdateTime();
        addLog('info', 'Dashboard data refreshed');
    } catch (error) {
        console.error('[Dashboard] Load error:', error);
        addLog('error', `Failed to load data: ${error.message}`);
    }
}

// Load overview metrics
async function loadOverview() {
    try {
        const response = await fetch(`${API_BASE}/api/analytics/overview`);
        const data = await response.json();
        
        // Update overview cards
        document.getElementById('managers-count').textContent = data.healthy_managers;
        document.getElementById('managers-healthy').textContent = data.healthy_managers;
        document.getElementById('managers-total').textContent = data.total_managers;
        
        document.getElementById('workers-count').textContent = data.healthy_workers;
        document.getElementById('workers-healthy').textContent = data.healthy_workers;
        document.getElementById('workers-total').textContent = data.total_workers;
        document.getElementById('active-count').textContent = `${data.healthy_workers}/${data.total_workers}`;
        
        document.getElementById('services-count').textContent = data.running_services;
        document.getElementById('services-running').textContent = data.running_services;
        document.getElementById('services-total').textContent = data.total_services;
        
        const healthEl = document.getElementById('cluster-health');
        healthEl.textContent = data.cluster_health.toUpperCase();
        healthEl.className = `metric-large status-indicator ${data.cluster_health}`;
        
    } catch (error) {
        console.error('[Dashboard] Overview error:', error);
    }
}

// Load managers
async function loadManagers() {
    try {
        const response = await fetch(`${API_BASE}/api/managers/`);
        const managers = await response.json();
        
        const grid = document.getElementById('managers-grid');
        grid.innerHTML = managers.map(m => createManagerCard(m)).join('');
        
    } catch (error) {
        console.error('[Dashboard] Managers error:', error);
    }
}

// Load workers
async function loadWorkers() {
    try {
        const response = await fetch(`${API_BASE}/api/workers/`);
        const workers = await response.json();
        
        const grid = document.getElementById('workers-grid');
        grid.innerHTML = workers.map(w => createWorkerCard(w)).join('');
        
        applyFilters();
    } catch (error) {
        console.error('[Dashboard] Workers error:', error);
    }
}

// Create manager card HTML
function createManagerCard(manager) {
    return `
        <div class="node-card manager" data-status="${manager.status}" data-type="manager">
            <div class="node-header">
                <div>
                    <div class="node-name">${manager.hostname}</div>
                    <div class="node-role">${manager.role}</div>
                </div>
                <span class="status-badge ${manager.status}">${manager.status}</span>
            </div>
            <div class="node-metrics">
                <div class="metric-item">
                    <div class="metric-label">CPU</div>
                    <div class="metric-value">${manager.cpu_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${manager.cpu_usage}%"></div>
                    </div>
                </div>
                <div class="metric-item">
                    <div class="metric-label">Memory</div>
                    <div class="metric-value">${manager.memory_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${manager.memory_usage}%"></div>
                    </div>
                </div>
                <div class="metric-item">
                    <div class="metric-label">Disk</div>
                    <div class="metric-value">${manager.disk_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${manager.disk_usage}%"></div>
                    </div>
                </div>
            </div>
            <div class="metric-sub">
                Workers: ${manager.healthy_workers}/${manager.managed_workers} | 
                Uptime: ${formatUptime(manager.uptime_seconds)}
            </div>
            <div class="node-actions">
                <button class="btn-small" onclick="viewManagerDetails('${manager.id}')">Details</button>
                <button class="btn-small" onclick="restartManager('${manager.id}')">Restart</button>
            </div>
        </div>
    `;
}

// Create worker card HTML
function createWorkerCard(worker) {
    return `
        <div class="node-card worker" data-status="${worker.status}" data-type="worker">
            <div class="node-header">
                <div>
                    <div class="node-name">${worker.hostname}</div>
                    <div class="node-role">${worker.pool}</div>
                </div>
                <span class="status-badge ${worker.status}">${worker.status}</span>
            </div>
            <div class="node-metrics">
                <div class="metric-item">
                    <div class="metric-label">CPU</div>
                    <div class="metric-value">${worker.cpu_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${worker.cpu_usage}%"></div>
                    </div>
                </div>
                <div class="metric-item">
                    <div class="metric-label">Memory</div>
                    <div class="metric-value">${worker.memory_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${worker.memory_usage}%"></div>
                    </div>
                </div>
                <div class="metric-item">
                    <div class="metric-label">Disk</div>
                    <div class="metric-value">${worker.disk_usage.toFixed(1)}%</div>
                    <div class="metric-bar">
                        <div class="metric-bar-fill" style="width: ${worker.disk_usage}%"></div>
                    </div>
                </div>
            </div>
            <div class="metric-sub">
                Services: ${worker.healthy_services}/${worker.total_services} | 
                Uptime: ${formatUptime(worker.uptime_seconds)}
            </div>
            <div class="node-actions">
                <button class="btn-small" onclick="viewWorkerDetails('${worker.id}')">Details</button>
                <button class="btn-small" onclick="restartWorker('${worker.id}')">Restart</button>
            </div>
        </div>
    `;
}

// Apply filters to node cards
function applyFilters() {
    document.querySelectorAll('.node-card').forEach(card => {
        const status = card.dataset.status;
        const type = card.dataset.type;
        
        const statusMatch = currentFilters.status === 'all' || status === currentFilters.status;
        const typeMatch = currentFilters.type === 'all' || type === currentFilters.type;
        
        card.style.display = (statusMatch && typeMatch) ? 'block' : 'none';
    });
}

// Utility functions
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) return `${days}d ${hours}h`;
    if (hours > 0) return `${hours}h ${mins}m`;
    return `${mins}m`;
}

function updateLastUpdateTime() {
    const now = new Date();
    document.getElementById('last-update').textContent = now.toLocaleTimeString();
}

function addLog(level, message) {
    const logsContent = document.getElementById('logs-content');
    const timestamp = new Date().toLocaleTimeString();
    const logLine = document.createElement('div');
    logLine.className = `log-line ${level}`;
    logLine.textContent = `[${timestamp}] [${level.toUpperCase()}] ${message}`;
    logsContent.appendChild(logLine);
    logsContent.scrollTop = logsContent.scrollHeight;
}

function clearLogs() {
    document.getElementById('logs-content').innerHTML = '<div class="log-line">[INFO] Logs cleared</div>';
}

function refreshDashboard() {
    addLog('info', 'Manual refresh triggered');
    loadDashboardData();
}

// Action handlers
async function viewManagerDetails(id) {
    addLog('info', `Viewing details for ${id}`);
    // Would open modal or navigate to detail page
}

async function restartManager(id) {
    if (!confirm(`Restart manager ${id}?`)) return;
    
    try {
        const response = await fetch(`${API_BASE}/api/managers/${id}/restart`, { method: 'POST' });
        const result = await response.json();
        addLog('info', result.message);
    } catch (error) {
        addLog('error', `Failed to restart ${id}: ${error.message}`);
    }
}

async function viewWorkerDetails(id) {
    addLog('info', `Viewing details for ${id}`);
}

async function restartWorker(id) {
    if (!confirm(`Restart worker ${id}?`)) return;
    
    try {
        const response = await fetch(`${API_BASE}/api/workers/${id}/restart`, { method: 'POST' });
        const result = await response.json();
        addLog('info', result.message);
    } catch (error) {
        addLog('error', `Failed to restart ${id}: ${error.message}`);
    }
}
