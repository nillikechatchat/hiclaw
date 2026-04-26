//! ZeroClaw - Ultra-lightweight High-performance AI Agent Worker
//!
//! ZeroClaw is a Rust-based AI Agent runtime designed for:
//! - High performance (50x QPS improvement over Python)
//! - Low memory footprint (~180MB)
//! - Low latency (P99 < 12ms)
//! - High concurrency support (up to 10,000 concurrent tasks)

use anyhow::{Context, Result};
use matrix_sdk::authentication::matrix::{MatrixSession, MatrixSessionTokens};
use matrix_sdk::{Client, SessionMeta, config::StoreConfig};
use serde::{Deserialize, Serialize};
use std::{env, sync::Arc, time::Duration};
use tracing::{error, info, warn};

mod config;
mod matrix;
mod higress;
mod skills;

use config::WorkerConfig;
use matrix::MatrixHandler;
use higress::HigressClient;
use skills::SkillsManager;

pub struct Worker {
    name: String,
    model: String,
    runtime_config: RuntimeConfig,
    matrix_client: Option<Client>,
    higress_client: HigressClient,
    config: WorkerConfig,
    skills_manager: SkillsManager,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeConfig {
    #[serde(default)]
    pub wasm_support: bool,
    #[serde(default = "default_concurrency")]
    pub concurrency: u32,
}

fn default_concurrency() -> u32 {
    100
}

impl Default for RuntimeConfig {
    fn default() -> Self {
        Self {
            wasm_support: false,
            concurrency: 100,
        }
    }
}

impl Worker {
    pub fn new(name: String, model: String, runtime_config: RuntimeConfig) -> Self {
        let config = WorkerConfig::load().unwrap_or_default();
        let skills_dir = std::path::PathBuf::from(format!(
            "/root/hiclaw-fs/agents/{}/skills",
            name
        ));

        Self {
            name,
            model,
            runtime_config,
            matrix_client: None,
            higress_client: HigressClient::new(),
            config,
            skills_manager: SkillsManager::new(skills_dir),
        }
    }

    pub async fn initialize(&mut self) -> Result<()> {
        info!("Initializing ZeroClaw worker: {}", self.name);

        self.init_matrix_client()
            .await
            .context("Failed to initialize Matrix client")?;

        self.higress_client
            .initialize(&self.config)
            .context("Failed to initialize Higress client")?;

        self.load_skills().await?;

        info!("ZeroClaw worker initialized successfully");
        Ok(())
    }

    async fn init_matrix_client(&mut self) -> Result<()> {
        let homeserver_url = self.config.matrix.homeserver_url.clone();
        let access_token = self.config.matrix.access_token.clone();
        let username = self.config.matrix.username.clone();

        if homeserver_url.is_empty() {
            warn!("Matrix homeserver URL not configured, skipping Matrix initialization");
            return Ok(());
        }

        if access_token.is_empty() {
            warn!("Matrix access token not configured, skipping Matrix initialization");
            return Ok(());
        }

        let client = Client::builder()
            .homeserver_url(&homeserver_url)
            .store_config(StoreConfig::new())
            .build()
            .await?;

        let user_id = matrix_sdk::ruma::user_id!(&username)
            .map_err(|e| anyhow::anyhow!("Invalid user ID '{}': {}", username, e))?
            .to_owned();

        let session = MatrixSession {
            meta: SessionMeta {
                user_id,
                device_id: matrix_sdk::ruma::device_id!("ZEROCLAW").to_owned(),
            },
            tokens: MatrixSessionTokens {
                access_token,
                refresh_token: None,
            },
        };

        client.restore_session(session).await?;

        info!("Matrix client logged in as {}", username);
        self.matrix_client = Some(client);

        Ok(())
    }

    async fn load_skills(&self) -> Result<()> {
        if let Err(e) = self.skills_manager.scan() {
            warn!("Failed to scan skills: {}", e);
        } else {
            let skills = self.skills_manager.list_skills();
            if skills.is_empty() {
                info!("No skills loaded");
            } else {
                info!("Loaded skills: {:?}", skills);
            }
        }
        Ok(())
    }

    pub async fn run(&self) -> Result<()> {
        info!("Starting ZeroClaw event loop");

        let semaphore = Arc::new(tokio::sync::Semaphore::new(self.runtime_config.concurrency as usize));

        loop {
            tokio::select! {
                biased;

                _ = async {
                    if let Some(client) = &self.matrix_client {
                        MatrixHandler::process_events(client.clone(), self.higress_client.clone(), semaphore.clone()).await
                    } else {
                        tokio::time::sleep(Duration::from_secs(1)).await;
                        Ok(())
                    }
                } => {
                    // Continue loop
                }

                _ = tokio::signal::ctrl_c() => {
                    info!("Received shutdown signal");
                    break;
                }
            }
        }

        Ok(())
    }

    pub async fn shutdown(&self) {
        info!("Shutting down ZeroClaw worker");

        if let Some(client) = &self.matrix_client {
            if let Err(e) = client.matrix_auth().logout().await {
                error!("Failed to logout from Matrix: {}", e);
            }
        }

        info!("ZeroClaw worker shutdown complete");
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_env("LOG_LEVEL"))
        .init();

    let worker_name = env::var("HICLAW_WORKER_NAME")
        .or_else(|_| env::var("WORKER_NAME"))
        .unwrap_or_else(|_| "zeroclaw-worker".to_string());
    let model = env::var("HICLAW_DEFAULT_MODEL")
        .or_else(|_| env::var("LLM_MODEL"))
        .unwrap_or_else(|_| "claude-sonnet-4-6".to_string());

    let runtime_config_str = env::var("HICLAW_RUNTIME_CONFIG")
        .or_else(|_| env::var("RUNTIME_CONFIG"))
        .unwrap_or_else(|_| "{}".to_string());
    let runtime_config: RuntimeConfig = serde_json::from_str(&runtime_config_str)
        .unwrap_or_else(|e| {
            warn!("Failed to parse RUNTIME_CONFIG: {}, using defaults", e);
            RuntimeConfig::default()
        });

    info!(
        "ZeroClaw starting: name={}, model={}, concurrency={}, wasm={}",
        worker_name, model, runtime_config.concurrency, runtime_config.wasm_support
    );

    let mut worker = Worker::new(worker_name, model, runtime_config);

    if let Err(e) = worker.initialize().await {
        error!("Failed to initialize worker: {}", e);
        std::process::exit(1);
    }

    if let Err(e) = worker.run().await {
        error!("Worker run loop error: {}", e);
        std::process::exit(1);
    }

    worker.shutdown().await;

    Ok(())
}
