# Full-Pass Huly And Minimal Ops Runbook

Status: Huly core staging conditional-pass; full-pass pending.

This runbook closes the remaining Phase 3 Huly full-pass evidence and defines
the minimal operations gate that must pass before starting Phase 6 Overleaf.
Do not record secrets, private keys, OAuth client secrets, webhook secrets,
tokens, raw Notion exports, or private research content in this file or in git.

## Current Gate State

| Area | Status | Evidence source |
| --- | --- | --- |
| Huly core staging | Conditional-pass | `deploy/reports/phase3-huly-pilot.md` |
| Automated relaxed preflight | Passed in staging mode | `23-check-phase3-huly-preflight.sh` with strict external checks disabled |
| Runtime smoke | Passed in staging mode | `30-check-huly.sh` with `STAGING_IP=127.0.0.1` |
| Workspace seed bundle | Ready; manual creation pending | `31-bootstrap-huly-workspace.sh` |
| GitHub App sync | Pending credentials and roundtrip | Server-only `30-huly.env` values |
| Google Calendar sync | Pending credentials and event sync | Server-only credential JSON |
| Notion sample import | Pending scrub/import | `deploy/huly/notion-sample/scrub-import-checklist.md` |
| Pilot usage | Pending one-week, two-user use | Pilot evidence table below |

Full pass requires strict checks with real DNS/TLS/SMTP, browser OIDC login,
seeded workspace evidence, GitHub and Google Calendar roundtrips, Notion sample
scrub/import evidence, timeline/Gantt evidence or a logged fallback decision,
and one week of pilot usage.

## Huly Browser And OIDC Evidence Checklist

Use a private browser session. Record timestamps, operator initials, test user
roles, URLs, HTTP/status observations, and screenshot filenames stored in the
private evidence folder. Do not record passwords, TOTP seeds, session cookies,
authorization codes, ID tokens, access tokens, refresh tokens, or client
secrets.

- [ ] `https://huly.lab.example.ac.kr` resolves through real DNS and trusted TLS.
- [ ] `HULY_OIDC_TLS_REJECT_UNAUTHORIZED=1` is set after trusted TLS is active.
- [ ] Public unauthenticated workspace access is blocked.
- [ ] Authentik/OpenID login button is visible and routes to `auth.lab.example.ac.kr`.
- [ ] Member user completes OIDC login and lands in the pilot workspace.
- [ ] Second pilot user completes OIDC login and sees the same workspace.
- [ ] Invite-only or public-signup-disabled behavior is confirmed.
- [ ] Logout clears Huly access and a fresh private browser requires login again.
- [ ] No forward-auth fallback was used. If fallback is used, full pass is blocked
  until the app-native OIDC failure is recorded and resolved.

Evidence template:

| Check | Timestamp | User role | Result | Evidence ref | Notes |
| --- | --- | --- | --- | --- | --- |
| Front TLS and login redirect | | | | | |
| Member OIDC login | | | | | |
| Second user workspace access | | | | | |
| Logout and re-login requirement | | | | | |

## Workspace Seed And Manual Content Evidence

Validate the seed bundle first:

```bash
/opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh
```

Then manually create the pilot content from
`/opt/lab-stack/huly/seed/workspace.seed.yaml` and seed artifacts. Keep real
names, emails, student IDs, private repository names, unpublished paper titles,
private datasets, and credentials out of screenshots and notes.

Required seed evidence:

| Content | Expected | Evidence ref | Result | Notes |
| --- | --- | --- | --- | --- |
| Workspace | `LabA Huly Pilot`, invitation-only | | | |
| Channels | `#general`, `#research`, `#paper`, `#infra`, `#random` | | | |
| Projects | `Experiments`, `Papers`, `Infrastructure`, `Datasets`, `Onboarding` | | | |
| Docs/wiki | `Lab Handbook`, `Meeting Notes` | | | |
| Issues | experiment task, paper milestone, GitHub sync issue, onboarding checklist | | | |
| Two-user visibility | Both pilot users see same channels, docs, projects, and issues | | | |
| Task flow | Assignee, due date, status, and project/calendar views update | | | |

