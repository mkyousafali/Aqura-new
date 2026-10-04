# Aqura deployment instructions (development phase)

These instructions apply to every human or AI agent working in this folder.

## Development phase: local server only

Until development is finished, deployment targets ONLY the local development server `192.168.0.156`.

- Never deploy to, write to, or change the cloud production server (`8.213.42.21`, `urbanaqura.com`, `supabase.urbanaqura.com`). It is reference-only: read from it only when asked.
- `push-and-deploy.ps1` refuses cloud hosts and refuses to build while `frontend/.env` points at the cloud Supabase.
- Database changes are made only on the local server's Supabase, and each change is saved as a SQL file in `database/migrations/` so it can be applied to production after development.

## Standard deployment

From the repository root, run:

```powershell
.\deployment\push-and-deploy.cmd
```

The command verifies that the current branch is `master` and that the working tree is clean, increments all four interface version numbers, commits that version, builds the frontend locally with `frontend/.env` (local Supabase values), pushes the commit to `origin` (`https://github.com/mkyousafali/Aqura-new`), uploads an isolated release to the local server through SSH, activates it atomically, tests `http://localhost/` on that server, and rolls back if the health check fails. After a healthy deployment, it retains the newest three releases and deletes older deployment files safely.

Do not manually copy frontend files, upload `.env` files, edit Nginx, or restart unrelated services during a routine deployment.

## Before reporting success

Confirm all of the following:

1. All intended changes are committed.
2. The command completed without an error.
3. The version-bump commit was pushed successfully.
4. The deployment script reported a healthy endpoint (`http://localhost/` on the local server).

## Safe validation without deployment

Run this to build and package locally without pushing or changing the server:

```powershell
.\deployment\push-and-deploy.cmd -DryRun
```

## Secrets and access

This folder contains no private credentials and must be committed to Git. The private SSH key remains outside the repository at `~/.ssh/id_ed25519_nopass` or `~/.ssh/id_ed25519`; an explicit `-IdentityFile` overrides this selection. SSH access is checked before the version bump and build. The local server's runtime secrets remain on the server at `/opt/aqura-web/shared/.env`. The cloud frontend values are backed up outside Git at `test sr/cloud-frontend/.env` for the eventual production deployment.

Keep deployment shell scripts LF-only as enforced by `.gitattributes` so Windows checkouts can upload them directly to Linux.

The version source is `frontend/src/lib/appVersion.ts`. Never edit separate interface version strings; all interfaces must import their value from that file. A dry run reports the current and next version but does not change or commit it.

Never commit or upload a private SSH key, service-role key, database password, private VAPID key, or `.env` file.
