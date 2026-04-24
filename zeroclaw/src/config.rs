//! Worker configuration management

use serde::{Deserialize, Serialize};
use std::path::Path;
use anyhow::{Context, Result};

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
    pub homeserver_url: String,
    /// Access token for authentication
    pub access_token: String,
    /// Username
    pub username: String,
}

/// Higress gateway configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HigressConfig {
    /// Gateway base URL
    pub base_url: String,
    /// Consumer token for authentication
    pub consumer_token: String,
}

/// Skills configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillsConfig {
    /// Enabled skills
    pub enabled: Vec<String>,
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
            base_url: "http://127.0.0.1:8080".to_string(),
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

impl WorkerConfig {
    /// Load configuration from file
    pub fn load() -> Result<Self> {
        let config_path = Path::new("/root/hiclaw-fs/agents/zeroclaw.json");
        
        if !config_path.exists() {
            anyhow::bail!("Config file not found: {:?}", config_path);
        }

        let config_str = std::fs::read_to_string(config_path)
            .context("Failed to read config file")?;
        
        let config: WorkerConfig = serde_json::from_str(&config_str)
            .context("Failed to parse config JSON")?;

        Ok(config)
    }
}
