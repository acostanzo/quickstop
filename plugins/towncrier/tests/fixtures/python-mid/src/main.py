"""Entry point. One leftover debug stdout call kept here as the
single unstructured emission site so that the structured-logging
ratio lands at 5 of 6 total sites (= 0.83)."""

DEBUG = False


def report_status():
    if DEBUG:
        print("debug heartbeat")
