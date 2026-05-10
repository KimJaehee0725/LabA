---
id: github-sync-demo
project: Infrastructure
type: integration-check
status: Ready
priority: high
channel: "#infra"
labels:
  - pilot
  - github-sync
  - integration
repository_placeholder: example-org/example-repo
assignee_role: infrastructure owner
---

# Validate Huly And GitHub Issue Sync

This issue validates one bidirectional sync path between Huly and GitHub using a
single approved pilot repository. Keep all app IDs, private keys, webhook
secrets, and client secrets out of this tracked seed.

## Scope

Use one placeholder repository until the pilot owner approves the real target:

`example-org/example-repo`

Required GitHub App permissions for the pilot should start narrow:

- Metadata: read
- Issues: read and write
- Pull requests: read and write
- Contents: read

## Sync Checks

- [ ] Create this issue in Huly.
- [ ] Confirm it appears in the approved GitHub repository.
- [ ] Change a label or status in GitHub.
- [ ] Confirm the change appears back in Huly.
- [ ] Link a placeholder pull request.
- [ ] Close or merge the pull request.
- [ ] Confirm the Huly issue activity records the PR event.

## Evidence To Record

- Huly issue ID
- GitHub issue number
- timestamp of Huly to GitHub sync
- timestamp of GitHub to Huly sync
- PR event observed
- blocker or workaround summary

Do not paste webhook payloads, tokens, private keys, or raw environment files
into the issue.

## Acceptance Criteria

- One Huly-created issue appears in GitHub.
- One GitHub-side update appears back in Huly.
- One PR close or merge event is visible in Huly.
- Any limitation is recorded as a pilot blocker or decision note.
