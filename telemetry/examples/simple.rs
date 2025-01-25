use tracing::{debug, error, info, trace, warn};

fn main() {
    let _guard = orb_telemetry::TelemetryConfig::new().init();

    trace!("TRACE");
    debug!("DEBUG");
    info!("INFO");
    warn!("WARN");
    error!("ERROR");
}
