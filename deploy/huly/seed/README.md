# Huly Pilot Seed

This directory contains tracked placeholder content for the Phase 3 Huly pilot.
It is intended to be copied or imported into a test Huly workspace after the
Huly service, authentication boundary, and initial admin account are ready.

The seed bundle is deliberately non-sensitive:

- no credentials, tokens, webhook secrets, private keys, or generated passwords
- no real names, email addresses, repository URLs, datasets, papers, or meeting notes
- no private research data or unpublished results
- only sample roles, sample issue bodies, and pilot-relative date placeholders

## Files

- `workspace.seed.yaml`: canonical seed manifest for channels, projects, docs, issues, and pilot checks
- `docs/lab-handbook.md`: sample lab handbook page
- `docs/meeting-notes.md`: sample recurring meeting notes page
- `issues/experiment-task.md`: sample experiment lifecycle issue
- `issues/paper-milestone.md`: sample paper milestone issue
- `issues/github-sync-issue.md`: sample GitHub sync validation issue
- `checklists/onboarding-checklist.md`: sample onboarding checklist
- `../notion-sample/scrub-import-checklist.md`: Notion sample scrub and import checklist

## Import Order

1. Create the `LabA Huly Pilot` workspace.
2. Create channels from `workspace.seed.yaml`.
3. Create projects from `workspace.seed.yaml`.
4. Import or copy the Markdown documents into Huly docs/wiki.
5. Create the sample issues and milestone from the issue Markdown files.
6. Replace `PILOT_DAY_*` placeholders with dates from the actual pilot window.
7. Run the Notion sample checklist before importing any exported page content.
8. Run the Huly gate checks from the manifest before opening the pilot to users.

Keep local edits inside this seed directory unless a later phase explicitly adds
an importer script or runbook.
