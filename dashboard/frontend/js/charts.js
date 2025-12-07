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
                backgroundColor: 'rgba(0, 0, 0, 0.9)',
                titleColor: '#00b4d8',
                bodyColor: '#e8e8e8',
                borderColor: '#00b4d8',
                borderWidth: 1,
                padding: 12,
                displayColors: false
            }
        },
        scales: {
            x: {
                grid: { 
                    display: false
                },
                ticks: { 
                    color: '#666666',
                    maxRotation: 45,
                    minRotation: 45
                },
                border: {
                    display: false
                }
            },
            y: {
                grid: { 
                    color: 'rgba(38, 38, 38, 0.3)',
                    drawTicks: false
                },
                ticks: { 
                    color: '#666666',
                    padding: 8
                },
                beginAtZero: true,
                max: 100,
                border: {
                    display: false
                }
            }
        },
        interaction: {
            intersect: false,
            mode: 'index'
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
                borderColor: '#00e676',
                backgroundColor: 'rgba(0, 230, 118, 0.1)',
                borderWidth: 2.5,
                tension: 0.3,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointHoverBackgroundColor: '#00e676',
                pointHoverBorderColor: '#000'
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
                borderColor: '#00b0ff',
                backgroundColor: 'rgba(0, 176, 255, 0.1)',
                borderWidth: 2.5,
                tension: 0.3,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointHoverBackgroundColor: '#00b0ff',
                pointHoverBorderColor: '#000'
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
                borderColor: '#bb86fc',
                backgroundColor: 'rgba(187, 134, 252, 0.1)',
                borderWidth: 2.5,
                tension: 0.3,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointHoverBackgroundColor: '#bb86fc',
                pointHoverBorderColor: '#000'
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