## GitHub App Credential And Roundtrip Checklist

Create one GitHub App for one approved pilot repository. Store all values only
in server-side env or secret files. Record only presence, file path ownership,
permission summary, and roundtrip results.

Required setup:

- [ ] GitHub App ID, slug, client ID, client secret, webhook secret, and private
  key are set on the server without printing values.
- [ ] Private key file is readable only by root or the deployment operator.
- [ ] Callback URL is `https://huly.lab.example.ac.kr/github`.
- [ ] Setup URL is `https://huly.lab.example.ac.kr/github?op=installation`.
- [ ] Webhook URL is `https://huly.lab.example.ac.kr/_github/api/webhook`.
- [ ] App is installed only on the approved pilot repository.
- [ ] Huly is started with the GitHub profile enabled.
- [ ] Strict preflight passes with `PHASE3_REQUIRE_GITHUB=true`.

Roundtrip evidence:

| Test | Expected result | Timestamp | Evidence ref | Notes |
| --- | --- | --- | --- | --- |
| Huly issue to GitHub | Huly-created issue appears in the pilot repository | | | |
| GitHub update to Huly | Label, status, comment, or title update appears in Huly | | | |
| PR event to Huly | PR open, close, merge, or review event appears in Huly activity | | | |
| Webhook delivery | GitHub delivery is successful without exposing payload secrets | | | |

## Google Calendar OAuth And Event Sync Checklist

Create a Google OAuth web application credential with Calendar API enabled.
Store credential JSON only on the server, for example
`/opt/lab-stack/secrets/huly/google-calendar-oauth.json`, and reference it from
`30-huly.env`. Do not copy JSON contents or OAuth secrets into evidence.

Required setup:

- [ ] Redirect URI is `https://huly.lab.example.ac.kr/_calendar/signin/code`.
- [ ] Calendar API is enabled in the Google project.
- [ ] Required scopes are approved for the pilot: calendar list readonly,
  userinfo email, calendars readonly, and calendar events.
- [ ] Credential JSON file permissions are restricted.
- [ ] Huly is started with the Calendar profile enabled.
- [ ] Strict preflight passes with `PHASE3_REQUIRE_CALENDAR=true`.

Event sync evidence:

| Test | Expected result | Timestamp | Evidence ref | Notes |
| --- | --- | --- | --- | --- |
| OAuth connect | Pilot user connects Google Calendar through Huly | | | |
| Huly to Google | Event created in Huly appears in Google Calendar | | | |
| Google to Huly | Event update in Google appears back in Huly | | | |
| Disconnect/reconnect | Reconnect works without duplicate calendars or events | | | |

## Notion Sample Scrub, Import, And Timeline Evidence

Use only an approved sample export of no more than five pages. Keep the raw
export, ZIP files, attachments, CSV databases, and private notes outside git.
Complete `deploy/huly/notion-sample/scrub-import-checklist.md` before import.

Scrub/import checklist:

- [ ] Export scope is no more than five approved sample pages.
- [ ] Credential words and attachment names are searched and scrubbed.
- [ ] Personal identifiers, private repositories, datasets, paper titles, and
  screenshots are removed or replaced with placeholders.
- [ ] Import destination under `Lab Handbook / Imported Samples` is chosen.
- [ ] Import method is recorded: native import, Markdown copy, or manual copy.
- [ ] Headings, tables, links, code blocks, checklists, and approved images are
  checked after import.
- [ ] Formatting blockers and cleanup time estimate are recorded as a summary
  only, without attaching raw exports.

Notion evidence template:

| Item | Value |
| --- | --- |
| Page count imported | |
| Import method | |
| Destination | |
| Formatting issues | |
| Manual cleanup estimate | |
| Decision | Huly import acceptable / manual copy acceptable / migration cost too high |

Gantt/timeline evidence template:

| Test | Expected result | Timestamp | Evidence ref | Notes |
| --- | --- | --- | --- | --- |
| Paper milestone dates | Start and due dates render in timeline or Gantt view | | | |
| Experiment task dates | Multiple tasks show correct ordering and status | | | |
| Project/calendar reflection | Due date changes appear in project or calendar views | | | |
| Fallback decision | If timeline/Gantt is unavailable, decision and substitute view are logged | | | |

