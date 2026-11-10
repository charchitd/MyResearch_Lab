id: 0
name: Bootstrap
owner: pi
requires:
---
Phase {{ID}} — Bootstrap. Project slug: {{SLUG}}. Research request: {{TOPIC}}

1. Inventory every MCP tool available to you (names starting with mcp__) and run
   `claude mcp list`. Append the inventory to reviews/run_log.md under today's date:
   server, capability class, status.
2. Map each capability class in CLAUDE.md §3 to a concrete tool or its fallback.
3. Read the phase registry (`./run_lab.sh list`) and restate the request as a
   research objective with acceptance criteria. Write the phase plan (owner,
   deliverable path, acceptance test per phase) to reviews/run_log.md.
   Create {{DRAFTS}}/ and {{SOURCES}}/.
Do not delegate yet.
