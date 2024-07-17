#![forbid(unsafe_code)]

use std::sync::OnceLock;
use std::time::Duration;
use std::{env, fs};

use clap::Parser;
use eyre::{Context, Result};
use orb_build_info::{make_build_info, BuildInfo};
use tokio::sync::mpsc;
use tokio::time;
use tracing::debug;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::{filter::LevelFilter, fmt, EnvFilter};

use crate::engine::{Engine, EventChannel};
use crate::observer::listen;
use crate::simulation::signup_simulation;

mod dbus;
mod engine;
mod hal; // hardware abstraction layer
mod observer;
mod simulation;
pub mod sound;

const BUILD_INFO: BuildInfo = make_build_info!();

/// Utility args
#[derive(Parser, Debug)]
#[clap(
    author,
    version=BUILD_INFO.version,
    about = "Orb UI daemon",
    long_about = "Handles the UI of the Orb, based on dbus messages"
)]
struct Args {
    #[clap(subcommand)]
    subcmd: SubCommand,
}

#[derive(Parser, Debug)]
enum SubCommand {
    /// Orb UI daemon, listening and reacting to dbus messages
    #[clap(action)]
    Daemon,

    /// Signup simulation
    #[clap(action)]
    Simulation,

    /// Recovery UI
    #[clap(action)]
    Recovery,
}
static HW_VERSION_FILE: OnceLock<String> = OnceLock::new();

fn get_hw_version() -> Result<String> {
    let hw_file = HW_VERSION_FILE.get_or_init(|| {
        env::var("HW_VERSION_FILE")
            .unwrap_or_else(|_| "/usr/persistent/hardware_version".to_string())
    });
    debug!("Reading HW version from {}", hw_file.as_str());

    String::from_utf8(
        fs::read(hw_file.as_str())
            .map_err(|e| {
                tracing::error!(
                    "Executing UI for Pearl as an error occurred while reading file \"{}\": {}",
                    hw_file.as_str(),
                    e
                )
            })
            .unwrap_or_default()
    ).wrap_err("Failed to read HW version")
}

#[tokio::main]
async fn main() -> Result<()> {
    let registry = tracing_subscriber::registry();
    #[cfg(tokio_unstable)]
    let registry = registry.with(console_subscriber::spawn());
    registry
        .with(fmt::layer())
        .with(
            EnvFilter::builder()
                .with_default_directive(LevelFilter::INFO.into())
                .from_env_lossy(),
        )
        .init();

    let args = Args::parse();
    let hw = get_hw_version()?;
    let (mut hal_tx, hal_rx) = mpsc::channel(hal::INPUT_CAPACITY);
    match args.subcmd {
        SubCommand::Daemon => {
            if hw.contains("Diamond") {
                let ui = engine::DiamondJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                let send_ui: &dyn EventChannel = &ui;
                listen(send_ui).await?;
            } else {
                let ui = engine::PearlJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                let send_ui: &dyn EventChannel = &ui;
                listen(send_ui).await?;
            };
        }
        SubCommand::Simulation => {
            let ui: Box<dyn Engine> = if hw.contains("Diamond") {
                let engine = engine::DiamondJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                Box::new(engine)
            } else {
                let engine = engine::PearlJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                Box::new(engine)
            };
            signup_simulation(ui.as_ref()).await?;
        }
        SubCommand::Recovery => {
            let ui: Box<dyn Engine> = if hw.contains("Diamond") {
                let engine = engine::DiamondJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                Box::new(engine)
            } else {
                let engine = engine::PearlJetson::spawn(&mut hal_tx);
                let _interface = hal::Hal::spawn(hal_rx)?;
                Box::new(engine)
            };
            loop {
                ui.recovery();
                time::sleep(Duration::from_secs(45)).await;
            }
        }
    }

    Ok(())
}

/// Just like `tokio::spawn()`, but if we are using unstable tokio features, we give
/// the task a readable `name`.
fn tokio_spawn<F>(name: &'static str, future: F) -> tokio::task::JoinHandle<F::Output>
where
    F: std::future::Future + Send + 'static,
    F::Output: Send + 'static,
{
    let _name = name; // Deal with "unused" variable;
    #[cfg(tokio_unstable)]
    return tokio::task::Builder::new()
        .name(_name)
        .spawn(future)
        .expect("failed to spawn async task");
    #[cfg(not(tokio_unstable))]
    return tokio::spawn(future);
}
