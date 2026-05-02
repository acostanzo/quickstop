pub fn handle() {
    tracing::info!(event = "ok");
    tracing::warn!(event = "slow");
    tracing::error!(event = "fail");
    tracing::debug!(event = "trace");
}