## One-Week Pilot Usage Evidence

Pilot requirement: at least two users use Huly for one week. Record daily usage
summaries, not private message bodies or unpublished research details.

| Day | Date | Active users | Docs/wiki used | Chat used | Issues/tasks updated | Calendar/GitHub used | Blockers | Decision or follow-up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | | | |
| 2 | | | | | | | | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |
| 6 | | | | | | | | |
| 7 | | | | | | | | |

Pilot closeout:

- [ ] Two pilot users completed the full week.
- [ ] At least one doc/wiki workflow was used.
- [ ] At least one chat-to-task workflow was used.
- [ ] At least one GitHub-linked issue workflow was used.
- [ ] At least one Calendar-linked event workflow was used.
- [ ] Blockers are recorded with owner and next action.
- [ ] Gate decision is recorded in `deploy/reports/phase3-huly-pilot.md`.

## Minimal Ops Gate Before Overleaf

This is the minimum operations gate before starting Phase 6 Overleaf. Passing it
does not replace the full Ops phase; it only confirms the platform has enough
backup and monitoring coverage to add the paper collaboration service.

| Gate | Required evidence | Pass condition |
| --- | --- | --- |
| Backup | Latest backup job log and artifact listing for Authentik, Huly, Nginx/cert metadata, MinIO/HF if active | Daily backup completed and artifacts are present under the backup root |
| Restore | One restore rehearsal note using a sample service or sample data | Restored sample is verified, and the restore command/path is documented |
| Certificate expiry | Expiry check for public TLS domains | 30/15/7 day warning path is configured or dry-run verified |
| Disk usage | Root, data, and backup filesystem usage snapshot | Primary and backup disks are below warning threshold, or mitigation is logged |
| Uptime alert | Intentional test alert or equivalent dry-run from the monitoring system | Operator receives email or Slack alert and records timestamp |

Minimal ops evidence template:

| Check | Timestamp | Command/action | Result | Evidence ref | Follow-up |
| --- | --- | --- | --- | --- | --- |
| Backup | | | | | |
| Restore | | | | | |
| Certificate expiry | | | | | |
| Disk usage | | | | | |
| Uptime alert | | | | | |

## Overleaf Phase 6 Start Conditions

Do not start Overleaf implementation until all start conditions are satisfied or
an explicit conditional-start decision is recorded by the operator.

- [ ] Huly full-pass is complete, or unresolved Huly items are documented as not
  blocking Overleaf with owner and date.
- [ ] Minimal ops gate above is complete.
- [ ] Real DNS and trusted TLS are working for `overleaf.lab.example.ac.kr`.
- [ ] Nginx edge can add the Overleaf route without exposing direct service ports.
- [ ] SMTP is available for Overleaf account and notification flows.
- [ ] Public registration will be disabled before exposing the route.
- [ ] Admin-created local account model is accepted for MVP; SSO/LDAP remains
  deferred unless a separate decision changes scope.
- [ ] Backup plan covers Overleaf Toolkit backup, Mongo dump, and project files.
- [ ] Initial template set is approved: NeurIPS, ICML, ICLR, ACL/EMNLP, AAAI,
  plus Korean sample if needed.
- [ ] Phase 6 validation targets are ready: HTTPS login page, public signup
  blocked, two-user collaboration, basic PDF compile, template compile, and
  sample project backup/restore.

## Final Phase 3 Full-Pass Decision

Record the final decision in `deploy/reports/phase3-huly-pilot.md`:

| Decision field | Value |
| --- | --- |
| Result | pass / conditional-pass / fail |
| Decision date | |
| Operator | |
| Blocking items | |
| Accepted risks | |
| Next phase allowed | yes / no / conditional |

Strict full pass should be checked with the production-mode scripts after the
evidence above is complete:

```bash
sudo /opt/lab-stack/scripts/23-check-phase3-huly-preflight.sh
sudo /opt/lab-stack/scripts/30-check-huly.sh
sudo /opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh
sudo /opt/lab-stack/scripts/32-check-huly-pilot.sh
```
