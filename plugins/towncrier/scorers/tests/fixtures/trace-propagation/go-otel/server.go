package main

import (
	"net/http"

	"go.opentelemetry.io/otel"
)

var tracer = otel.Tracer("svc")

func setup() {
	http.HandleFunc("/items", func(w http.ResponseWriter, r *http.Request) {
		_, span := tracer.Start(r.Context(), "items")
		defer span.End()
		w.Write([]byte("ok"))
	})
	http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
		_, span := tracer.Start(r.Context(), "users")
		defer span.End()
		w.Write([]byte("ok"))
	})
}
