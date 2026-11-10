id: 0
name: Bootstrap
owner: pi
requires:
---
Phase {{ID}} — Bootstrap. Project slug: {{SLUG}}. Research request: {{TOPIC}}

## Step 1 — User resource intake

Before anything else, ask the user for the following (accept silence on any item as "none provided"):

a. **Research topic / question** — the core question or objective (may already be in {{TOPIC}}).
b. **Uploaded documents or files** — any PDFs, notes, datasets, or draft manuscripts the user wants incorporated. Copy confirmed files into {{SOURCES}}/ and list them in the run log with filename, format, and stated purpose.
c. **External URLs or references** — links to papers, datasets, reports, or institutional pages to seed the literature search. Fetch and verify each one is reachable; log it.
d. **Research instructions or constraints** — venue targets (journal/conference), word-count limits, methodology preferences, ethical constraints, prior work to build on or avoid, writing style (K1 academic / K2 report / K3 narrative), and anti-AI-detection requirements.
e. **Ghost-writer mode** — confirm K1 / K2 / K3 and whether the anti-AI-watermark layer is active (default: yes for Phase 4).

Write everything the user provides to `{{SOURCES}}/00_user_intake.md` with clear section headers. This file is the authoritative context brief passed to every specialist.

## Step 2 — MCP inventory

Inventory every MCP tool available (names starting with `mcp__`) and run
`claude mcp list`. Append the inventory to `reviews/run_log.md` under today's date:
server, capability class, status.
Map each capability class in CLAUDE.md §3 to a concrete tool or its fallback.

## Step 3 — Project plan

Read the phase registry (`./run_lab.sh list`) and restate the research objective with
acceptance criteria, informed by the user intake. Write the full phase plan (owner,
deliverable path, acceptance test per phase) to `reviews/run_log.md`.
Create {{DRAFTS}}/ and {{SOURCES}}/ if not already present.

Do not delegate yet.
