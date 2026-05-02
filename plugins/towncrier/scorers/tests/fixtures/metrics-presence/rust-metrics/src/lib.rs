use metrics::{counter, gauge, histogram};

pub fn record() {
    counter!("requests_total", 1);
    histogram!("latency_seconds", 1.5);
    gauge!("active_connections", 42.0);
}
