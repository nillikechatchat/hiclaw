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
import re
import sys
import logging
import traceback
from pathlib import Path
from typing import Optional, Dict, Any, List

import aiohttp
from nio import (
    AsyncClient,
    AsyncClientConfig,
    MatrixRoom,
    RoomMessageText,
    SyncResponse,
)
from nio.responses import WhoamiResponse

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("fastclaw")

MINIO_FS_DIR = Path(os.getenv("MINIO_FS_DIR", "/root/hiclaw-fs"))
AGENTS_DIR = MINIO_FS_DIR / "agents"


def _env(name: str, fallback: str = "", *, alt: str = "") -> str:
    return os.getenv(name) or os.getenv(alt) or fallback


class FastClawWorker:
    """Lightweight Python AI Agent Worker implementation."""

    def __init__(self, name: str, model: str, runtime_config: Optional[Dict[str, Any]] = None):
        self.name = name
        self.model = model
        self.runtime_config = runtime_config or {}

        self.python_version = self.runtime_config.get("fastclaw", {}).get("pythonVersion", "3.11")
        self.sdk = self.runtime_config.get("fastclaw", {}).get("sdk", "openai")

        self.agent_dir = AGENTS_DIR / name
        self.skills_dir = self.agent_dir / "skills"
        self.config_file = self.agent_dir / "fastclaw.json"

        self._matrix_client: Optional[AsyncClient] = None
        self._matrix_user_id: Optional[str] = None
        self._http_session: Optional[aiohttp.ClientSession] = None
        self._sync_task: Optional[asyncio.Task] = None
        self._conversation_contexts: Dict[str, List[Dict[str, str]]] = {}

        self.matrix_url = _env("HICLAW_MATRIX_URL", alt="HICLAW_MATRIX_SERVER")
        self.matrix_token = _env("HICLAW_WORKER_MATRIX_TOKEN", alt="HICLAW_MATRIX_TOKEN")
        self.gateway_url = _env("HICLAW_AI_GATEWAY_URL")
        self.gateway_key = _env("HICLAW_WORKER_GATEWAY_KEY", alt="HICLAW_GATEWAY_KEY")

        logger.info(f"Initialized fastclaw worker: {name}, model: {model}, sdk: {self.sdk}")

    async def initialize(self) -> bool:
        try:
            self.agent_dir.mkdir(parents=True, exist_ok=True)
            self.skills_dir.mkdir(parents=True, exist_ok=True)

            config = await self.load_config()
            if config:
                logger.info("Configuration loaded successfully")
                self._apply_config(config)

            skills = await self.load_skills()
            logger.info(f"Loaded {len(skills)} skills")

            if not await self.init_matrix_client():
                return False

            await self.init_higress_client()

            logger.info("Worker initialization complete")
            return True

        except Exception as e:
            logger.error(f"Initialization failed: {e}")
            traceback.print_exc()
            return False

    def _apply_config(self, config: Dict[str, Any]) -> None:
        if "model" in config and config["model"]:
            self.model = config["model"]
        if "matrixUrl" in config and config["matrixUrl"]:
            self.matrix_url = config["matrixUrl"]
        if "matrixToken" in config and config["matrixToken"]:
            self.matrix_token = config["matrixToken"]
        if "gatewayUrl" in config and config["gatewayUrl"]:
            self.gateway_url = config["gatewayUrl"]
        if "gatewayKey" in config and config["gatewayKey"]:
            self.gateway_key = config["gatewayKey"]
        if "systemPrompt" in config:
            self.runtime_config.setdefault("systemPrompt", config["systemPrompt"])

    async def load_config(self) -> Optional[Dict[str, Any]]:
        if self.config_file.exists():
            with open(self.config_file, "r") as f:
                return json.load(f)
        logger.warning(f"Config file not found: {self.config_file}")
        return None

    async def load_skills(self) -> list:
        skills = []
        if self.skills_dir.exists():
            for skill_dir in self.skills_dir.iterdir():
                if skill_dir.is_dir():
                    skill_file = skill_dir / "SKILL.md"
                    if skill_file.exists():
                        skills.append(skill_dir.name)
        return skills

    async def init_matrix_client(self) -> bool:
        if not self.matrix_url:
            logger.error("HICLAW_MATRIX_URL is not set")
            return False
        if not self.matrix_token:
            logger.error("HICLAW_WORKER_MATRIX_TOKEN is not set")
            return False

        try:
            client_config = AsyncClientConfig(
                store_sync_tokens=False,
                encryption_enabled=False,
            )
            self._matrix_client = AsyncClient(
                self.matrix_url,
                user="",
                config=client_config,
            )
            self._matrix_client.access_token = self.matrix_token

            whoami = await self._matrix_client.whoami()
            if isinstance(whoami, WhoamiResponse):
                self._matrix_user_id = whoami.user_id
                self._matrix_client.user_id = whoami.user_id
                self._matrix_client.user = whoami.user_id
                if whoami.device_id:
                    self._matrix_client.device_id = whoami.device_id
                logger.info(
                    f"Matrix client logged in as {self._matrix_user_id} "
                    f"(device: {whoami.device_id})"
                )
            else:
                logger.error(f"Matrix token login failed: {whoami}")
                return False

            self._matrix_client.add_event_callback(
                self._on_room_message, (RoomMessageText,)
            )

            self._sync_task = asyncio.create_task(self._matrix_sync_loop())
            logger.info("Matrix sync loop started")

            return True

        except Exception as e:
            logger.error(f"Matrix client initialization failed: {e}")
            traceback.print_exc()
            return False

    async def _matrix_sync_loop(self) -> None:
        next_batch = None

        try:
            logger.info("Performing initial Matrix sync (suppressing callbacks)...")
            saved_cbs = self._matrix_client.event_callbacks[:]
            self._matrix_client.event_callbacks.clear()
            try:
                resp = await self._matrix_client.sync(timeout=30000, full_state=True)
            finally:
                self._matrix_client.event_callbacks.extend(saved_cbs)

            if isinstance(resp, SyncResponse):
                next_batch = resp.next_batch
                for room_id in resp.rooms.invite:
                    logger.info(f"Auto-joining room: {room_id}")
                    await self._matrix_client.join(room_id)
                logger.info("Initial sync complete, will process messages from next sync")
            else:
                logger.warning(f"Initial sync error: {resp}")
        except Exception as e:
            logger.error(f"Initial sync exception: {e}")

        while True:
            try:
                resp = await self._matrix_client.sync(
                    timeout=30000,
                    since=next_batch,
                    full_state=False,
                )
                if isinstance(resp, SyncResponse):
                    next_batch = resp.next_batch
                    for room_id in resp.rooms.invite:
                        logger.info(f"Auto-joining room: {room_id}")
                        await self._matrix_client.join(room_id)
                else:
                    logger.warning(f"Sync error: {resp}")
                    await asyncio.sleep(5)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Sync exception: {e}")
                await asyncio.sleep(5)

    async def _on_room_message(self, room: MatrixRoom, event: RoomMessageText) -> None:
        if event.sender == self._matrix_user_id:
            return

        text = event.body or ""
        room_id = room.room_id
        is_dm = len(room.users) == 2

        if not is_dm and not self._was_mentioned(event, text):
            return

        await self._send_read_receipt(room_id, event.event_id)
        await self._send_typing(room_id, True)

        message_text = self._strip_mention(text, room)

        logger.info(f"Processing message from {event.sender} in {room_id}: {message_text[:100]}")

        try:
            response_text = await self.call_llm(room_id, message_text)
            if response_text:
                await self._send_matrix_message(room_id, response_text)
            else:
                await self._send_matrix_message(room_id, "Sorry, I could not generate a response.")
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            traceback.print_exc()
            await self._send_matrix_message(room_id, f"Error: {str(e)[:200]}")
        finally:
            await self._send_typing(room_id, False)

    def _was_mentioned(self, event: Any, text: str) -> bool:
        if not self._matrix_user_id:
            return False

        content = event.source.get("content", {})
        mentions = content.get("m.mentions", {})
        if self._matrix_user_id in mentions.get("user_ids", []):
            return True
        if mentions.get("room"):
            return True

        formatted_body = content.get("formatted_body", "")
        if formatted_body and self._matrix_user_id:
            escaped_uid = re.escape(self._matrix_user_id)
            if re.search(
                rf'href=["\']https://matrix\.to/#/{escaped_uid}["\']',
                formatted_body,
                re.IGNORECASE,
            ):
                return True

        if self._matrix_user_id and re.search(
            re.escape(self._matrix_user_id), text, re.IGNORECASE
        ):
            return True

        return False

    def _strip_mention(self, text: str, room: MatrixRoom = None) -> str:
        if not self._matrix_user_id:
            return text

        escaped = re.escape(self._matrix_user_id)
        result = re.sub(rf"^{escaped}\s*:?\s*", "", text, flags=re.IGNORECASE)
        if result != text:
            return result.strip()

        if room and self._matrix_user_id:
            display_name = self._get_display_name(room, self._matrix_user_id)
            if display_name and display_name != self._matrix_user_id:
                result = re.sub(
                    rf"^{re.escape(display_name)}\s*:?\s*",
                    "",
                    text,
                    flags=re.IGNORECASE,
                )
                if result != text:
                    result = re.sub(r"^[^\w/]+", "", result)
                    return result.strip()

        localpart = self._matrix_user_id.split(":")[0].lstrip("@")
        if localpart:
            result = re.sub(
                rf"^{re.escape(localpart)}\s*:?\s*",
                "",
                text,
                flags=re.IGNORECASE,
            )
            if result != text:
                result = re.sub(r"^[^\w/]+", "", result)
                return result.strip()

        return text

    def _get_display_name(self, room: MatrixRoom, user_id: str) -> str:
        try:
            name = room.user_name(user_id)
            if name:
                return name
        except Exception:
            pass
        return user_id.split(":")[0].lstrip("@") or user_id

    async def _send_matrix_message(self, room_id: str, text: str) -> None:
        if not self._matrix_client:
            return
        try:
            await self._matrix_client.room_send(
                room_id=room_id,
                message_type="m.room.message",
                content={
                    "msgtype": "m.text",
                    "body": text,
                },
            )
            logger.debug(f"Sent message to {room_id}")
        except Exception as e:
            logger.error(f"Failed to send message to {room_id}: {e}")

    async def _send_read_receipt(self, room_id: str, event_id: str) -> None:
        if not self._matrix_client:
            return
        try:
            await self._matrix_client.room_read_markers(
                room_id=room_id,
                fully_read_event_id=event_id,
                read_event_id=event_id,
            )
        except Exception as e:
            logger.debug(f"Failed to send read receipt: {e}")

    async def _send_typing(self, room_id: str, typing: bool) -> None:
        if not self._matrix_client:
            return
        try:
            await self._matrix_client.room_typing(room_id, typing_state=typing)
        except Exception as e:
            logger.debug(f"Failed to send typing notification: {e}")

    async def init_higress_client(self) -> None:
        self._http_session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=120),
        )
        if self.gateway_url:
            logger.info(f"Higress client ready: {self.gateway_url}")
        else:
            logger.warning("HICLAW_AI_GATEWAY_URL is not set; LLM calls will fail")

    async def call_llm(self, room_id: str, user_message: str) -> Optional[str]:
        if not self.gateway_url or not self.gateway_key:
            logger.error("Gateway URL or key not configured")
            return None
        if not self._http_session:
            logger.error("HTTP session not initialized")
            return None

        context = self._conversation_contexts.setdefault(room_id, [])

        system_prompt = self.runtime_config.get(
            "systemPrompt",
            f"You are {self.name}, a helpful AI worker agent in the HiClaw system.",
        )

        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(context[-10:])
        messages.append({"role": "user", "content": user_message})

        url = f"{self.gateway_url}/v1/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "x-higress-consumer-name": self.name,
            "Authorization": f"Bearer {self.gateway_key}",
        }
        payload = {
            "model": self.model,
            "messages": messages,
            "max_tokens": 4096,
        }

        try:
            async with self._http_session.post(url, headers=headers, json=payload) as resp:
                if resp.status != 200:
                    body = await resp.text()
                    logger.error(f"LLM call failed (HTTP {resp.status}): {body[:500]}")
                    return None

                data = await resp.json()
                content = (
                    data.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )

                if content:
                    context.append({"role": "user", "content": user_message})
                    context.append({"role": "assistant", "content": content})
                    if len(context) > 20:
                        self._conversation_contexts[room_id] = context[-20:]

                return content or None

        except Exception as e:
            logger.error(f"LLM call exception: {e}")
            traceback.print_exc()
            return None

    async def run(self) -> None:
        logger.info("Starting worker event loop")

        try:
            while True:
                await asyncio.sleep(60)
        except asyncio.CancelledError:
            logger.info("Worker event loop cancelled")
        except Exception as e:
            logger.error(f"Worker event loop error: {e}")
            traceback.print_exc()
            raise

    async def shutdown(self) -> None:
        logger.info("Shutting down worker")

        if self._sync_task:
            self._sync_task.cancel()
            try:
                await self._sync_task
            except asyncio.CancelledError:
                pass

        if self._matrix_client:
            try:
                await self._matrix_client.close()
            except Exception:
                pass

        if self._http_session:
            try:
                await self._http_session.close()
            except Exception:
                pass

        logger.info("Worker shutdown complete")


async def main():
    worker_name = _env("HICLAW_WORKER_NAME", "fastclaw-worker", alt="WORKER_NAME")
    model = _env("HICLAW_DEFAULT_MODEL", "claude-sonnet-4-6", alt="LLM_MODEL")

    runtime_config_str = _env("HICLAW_RUNTIME_CONFIG", "{}", alt="RUNTIME_CONFIG")
    try:
        runtime_config = json.loads(runtime_config_str)
    except json.JSONDecodeError:
        logger.warning("Invalid RUNTIME_CONFIG, using empty config")
        runtime_config = {}

    worker = FastClawWorker(
        name=worker_name,
        model=model,
        runtime_config=runtime_config,
    )

    if not await worker.initialize():
        logger.error("Failed to initialize worker, exiting")
        sys.exit(1)

    try:
        await worker.run()
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        await worker.shutdown()


if __name__ == "__main__":
    asyncio.run(main())
