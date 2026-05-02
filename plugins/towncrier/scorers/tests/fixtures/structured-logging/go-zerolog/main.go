package main

import (
	"log/slog"
)

func handle() {
	slog.Info("event_one")
	slog.Warn("event_two")
	slog.Error("event_three")
	slog.Debug("event_four")
}
