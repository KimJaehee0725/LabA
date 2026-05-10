---
id: paper-milestone-demo
project: Papers
type: milestone
status: Backlog
priority: high
channel: "#paper"
labels:
  - pilot
  - paper
  - gantt
start: PILOT_DAY_03
due: PILOT_DAY_14
assignee_role: paper owner
---

# Track Sample Paper Milestone To Draft Freeze

This milestone checks whether Huly can manage paper work with dates,
dependencies, and a timeline or Gantt view.

## Milestone Goal

Reach a sample draft freeze using placeholder tasks. Do not add real title,
author list, reviewer comments, unpublished claims, or submission metadata to
the tracked seed.

## Child Tasks

| Task | Suggested Window | Dependency |
| --- | --- | --- |
| Draft abstract | PILOT_DAY_03 to PILOT_DAY_04 | none |
| Fill experiment table | PILOT_DAY_04 to PILOT_DAY_08 | experiment-task-demo |
| Complete first draft | PILOT_DAY_08 to PILOT_DAY_11 | draft abstract, experiment table |
| Internal review pass | PILOT_DAY_11 to PILOT_DAY_13 | complete first draft |
| Rebuttal template check | PILOT_DAY_13 to PILOT_DAY_14 | internal review pass |

## Timeline Check

- [ ] Add start and due dates to the milestone.
- [ ] Add child tasks or linked issues for each row above.
- [ ] Confirm the timeline or Gantt view renders after browser refresh.
- [ ] Confirm dependency or grouping behavior is good enough for pilot use.
- [ ] Record blockers in a Huly decision note.

## Acceptance Criteria

- The milestone is visible in the `Papers` project.
- The milestone can be grouped with child tasks or linked issues.
- Timeline or Gantt view renders in the self-hosted deployment.
- The workflow does not require Plane as the canonical task tracker for this sample.
