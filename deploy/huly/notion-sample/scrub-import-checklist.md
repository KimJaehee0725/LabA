# Notion Sample Scrub And Import Checklist

Use this checklist for the Phase 3 Huly pilot Notion migration sample. Keep the
actual Notion export outside git unless it has been reviewed and explicitly
approved as public sample content.

## Export Scope

- [ ] Export no more than five approved sample pages.
- [ ] Include only pages needed to test handbook, meeting notes, table, link, image, checklist, and code block rendering.
- [ ] Exclude private meeting notes, personnel pages, unpublished results, and raw datasets.
- [ ] Exclude credential stores, environment notes, token setup pages, and incident pages with sensitive details.

## Scrub Review

- [ ] Search page text for credential words such as `password`, `token`, `secret`, `private key`, `client secret`, and `webhook secret`.
- [ ] Search attachment names for private dataset names, private repository names, or personal identifiers.
- [ ] Remove real names, personal email addresses, phone numbers, student IDs, and private account handles.
- [ ] Replace private repository URLs with `example-org/example-repo`.
- [ ] Replace private dataset locations with `SAMPLE_DATASET_PLACEHOLDER`.
- [ ] Replace private paper titles with `Sample Paper Placeholder`.
- [ ] Remove unapproved images and screenshots.
- [ ] Confirm no generated export ZIP or raw attachment folder is staged for commit.

## Import Prep

- [ ] Map each approved page to a Huly destination under `Lab Handbook`.
- [ ] Decide whether each page will use Huly import or manual copy.
- [ ] Preserve headings and tables where practical.
- [ ] Convert unsupported database fields into simple Markdown tables.
- [ ] Convert Notion task checkboxes into Markdown checklist items.
- [ ] Keep links to internal Huly pages or approved public sample URLs only.

## Huly Import Check

- [ ] Import or copy the scrubbed sample into the Huly pilot workspace.
- [ ] Verify page headings render correctly.
- [ ] Verify tables remain readable.
- [ ] Verify code blocks retain formatting.
- [ ] Verify checklist items remain interactive or readable.
- [ ] Verify images render only if they are approved sample images.
- [ ] Verify internal links either work or have documented replacement targets.

## Evidence To Record

- [ ] Page count imported.
- [ ] Import method used.
- [ ] Formatting issues found.
- [ ] Manual cleanup time estimate.
- [ ] Decision: Huly import acceptable, manual copy acceptable, or migration cost too high.

Record evidence in Huly as a short summary only. Do not attach the raw Notion
export unless it has passed a separate public-sample review.
