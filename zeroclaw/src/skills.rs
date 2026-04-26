//! Skills management module

use anyhow::Result;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use tracing::{info, warn};

/// Represents a single skill
#[derive(Debug, Clone)]
pub struct Skill {
    /// Skill name (directory name)
    pub name: String,
    /// Absolute path to the skill directory
    pub path: PathBuf,
}

/// Manages discovery and access of skills from a directory
pub struct SkillsManager {
    skills: Mutex<HashMap<String, Skill>>,
    skills_dir: PathBuf,
}

impl SkillsManager {
    /// Create a new SkillsManager pointing at the given directory
    pub fn new(skills_dir: PathBuf) -> Self {
        Self {
            skills: Mutex::new(HashMap::new()),
            skills_dir,
        }
    }

    /// Scan the skills directory and load all skill subdirectories
    pub fn scan(&self) -> Result<()> {
        let mut skills = self.skills.lock().unwrap();
        skills.clear();

        if !self.skills_dir.exists() {
            warn!("Skills directory does not exist: {:?}", self.skills_dir);
            return Ok(());
        }

        let entries = fs::read_dir(&self.skills_dir)?;
        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            let name = path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            if name.starts_with('.') {
                continue;
            }
            info!("Found skill: {}", name);
            skills.insert(
                name.clone(),
                Skill { name, path },
            );
        }

        info!("Loaded {} skill(s) from {:?}", skills.len(), self.skills_dir);
        Ok(())
    }

    /// List all loaded skill names
    pub fn list_skills(&self) -> Vec<String> {
        self.skills.lock().unwrap().keys().cloned().collect()
    }

    /// Get a skill by name
    pub fn get_skill(&self, name: &str) -> Option<Skill> {
        self.skills.lock().unwrap().get(name).cloned()
    }

    /// Get the skills directory path
    pub fn skills_dir(&self) -> &Path {
        &self.skills_dir
    }
}
