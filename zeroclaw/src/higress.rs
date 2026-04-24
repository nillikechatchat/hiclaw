//! Higress gateway HTTP client

use anyhow::Result;
use reqwest::{Client, RequestBuilder};
use tracing::info;
use crate::config::HigressConfig;

/// Higress HTTP client
#[derive(Clone)]
pub struct HigressClient {
    client: Client,
    base_url: String,
    token: Option<String>,
}

impl HigressClient {
    /// Create a new Higress client
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: String::new(),
            token: None,
        }
    }

    /// Initialize the client
    pub fn initialize(&mut self, config: &crate::config::WorkerConfig) -> Result<()> {
        self.base_url = config.higress.base_url.clone();
        self.token = if config.higress.consumer_token.is_empty() {
            None
        } else {
            Some(config.higress.consumer_token.clone())
        };
        
        info!("Higress client initialized: {}", self.base_url);
        Ok(())
    }

    /// Create an authenticated HTTP request
    pub fn post(&self, url: &str) -> RequestBuilder {
        let mut req = self.client.post(url);
        if let Some(token) = &self.token {
            req = req.bearer_auth(token);
        }
        req
    }
}

impl Default for HigressClient {
    fn default() -> Self {
        Self::new()
    }
}
