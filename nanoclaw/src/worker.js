/**
 * NanoClaw - Minimal Node.js AI Agent Worker
 * 
 * An ultra-lightweight (~500 lines of code) AI agent designed for:
 * - Personal assistant use cases
 * - Resource-constrained environments
 * - Containerized secure execution
 * - Matrix protocol communication
 */

import { createClient } from 'matrix-js-sdk';
import axios from 'axios';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs/promises';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const WORKER_NAME = process.env.WORKER_NAME || 'nanoclaw-worker';
const LLM_MODEL = process.env.LLM_MODEL || 'claude-sonnet-4-6';
const RUNTIME_CONFIG = JSON.parse(process.env.RUNTIME_CONFIG || '{}');
const MINIO_FS_DIR = process.env.MINIO_FS_DIR || '/root/hiclaw-fs';
const AGENT_DIR = join(MINIO_FS_DIR, 'agents', WORKER_NAME);

// Runtime config defaults
const CONTAINER_TIMEOUT = RUNTIME_CONFIG.nanoclaw?.containerTimeout || 300; // 5 minutes
const CHANNEL = RUNTIME_CONFIG.nanoclaw?.channel || 'matrix';

/**
 * NanoClaw Worker class
 */
class NanoClawWorker {
  constructor(name, model, config) {
    this.name = name;
    this.model = model;
    this.config = config;
    this.matrixClient = null;
    this.higressClient = null;
    this.skills = new Map();
  }

  /**
   * Initialize the worker
   */
  async initialize() {
    console.log(`[NanoClaw] Initializing worker: ${this.name}`);
    
    try {
      // Ensure agent directory exists
      await fs.mkdir(AGENT_DIR, { recursive: true });
      await fs.mkdir(join(AGENT_DIR, 'skills'), { recursive: true });
      
      // Load configuration
      await this.loadConfig();
      
      // Load skills
      await this.loadSkills();
      
      // Initialize Matrix client
      await this.initMatrixClient();
      
      // Initialize Higress client
      await this.initHigressClient();
      
      console.log(`[NanoClaw] Worker initialized successfully`);
      return true;
    } catch (error) {
      console.error(`[NanoClaw] Initialization failed:`, error);
      return false;
    }
  }

  /**
   * Load worker configuration
   */
  async loadConfig() {
    const configPath = join(AGENT_DIR, 'openclaw.json');
    try {
      const configStr = await fs.readFile(configPath, 'utf-8');
      this.config = JSON.parse(configStr);
      console.log(`[NanoClaw] Configuration loaded from ${configPath}`);
    } catch (error) {
      console.warn(`[NanoClaw] Config file not found, using defaults`);
      this.config = {};
    }
  }

  /**
   * Load skills from skills directory
   */
  async loadSkills() {
    const skillsDir = join(AGENT_DIR, 'skills');
    try {
      const skills = await fs.readdir(skillsDir);
      for (const skill of skills) {
        const skillPath = join(skillsDir, skill);
        const stat = await fs.stat(skillPath);
        if (stat.isDirectory()) {
          this.skills.set(skill, { name: skill, path: skillPath });
          console.log(`[NanoClaw] Loaded skill: ${skill}`);
        }
      }
      console.log(`[NanoClaw] Loaded ${this.skills.size} skills`);
    } catch (error) {
      console.warn(`[NanoClaw] Failed to load skills:`, error.message);
    }
  }

  /**
   * Initialize Matrix client
   */
  async initMatrixClient() {
    const homeserverUrl = this.config.homeserverUrl || process.env.MATRIX_HOMESERVER_URL;
    const accessToken = this.config.accessToken || process.env.MATRIX_ACCESS_TOKEN;
    const userId = this.config.userId || `@${this.name}:hiclaw.io`;

    if (!homeserverUrl || !accessToken) {
      console.warn(`[NanoClaw] Matrix credentials not configured, skipping`);
      return;
    }

    this.matrixClient = createClient({
      baseUrl: homeserverUrl,
      accessToken: accessToken,
      userId: userId,
    });

    console.log(`[NanoClaw] Matrix client initialized for ${userId}`);
  }

  /**
   * Initialize Higress client
   */
  initHigressClient() {
    const baseUrl = process.env.HIGRESS_URL || 'http://127.0.0.1:8080';
    const token = process.env.HIGRESS_TOKEN;

    this.higressClient = axios.create({
      baseURL: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` }),
      },
    });

    console.log(`[NanoClaw] Higress client initialized: ${baseUrl}`);
  }

  /**
   * Process incoming message
   */
  async processMessage(roomId, message, sender) {
    console.log(`[NanoClaw] Processing message from ${sender} in ${roomId}`);
    
    try {
      // Call LLM via Higress
      const response = await this.higressClient.post('/v1/chat/completions', {
        model: this.model,
        messages: [
          { role: 'user', content: message },
        ],
      });

      const reply = response.data.choices[0].message.content;

      // Send response
      if (this.matrixClient) {
        await this.matrixClient.sendTextMessage(roomId, reply);
      }

      console.log(`[NanoClaw] Message processed successfully`);
    } catch (error) {
      console.error(`[NanoClaw] Failed to process message:`, error.message);
    }
  }

  /**
   * Run the worker
   */
  async run() {
    console.log(`[NanoClaw] Starting event loop (timeout: ${CONTAINER_TIMEOUT}s)`);

    // Set up container timeout
    const timeoutId = setTimeout(() => {
      console.log(`[NanoClaw] Container timeout reached, shutting down`);
      process.exit(0);
    }, CONTAINER_TIMEOUT * 1000);

    // Keep alive
    const keepAlive = setInterval(() => {
      console.log(`[NanoClaw] Heartbeat - uptime: ${process.uptime()}s`);
    }, 30000);

    // Handle graceful shutdown
    process.on('SIGINT', () => this.shutdown(keepAlive, timeoutId));
    process.on('SIGTERM', () => this.shutdown(keepAlive, timeoutId));

    // Note: In production, would listen for Matrix events here
  }

  /**
   * Gracefully shutdown
   */
  async shutdown(keepAlive, timeoutId) {
    console.log(`[NanoClaw] Shutting down...`);
    
    clearInterval(keepAlive);
    clearTimeout(timeoutId);

    if (this.matrixClient) {
      await this.matrixClient.stopClient();
    }

    process.exit(0);
  }
}

// Main entry point
async function main() {
  const worker = new NanoClawWorker(WORKER_NAME, LLM_MODEL, RUNTIME_CONFIG);
  
  const initialized = await worker.initialize();
  if (!initialized) {
    console.error('[NanoClaw] Failed to initialize, exiting');
    process.exit(1);
  }

  await worker.run();
}

main().catch(console.error);
