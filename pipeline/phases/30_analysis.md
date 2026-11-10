id: 3
name: Analysis
owner: data-scientist
requires: 1 2
---
Phase {{ID}} — Analysis. Project slug: {{SLUG}}. Research request: {{TOPIC}}

Delegate to the data-scientist sub-agent: inputs {{DRAFTS}}/01_strategy.md and
{{DRAFTS}}/02_literature_matrix.md; name the execution/filesystem tools to use and
any dataset it is authorized to download; deliverable {{DRAFTS}}/03_analysis/ with
run.sh and RESULTS.md.
Then re-run the reproduce command yourself, confirm at least three reported
numbers against the logs, confirm simulated data is labeled, and write the
scorecard to reviews/{{SLUG}}_P{{ID}}_data-scientist_{{DATE}}.md. REVISE at most twice.
