"""User-facing CLI front-end. Eight free-form prints — the
unstructured emission surface that drives the structured-logging
ratio down to 0.20 in concert with src/log_helpers.py's two
structlog calls."""


def report_status():
    print("starting batch")
    print("processed 10 records")
    print("processed 20 records")
    print("processed 30 records")
    print("flushing buffers")
    print("closing handles")
    print("done")
    print("exit code 0")
