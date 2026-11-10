id: 4
name: Write, audit, release
owner: academic-writer, peer-reviewer
requires: 1 2 3
---
Phase {{ID}} — Write, audit, release. Project slug: {{SLUG}}. Research request: {{TOPIC}}

a. Delegate to academic-writer: inputs are the approved upstream artifacts in
   {{DRAFTS}}/ and {{SOURCES}}/refs.bib; state the target venue; local drafts only
   (no remote pushes unless the user has authorized a specific destination);
   deliverables {{DRAFTS}}/04_manuscript_v1.* and {{DRAFTS}}/04_claim_map.md.
   Score it: reviews/{{SLUG}}_P{{ID}}_academic-writer_{{DATE}}.md.
b. Delegate to peer-reviewer: audit the manuscript against {{SOURCES}}/ and
   {{DRAFTS}}/03_analysis/; deliverable {{DRAFTS}}/05_audit.md.
   Score it: reviews/{{SLUG}}_P{{ID}}_peer-reviewer_{{DATE}}.md.
c. If the audit has BLOCKER items, route each to the owning specialist, then
   re-audit. At most two loops.
d. Final gate: independently confirm a sample of the reviewer's checks. Only with
   zero open BLOCKERs, copy the approved artifacts to outputs/{{SLUG}}/ and write
   reviews/{{SLUG}}_P{{ID}}_final_{{DATE}}.md.
Report: what was produced and where, what was verified and how, and what remains
unverified.
