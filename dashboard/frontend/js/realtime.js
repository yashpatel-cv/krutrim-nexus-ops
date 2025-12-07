// WebSocket real-time updates
let ws = null;
window.wsConnected = false;
let reconnectTimer = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_DELAY = 5000;

function toggleRealtime() {
    if (ws && ws.readyState === WebSocket.OPEN) {
        disconnectWebSocket();
    } else {
        connectWebSocket();
    }
}

function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/realtime`;
    
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        window.wsConnected = true;
        reconnectAttempts = 0;
        updateConnectionStatus('Connected', true);
        debouncedLog('info', 'Real-time connection established');
    };
    
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleRealtimeUpdate(data);
        } catch (error) {
            console.error('[WebSocket] Parse error:', error);
        }
    };
    
    ws.onerror = (error) => {
        console.error('[WebSocket] Error:', error);
    };
    
    ws.onclose = () => {
        window.wsConnected = false;
        updateConnectionStatus('Disconnected', false);
        
        // Auto-reconnect with exponential backoff
        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            reconnectAttempts++;
            const delay = RECONNECT_DELAY * Math.pow(2, reconnectAttempts - 1);
            debouncedLog('warn', `Connection closed. Reconnecting in ${delay/1000}s (attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
            
            reconnectTimer = setTimeout(() => {
                connectWebSocket();
            }, delay);
        } else {
            debouncedLog('error', 'Max reconnection attempts reached');
        }
    };
}

function updateConnectionStatus(text, connected) {
    const statusEl = document.getElementById('realtime-status');
    const connEl = document.getElementById('connection-status');
    const dotEl = document.getElementById('connection-dot');
    const btnEl = document.getElementById('realtime-btn');
    
    if (statusEl) statusEl.textContent = connected ? 'Disconnect' : 'Connect Live';
    if (connEl) connEl.textContent = text;
    if (dotEl) dotEl.classList.toggle('connected', connected);
    if (btnEl) btnEl.classList.toggle('active', connected);
}

function disconnectWebSocket() {
    if (reconnectTimer) {
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
    }
    reconnectAttempts = MAX_RECONNECT_ATTEMPTS; // Prevent auto-reconnect
    
    if (ws) {
        ws.close();
        ws = null;
    }
}

function handleRealtimeUpdate(data) {
    if (data.type === 'metrics_update') {
        // Update real-time metrics without full reload
        updateRealtimeMetrics(data.data);
    }
}

// Throttle metric updates to prevent excessive DOM manipulation
let lastUpdate = 0;
const UPDATE_THROTTLE = 500; // ms

function updateRealtimeMetrics(metrics) {
    const now = Date.now();
    if (now - lastUpdate < UPDATE_THROTTLE) {
        return; // Skip update if too soon
    }
    lastUpdate = now;
    
    // Use requestAnimationFrame for smooth updates
    requestAnimationFrame(() => {
        // Update overview cards with smooth transitions
        updateElementIfExists('managers-count', metrics.total_nodes || '0');
        updateElementIfExists('workers-count', metrics.total_nodes || '0');
        updateElementIfExists('services-count', metrics.total_services || '0');
        
        // Update health status if available
        if (metrics.cpu_usage !== undefined) {
            updateMetricBar('cpu-usage', metrics.cpu_usage);
        }
        if (metrics.memory_usage !== undefined) {
            updateMetricBar('memory-usage', metrics.memory_usage);
        }
        if (metrics.disk_usage !== undefined) {
            updateMetricBar('disk-usage', metrics.disk_usage);
        }
    });
}

function updateElementIfExists(id, value) {
    const el = document.getElementById(id);
    if (el && el.textContent !== String(value)) {
        el.textContent = value;
        el.classList.add('updated');
        setTimeout(() => el.classList.remove('updated'), 300);
    }
}

function updateMetricBar(id, percentage) {
    const bar = document.querySelector(`#${id} .metric-bar-fill`);
    if (bar) {
        bar.style.width = `${Math.min(100, Math.max(0, percentage))}%`;
    }
}
