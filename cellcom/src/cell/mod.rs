pub mod data;
pub mod parser;
pub mod types;

use anyhow::{Context, Result};
pub use data::{NeighborCell, ServingCell};
use parser::{parse_neighbor_cells, parse_serving_cell};
use serialport::SerialPort;
use std::io::{Read, Write};
use std::time::Duration;

/// Represents a connection to the EC25 modem for issuing QENG commands.
pub struct EC25Modem {
    // TODO: maybe genercize this idk
    port: Box<dyn SerialPort>,
    debug: bool,
}

impl EC25Modem {
    /// Opens the specified serial device and returns a new EC25Modem.
    pub fn new(device: &str, debug: bool) -> Result<Self> {
        let port = serialport::new(device, 115_200)
            .timeout(Duration::from_secs(2))
            .open()
            .with_context(|| format!("Failed to open serial port '{}'", device))?;

        Ok(Self { port, debug })
    }

    /// Sends an AT command, returning the raw response string until "OK" or "ERROR".
    fn send_command(&mut self, command: &str) -> Result<String> {
        let cmd = format!("{}\r\n", command);
        self.port.write_all(cmd.as_bytes())?;
        let mut response = String::new();
        let mut buf = [0u8; 1024];

        loop {
            match self.port.read(&mut buf) {
                Ok(n) if n > 0 => {
                    response.push_str(&String::from_utf8_lossy(&buf[..n]));
                    if response.contains("OK") || response.contains("ERROR") {
                        break;
                    }
                }
                Ok(_) | Err(_) => break,
            }
        }

        if self.debug {
            eprintln!("Debug: Sent '{}' => Received:\n{}", command, response);
        }

        Ok(response)
    }

    /// Issues AT+QENG="servingcell" and parses into a ServingCell.
    pub fn get_serving_cell(&mut self) -> Result<ServingCell> {
        let response = self.send_command("AT+QENG=\"servingcell\"")?;
        parse_serving_cell(&response)
            .with_context(|| "Failed to parse serving cell info from the EC25 response")
    }

    /// Issues AT+QENG="neighbourcell" and parses into a list of NeighborCell.
    pub fn get_neighbor_cells(&mut self) -> Result<Vec<NeighborCell>> {
        let response = self.send_command("AT+QENG=\"neighbourcell\"")?;
        parse_neighbor_cells(&response).with_context(|| {
            "Failed to parse neighbor cell info from the EC25 response"
        })
    }
}
