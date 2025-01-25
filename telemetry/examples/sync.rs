use std::time::Duration;

use tracing::{debug, error, info, instrument, trace, warn};

const SERVICE_NAME: &str = "my-service";
const SERVICE_VERSION: &str = "v1.2.3"; // get this from orb-build-info instead

fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;

    // You have to do this, otherwise opentelemetry will complain about missing a tokio reactor.
    // Multithreaded runtime is necessary otherwise the code will deadlock
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(1)
        .build()?;
    let _rt_ctx = rt.enter();

    let _tracing_guard = orb_telemetry::TelemetryConfig::new()
        // using opentelemetry will fail without a tokio reactor running.
        .with_opentelemetry(orb_telemetry::OpentelemetryConfig::new(
            orb_telemetry::OpentelemetryAttributes {
                service_name: SERVICE_NAME.to_string(),
                service_version: SERVICE_VERSION.to_string(),
                additional_otel_attributes: Default::default(),
            },
        )?)
        .with_journald(SERVICE_NAME)
        .init();

    trace!("TRACE");
    debug!("DEBUG");
    info!("INFO");
    warn!("WARN");
    error!("ERROR");

    some_longer_task(69);

    Ok(())
}

#[instrument]
fn some_longer_task(arg: u8) {
    std::thread::sleep(Duration::from_millis(1000));
    info!("got result: {arg}");
}
