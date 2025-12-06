// WebSocket real-time updates
let ws = null;
window.wsConnected = false;

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
        document.getElementById('realtime-status').textContent = 'Connected';
        document.getElementById('connection-status').textContent = 'Connected';
        document.getElementById('connection-status').classList.add('connected');
        addLog('info', 'Real-time connection established');
    };
    
    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        handleRealtimeUpdate(data);
    };
    
    ws.onerror = (error) => {
        addLog('error', 'WebSocket error');
        console.error('[WebSocket] Error:', error);
    };
    
    ws.onclose = () => {
        window.wsConnected = false;
        document.getElementById('realtime-status').textContent = 'Connect';
        document.getElementById('connection-status').textContent = 'Disconnected';
        document.getElementById('connection-status').classList.remove('connected');
        addLog('warn', 'Real-time connection closed');
    };
}

function disconnectWebSocket() {
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

function updateRealtimeMetrics(metrics) {
    // Update overview if elements exist
    const cpuEl = document.querySelector('.metric-large');
    if (cpuEl && metrics.cpu_usage !== undefined) {
        // Update displayed metrics
        console.log('[Realtime] Metrics updated:', metrics);
    }
}
