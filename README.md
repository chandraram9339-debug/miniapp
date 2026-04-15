# Telegram Mini App Scaffold

This repository is a bootstrap for a Telegram Mini App project.

## Structure

- `frontend` - client app (React + Vite + TypeScript)
- `backend` - API service (Node.js + Express + TypeScript)
- `docker-compose.yml` - local Postgres and Redis

## Quick start

1. Install dependencies:
   - `cd backend && pnpm install`
   - `cd ../frontend && pnpm install`
2. Start infrastructure:
   - `docker compose up -d`
3. Run backend:
   - `cd backend && pnpm dev`
4. Run frontend:
   - `cd frontend && pnpm dev`

## Runtime preflight gate

- Runner preflight: `scripts/runner06-preflight.sh`
- CI preflight: `scripts/ci-preflight-gate.sh`

Both paths use the same deterministic gate and emit:
- `runner_id`
- `profile_id`
- `env_source`
- `dsn_redacted`

## Merge enforcement checks

- Required check 1: `preflight` (runtime preflight gate)
- Required check 2: `metadata-schema-validation` (runtime metadata schema gate)

S2 enforcement evidence PR
