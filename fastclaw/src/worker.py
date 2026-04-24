"""
fastclaw - Lightweight Python AI Agent Worker for HiClaw

A minimal, Python-based AI Agent runtime designed for:
- Fast prototyping and development
- Python ecosystem integration
- Lightweight resource footprint (~300MB memory)
- Matrix protocol communication
- MinIO file synchronization
- Higress gateway integration
"""

import asyncio
import json
import os
import sys
import logging
from pathlib import Path
from typing import Optional, Dict, Any
import traceback

# Setup logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("fastclaw")

# Configuration paths
WORKSPACE_DIR = Path(os.getenv("HOME", "/root/fastclaw-workspace"))
MINIO_FS_DIR = Path(os.getenv("MINIO_FS_DIR", "/root/hiclaw-fs"))
AGENTS_DIR = MINIO_FS_DIR / "agents"

class FastClawWorker:
    """Lightweight Python AI Agent Worker implementation."""
    
    def __init__(self, name: str, model: str, runtime_config: Optional[Dict[str, Any]] = None):
        self.name = name
        self.model = model
        self.runtime_config = runtime_config or {}
        
        # fastclaw-specific config
        self.python_version = self.runtime_config.get("fastclaw", {}).get("pythonVersion", "3.11")
        self.sdk = self.runtime_config.get("fastclaw", {}).get("sdk", "claude")
        
        self.agent_dir = AGENTS_DIR / name
        self.skills_dir = self.agent_dir / "skills"
        self.config_file = self.agent_dir / "fastclaw.json"
        
        logger.info(f"Initialized fastclaw worker: {name}, model: {model}, sdk: {self.sdk}")
    
    async def initialize(self) -> bool:
        """Initialize the worker: load config, skills, and establish connections."""
        try:
            # Ensure agent directory exists
            self.agent_dir.mkdir(parents=True, exist_ok=True)
            self.skills_dir.mkdir(parents=True, exist_ok=True)
            
            # Load configuration
            config = await self.load_config()
            if config:
                logger.info("Configuration loaded successfully")
            
            # Load skills
            skills = await self.load_skills()
            logger.info(f"Loaded {len(skills)} skills")
            
            # Initialize Matrix client (placeholder - would use matrix-nio or similar)
            await self.init_matrix_client()
            
            # Initialize Higress gateway connection (placeholder)
            await self.init_higress_client()
            
            logger.info("Worker initialization complete")
            return True
            
        except Exception as e:
            logger.error(f"Initialization failed: {e}")
            traceback.print_exc()
            return False
    
    async def load_config(self) -> Optional[Dict[str, Any]]:
        """Load worker configuration from fastclaw.json."""
        if self.config_file.exists():
            with open(self.config_file, "r") as f:
                return json.load(f)
        logger.warning(f"Config file not found: {self.config_file}")
        return None
    
    async def load_skills(self) -> list:
        """Load skills from the skills directory."""
        skills = []
        if self.skills_dir.exists():
            for skill_dir in self.skills_dir.iterdir():
                if skill_dir.is_dir():
                    skill_file = skill_dir / "SKILL.md"
                    if skill_file.exists():
                        skills.append(skill_dir.name)
                        # In production, would parse and load the skill
        return skills
    
    async def init_matrix_client(self):
        """Initialize Matrix client for communication."""
        # Placeholder: In production, would initialize matrix-nio client
        # with credentials from openclaw.json
        logger.info("Matrix client initialized (placeholder)")
    
    async def init_higress_client(self):
        """Initialize Higress gateway client for LLM and MCP access."""
        # Placeholder: In production, would setup HTTP client with
        # Consumer token for Higress authentication
        logger.info("Higress client initialized (placeholder)")
    
    async def run(self):
        """Main event loop for the worker."""
        logger.info("Starting worker event loop")
        
        try:
            # In production, this would:
            # 1. Listen for Matrix messages
            # 2. Process incoming tasks
            # 3. Call LLM via Higress
            # 4. Execute skills
            # 5. Report results back to Matrix
            
            # Keep the worker running
            while True:
                await asyncio.sleep(1)
                
        except asyncio.CancelledError:
            logger.info("Worker event loop cancelled")
        except Exception as e:
            logger.error(f"Worker event loop error: {e}")
            traceback.print_exc()
            raise
    
    async def shutdown(self):
        """Gracefully shutdown the worker."""
        logger.info("Shutting down worker")
        # Cleanup resources, close connections, etc.

async def main():
    """Main entry point."""
    # Parse environment variables
    worker_name = os.getenv("WORKER_NAME", "fastclaw-worker")
    model = os.getenv("LLM_MODEL", "claude-sonnet-4-6")
    
    # Parse runtime config from environment (passed by hiclaw-controller)
    runtime_config_str = os.getenv("RUNTIME_CONFIG", "{}")
    try:
        runtime_config = json.loads(runtime_config_str)
    except json.JSONDecodeError:
        logger.warning("Invalid RUNTIME_CONFIG, using empty config")
        runtime_config = {}
    
    # Create and initialize worker
    worker = FastClawWorker(
        name=worker_name,
        model=model,
        runtime_config=runtime_config
    )
    
    if not await worker.initialize():
        logger.error("Failed to initialize worker, exiting")
        sys.exit(1)
    
    # Run the worker
    try:
        await worker.run()
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        await worker.shutdown()

if __name__ == "__main__":
    asyncio.run(main())
