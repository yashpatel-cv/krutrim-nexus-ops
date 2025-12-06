// Chart.js configuration and initialization
let cpuChart, memoryChart, networkChart;

// Initialize charts on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeCharts();
    loadChartData();
    
    // Update charts every 5 minutes
    setInterval(loadChartData, 300000);
});

function initializeCharts() {
    const chartOptions = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false },
            tooltip: {
                backgroundColor: '#0f1429',
                titleColor: '#00ff41',
                bodyColor: '#e0e0e0',
                borderColor: '#00ff41',
                borderWidth: 1
            }
        },
        scales: {
            x: {
                grid: { color: '#1a1f3a' },
                ticks: { color: '#a0a0a0' }
            },
            y: {
                grid: { color: '#1a1f3a' },
                ticks: { color: '#a0a0a0' },
                beginAtZero: true,
                max: 100
            }
        }
    };

    // CPU Chart
    const cpuCtx = document.getElementById('cpu-chart').getContext('2d');
    cpuChart = new Chart(cpuCtx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'CPU %',
                data: [],
                borderColor: '#00ff41',
                backgroundColor: 'rgba(0, 255, 65, 0.1)',
                borderWidth: 2,
                tension: 0.4,
                fill: true
            }]
        },
        options: chartOptions
    });

    // Memory Chart
    const memCtx = document.getElementById('memory-chart').getContext('2d');
    memoryChart = new Chart(memCtx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Memory %',
                data: [],
                borderColor: '#00ffff',
                backgroundColor: 'rgba(0, 255, 255, 0.1)',
                borderWidth: 2,
                tension: 0.4,
                fill: true
            }]
        },
        options: chartOptions
    });

    // Network Chart
    const netCtx = document.getElementById('network-chart').getContext('2d');
    networkChart = new Chart(netCtx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Network MB/s',
                data: [],
                borderColor: '#ffff00',
                backgroundColor: 'rgba(255, 255, 0, 0.1)',
                borderWidth: 2,
                tension: 0.4,
                fill: true
            }]
        },
        options: { ...chartOptions, scales: { ...chartOptions.scales, y: { ...chartOptions.scales.y, max: null } } }
    });
}

async function loadChartData() {
    try {
        const response = await fetch(`${API_BASE}/api/analytics/performance?duration_hours=24`);
        const data = await response.json();
        
        updateChart(cpuChart, data.cpu_history);
        updateChart(memoryChart, data.memory_history);
        updateChart(networkChart, data.network_history);
        
    } catch (error) {
        console.error('[Charts] Load error:', error);
    }
}

function updateChart(chart, dataPoints) {
    if (!dataPoints || dataPoints.length === 0) return;
    
    chart.data.labels = dataPoints.map(d => new Date(d.timestamp).toLocaleTimeString());
    chart.data.datasets[0].data = dataPoints.map(d => d.value);
    chart.update('none'); // Update without animation for performance
}
