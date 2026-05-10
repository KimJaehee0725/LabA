# Lab Handbook

Seed source: `deploy/huly/seed/docs/lab-handbook.md`

This page is sample Huly pilot content. Replace role placeholders with approved
team labels in the live workspace. Do not add credentials, personal data, private
research notes, or unpublished dataset details to the tracked seed copy.

## Start Here

The Huly pilot workspace is the default place for:

- lab-wide announcements in `#general`
- research discussion in `#research`
- paper planning in `#paper`
- service and integration work in `#infra`
- informal pilot discussion in `#random`

Project work is tracked in:

- `Experiments`
- `Papers`
- `Infrastructure`
- `Datasets`
- `Onboarding`

## Communication Norms

- Put decisions in a Huly doc or issue, not only in chat.
- Link experiment tasks to the related meeting note or report page.
- Move operational incidents to the `Infrastructure` project.
- Keep paper deadline updates in the `Papers` project and `#paper`.
- Use short summaries when linking external documents.

## Access And Accounts

Use the approved identity provider flow for Huly access. A pilot member should be
able to open Huly, complete authentication, and reach the workspace without using
shared credentials.

Never paste these into Huly docs, comments, or chat:

- passwords
- API tokens
- OAuth client secrets
- webhook secrets
- private keys
- unredacted environment files
- private dataset download links

## Research Workflow

Each experiment should have one Huly issue with:

- hypothesis or goal
- dataset placeholder or approved dataset reference
- code repository reference
- expected metrics
- run notes
- result summary
- reproducibility checklist

Use synthetic or scrubbed artifacts in the pilot seed. Real experiment results
belong only in approved private project areas.

## Dataset Handling

Dataset tasks should record:

- source approval status
- license or access notes
- storage location category
- upload or checksum status
- QA owner role
- retention or deletion note

Do not attach raw datasets to sample Huly docs.

## Coding Norms

- Keep work tied to a Huly issue when practical.
- Link pull requests back to the Huly issue after GitHub sync is enabled.
- Record validation commands in the issue before moving it to `Done`.
- Keep secrets in server-only environment files.

## Incident Notes

Operational incidents belong in `#infra` and the `Infrastructure` project. Each
incident note should capture:

- symptom
- affected service
- start and end time
- mitigation
- validation
- follow-up task

## Onboarding

New pilot members should complete the onboarding checklist before they receive
real project assignments. The tracked sample checklist is in:

`deploy/huly/seed/checklists/onboarding-checklist.md`
