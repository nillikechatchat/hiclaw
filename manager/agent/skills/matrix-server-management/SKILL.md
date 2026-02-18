---
name: matrix-server-management
description: Manage the Tuwunel Matrix Homeserver (register users, create rooms, manage room membership). Use when creating Matrix accounts for new workers or managing room structures.
---

# Matrix Server Management

## Overview

This skill allows you to manage the Tuwunel Matrix Homeserver. Tuwunel is a conduwuit fork running at `http://127.0.0.1:6167`. Access the server directly (not through the Higress gateway).

## User Registration

Tuwunel uses **single-step registration** with a registration token (no UIAA flow).

### Register a New User

```bash
curl -X POST http://127.0.0.1:6167/_matrix/client/v3/register \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "<USERNAME>",
    "password": "<PASSWORD>",
    "auth": {
      "type": "m.login.registration_token",
      "token": "'"${HICLAW_REGISTRATION_TOKEN}"'"
    }
  }'
```

Response includes `user_id` and `access_token`.

### Login (Get Access Token)

```bash
curl -X POST http://127.0.0.1:6167/_matrix/client/v3/login \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "m.login.password",
    "identifier": {"type": "m.id.user", "user": "<USERNAME>"},
    "password": "<PASSWORD>"
  }'
```

Response: `{"access_token": "...", "user_id": "@<USERNAME>:<DOMAIN>", ...}`

## Room Management

### Create a Room (3-party: Human + Manager + Worker)

When creating a Worker, always create a Room with the human admin, Manager, and Worker:

```bash
MANAGER_TOKEN="<manager_access_token>"
curl -X POST http://127.0.0.1:6167/_matrix/client/v3/createRoom \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Worker: <WORKER_NAME>",
    "topic": "Communication channel for <WORKER_NAME>",
    "invite": [
      "@'"${HICLAW_ADMIN_USER}"':'"${HICLAW_MATRIX_DOMAIN}"'",
      "@<WORKER_NAME>:'"${HICLAW_MATRIX_DOMAIN}"'"
    ],
    "preset": "trusted_private_chat"
  }'
```

Response: `{"room_id": "!<id>:<DOMAIN>"}`

### Send a Message in a Room

```bash
curl -X PUT "http://127.0.0.1:6167/_matrix/client/v3/rooms/<ROOM_ID>/send/m.room.message/$(date +%s)" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{
    "msgtype": "m.text",
    "body": "Hello, this is your task assignment..."
  }'
```

### List Joined Rooms

```bash
curl -s http://127.0.0.1:6167/_matrix/client/v3/joined_rooms \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" | jq
```

### Get Room Messages

```bash
curl -s "http://127.0.0.1:6167/_matrix/client/v3/rooms/<ROOM_ID>/messages?dir=b&limit=20" \
  -H "Authorization: Bearer ${MANAGER_TOKEN}" | jq
```

## Important Notes

- **Environment prefix**: Tuwunel uses `CONDUWUIT_` environment variable prefix (NOT `TUWUNEL_`)
- **Server name**: Set in `CONDUWUIT_SERVER_NAME`, usually `${HICLAW_MATRIX_DOMAIN}`
- **User ID format**: `@<username>:${HICLAW_MATRIX_DOMAIN}`
- **Registration token**: Stored in `HICLAW_REGISTRATION_TOKEN` env var
- **Direct access**: Use `http://127.0.0.1:6167` for server management (not through Higress Gateway port 8080)
