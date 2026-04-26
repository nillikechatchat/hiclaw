//! Worker configuration management

use serde::{Deserialize, Serialize};
use std::path::Path;
use anyhow::{Context, Result};
use std::env;

/// Worker configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkerConfig {
    /// Matrix configuration
    #[serde(default)]
    pub matrix: MatrixConfig,
    /// Higress configuration
    #[serde(default)]
    pub higress: HigressConfig,
    /// Skills configuration
    #[serde(default)]
    pub skills: SkillsConfig,
}

/// Matrix homeserver configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatrixConfig {
    /// Homeserver URL
    #[serde(default)]
    pub homeserver_url: String,
    /// Access token for authentication
    #[serde(default)]
    pub access_token: String,
    /// Username
    #[serde(default)]
    pub username: String,
}

/// Higress gateway configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HigressConfig {
    /// Gateway base URL
    #[serde(default = "default_higress_base_url")]
    pub base_url: String,
    /// Consumer token for authentication
    #[serde(default)]
    pub consumer_token: String,
}

/// Skills configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillsConfig {
    /// Enabled skills
    #[serde(default)]
    pub enabled: Vec<String>,
}

fn default_higress_base_url() -> String {
    "http://127.0.0.1:8080".to_string()
}

impl Default for WorkerConfig {
    fn default() -> Self {
        Self {
            matrix: MatrixConfig::default(),
            higress: HigressConfig::default(),
            skills: SkillsConfig::default(),
        }
    }
}

impl Default for MatrixConfig {
    fn default() -> Self {
        Self {
            homeserver_url: String::new(),
            access_token: String::new(),
            username: String::new(),
        }
    }
}

impl Default for HigressConfig {
    fn default() -> Self {
        Self {
            base_url: default_higress_base_url(),
            consumer_token: String::new(),
        }
    }
}

impl Default for SkillsConfig {
    fn default() -> Self {
        Self {
            enabled: Vec::new(),
        }
    }
}

fn resolve_worker_name() -> String {
    env::var("HICLAW_WORKER_NAME")
        .or_else(|_| env::var("WORKER_NAME"))
        .unwrap_or_else(|_| "zeroclaw-worker".to_string())
}

impl WorkerConfig {
    /// Load configuration from file, with environment variable fallbacks
    pub fn load() -> Result<Self> {
        let worker_name = resolve_worker_name();
        let config_path = Path::new(&format!(
            "/root/hiclaw-fs/agents/{}/zeroclaw.json",
            worker_name
        ));

        let mut config = if config_path.exists() {
            let config_str = std::fs::read_to_string(config_path)
                .context("Failed to read config file")?;
            serde_json::from_str(&config_str)
                .context("Failed to parse config JSON")?
        } else {
            WorkerConfig::default()
        };

        // Environment variable fallbacks for Matrix config
        if config.matrix.homeserver_url.is_empty() {
            if let Ok(v) = env::var("HICLAW_MATRIX_URL") {
                config.matrix.homeserver_url = v;
            }
        }
        if config.matrix.access_token.is_empty() {
            if let Ok(v) = env::var("HICLAW_WORKER_MATRIX_TOKEN") {
                config.matrix.access_token = v;
            }
        }
        if config.matrix.username.is_empty() {
            if let Ok(v) = env::var("HICLAW_WORKER_NAME").or_else(|_| env::var("WORKER_NAME")) {
                config.matrix.username = v;
            }
        }

        // Environment variable fallbacks for Higress config
        if config.higress.base_url.is_empty() || config.higress.base_url == default_higress_base_url() {
            if let Ok(v) = env::var("HICLAW_AI_GATEWAY_URL") {
                config.higress.base_url = v;
            }
        }
        if config.higress.consumer_token.is_empty() {
            if let Ok(v) = env::var("HICLAW_WORKER_GATEWAY_KEY") {
                config.higress.consumer_token = v;
            }
        }

        Ok(config)
    }
}
