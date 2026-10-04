# Database migrations (development phase)

This folder holds ONLY database changes made during development on the local server
(`192.168.0.156`), starting 2026-10-04. Everything that existed before that date is already
applied on both the cloud and the local server; older files were removed and remain in Git
history (last commit containing them: `d1cd9751`).

Rules:

- One file per change: `YYYYMMDD_short_description.sql`, wrapped in `begin; ... commit;`.
- Apply to the local server only, then commit the file with the code that needs it.
- Never edit a file after it has been applied; add a new migration instead.
- At the end of development, every file in this folder is applied to production in
  filename order (after a production backup).

Full workflow: `Do not delete/AQURA_DEVELOPMENT_GUIDE.md` (sections 5 and 6).
