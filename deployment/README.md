# Aqura deployment (development phase: local server only)

This tracked folder deploys the Aqura frontend to the local development server `192.168.0.156` (app at `http://localhost/` on that server) from an authorized Windows computer. Cloud production deployment (`8.213.42.21` / `https://urbanaqura.com/`) is disabled until development is finished; the script refuses cloud hosts.

## Deploy

Commit the intended changes on `master`, then run from the repository root:

```powershell
.\deployment\push-and-deploy.cmd
```

The process increments Desktop, Mobile, Cashier, and Customer version numbers together, commits the version, builds locally from `frontend/.env` (local Supabase values), pushes `master` to the configured `origin` (`Aqura-new`), uploads the release to `192.168.0.156`, switches the active release, and performs a health check of `http://localhost/` on that server. A failed health check restores the previous release automatically. After success, the server keeps the newest three releases and removes older release directories, stale incoming deployment files, and its dedicated temporary npm cache.

## Test only

```powershell
.\deployment\push-and-deploy.cmd -DryRun
```

This reports the next version and performs the production build and packaging checks without changing the version, creating a commit, pushing to GitHub, or contacting the deployment server.

## Requirements

- Windows PowerShell, Git, Node.js 20, pnpm, `tar`, `ssh`, and `scp`
- A clean `master` working tree
- GitHub push access for the configured `origin`
- The authorized private key at `~/.ssh/id_ed25519_nopass` or `~/.ssh/id_ed25519` (or pass `-IdentityFile`)
- Network access to the local server `192.168.0.156` (root key login; Node 20 at `/opt/node20`, `aqura-web` service, Nginx)
- `frontend/.env` pointing `VITE_SUPABASE_URL` at the local server (the script refuses a cloud URL)

The private key and environment variables are deliberately not stored in this repository.

SSH access is checked before changing the version or building. Git enforces LF line endings for deployment shell scripts so they run correctly on Linux after a Windows checkout.

## Files

- `AGENTS.md`: mandatory instructions for AI agents and humans
- `push-and-deploy.cmd`: recommended Windows entry point
- `push-and-deploy.ps1`: build, package, push, and upload orchestration
- `bump-version.mjs`: validates and increments all interface versions together
- `activate-release.sh`: atomic server activation, health check, and rollback
- `websocket-polyfill.mjs`: Node 20 runtime compatibility required by the frontend
- `urbanaqura.com.http.conf`: production (cloud) Nginx bootstrap proxy, kept for reference; not used during development
- `aqura-web-origin.conf`: production (cloud) systemd origin override, kept for reference; not used during development
