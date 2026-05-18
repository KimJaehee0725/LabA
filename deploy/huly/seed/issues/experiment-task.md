---
id: experiment-task-demo
project: Experiments
type: task
status: Ready
priority: medium
channel: "#research"
labels:
  - pilot
  - experiment
  - reproducibility
start: PILOT_DAY_02
due: PILOT_DAY_07
assignee_role: experiment owner
---

# Run Sample Baseline Experiment Lifecycle

This sample task verifies that Huly can represent a research experiment from
planning through reporting. Use only synthetic or scrubbed sample data.

## Goal

Confirm that an experiment issue can carry status, role assignment, due date,
notes, checklist items, and result summary in the Huly project and calendar
views.

## Checklist

- [ ] Define the sample hypothesis.
- [ ] Confirm that the dataset reference is synthetic or approved for pilot use.
- [ ] Link the placeholder code repository.
- [ ] Record planned metrics.
- [ ] Run the sample training or dry-run command outside this seed file.
- [ ] Attach or link a scrubbed result summary.
- [ ] Add reproducibility notes.
- [ ] Move the issue through `Ready`, `In Progress`, `Review`, and `Done`.

## Sample Hypothesis

A minimal baseline can complete the pilot workflow and produce a small metrics
summary without using private data.

## Sample Metrics

| Metric | Placeholder Value | Notes |
| --- | --- | --- |
| accuracy | 0.91 | Synthetic sample number |
| loss | 0.23 | Synthetic sample number |
| runtime | 5 min | Pilot dry-run estimate |

## Acceptance Criteria

- The issue appears in the `Experiments` project.
- The due date appears in calendar or project views.
- A role placeholder can be assigned.
- The result summary remains linked after a page refresh.
- No private dataset, credential, or personal data is attached.
