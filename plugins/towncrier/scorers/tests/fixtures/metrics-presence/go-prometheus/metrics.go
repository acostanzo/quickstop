package main

import (
	"github.com/prometheus/client_golang/prometheus"
)

var (
	requestsTotal  = prometheus.NewCounter(prometheus.CounterOpts{Name: "requests_total"})
	latencySeconds = prometheus.NewHistogram(prometheus.HistogramOpts{Name: "latency_seconds"})
	activeConn     = prometheus.NewGauge(prometheus.GaugeOpts{Name: "active_connections"})
)
