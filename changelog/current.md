# Changelog (Unreleased)

Record image-affecting changes to `manager/`, `worker/`, `openclaw-base/` here before the next release.

---

- feat(fastclaw): implement real Matrix client (matrix-nio) and Higress LLM client, add mc installation to Dockerfile, unify env vars to HICLAW_* naming convention
- feat(zeroclaw): add missing skills.rs module to fix compilation, add env var fallbacks (HICLAW_* with legacy WORKER_NAME/LLM_MODEL fallbacks), switch Dockerfile from scratch to alpine for mc support
- feat(nanoclaw): add package.json for Docker build, remove self-destruct container timeout, unify env vars to HICLAW_* naming, add mc to Dockerfile, try nanoclaw.json before openclaw.json
- feat(manager): extend create-worker.sh to support fastclaw/zeroclaw/nanoclaw runtimes with proper container creation, readiness checks, SAE image selection, and agent template resolution
- feat(manager): extend container-api.sh with container_create_fastclaw_worker, container_create_zeroclaw_worker, container_create_nanoclaw_worker, and container_wait_generic_worker_ready functions
- feat(manager): add fastclaw-worker-agent, zeroclaw-worker-agent, nanoclaw-worker-agent template directories with AGENTS.md and builtin skills
- feat(manager): extend lifecycle-worker.sh with runtime-aware readiness checks and container creation helpers
- feat(manager): extend upgrade-builtins.sh to publish builtins for all 5 worker runtimes
- feat(install): extend hiclaw-install.sh with fastclaw/zeroclaw/nanoclaw runtime options, image resolution, and SAE cloud support

