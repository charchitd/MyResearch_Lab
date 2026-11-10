# Lab run log

---

## 2026-11-10 — Session start (MCP inventory)

### MCP Servers — Status

| Server | Config state | Transport | Status | Capability class |
|---|---|---|---|---|
| sequential-thinking | on | stdio | **AVAILABLE** (`mcp__sequential-thinking__sequentialthinking`) | Structured reasoning |
| filesystem | on | stdio | **AVAILABLE** (`mcp__filesystem__*`) | File read/write scoped to sources/, outputs/, reviews/ |
| puppeteer | on | stdio | **CONNECT_TIMEOUT** (30 s timeout at session start) | Web browsing / screenshots |
| playwright | off | stdio | Not registered | Web browsing (alternative) |
| arxiv | off | stdio | Not registered | Scholarly metadata |
| zotero | off | stdio | Not registered | Reference library |
| brave-search | off | stdio | Not registered | Web search |
| github | off | http | Not registered | Versioning / GitHub |
| lab-db | off | stdio | Not registered | Custom results DB |

### claude.ai-hosted MCP connectors (available via deferred tools)

| Server | Key tools | Auth status |
|---|---|---|
| Consensus | `search`, `create_thread` | **AVAILABLE** (no extra auth) |
| Fast Track Literature Open | `search_papers`, `get_paper`, `map_topic_debate`, `run_duplication_test`, `check_gap_saturation` | **AVAILABLE** (no extra auth) |
| PubMed | `search_articles`, `get_full_text_article`, `get_article_metadata` | **AVAILABLE** (no extra auth) |
| Wiley Scholar Gateway | `search_wiley_fulltext`, `getUsageLimit` | **AVAILABLE** (no extra auth — usage-capped) |
| Gmail | Full suite (send, search, draft, label…) | **AVAILABLE** (connected to charchitdhawan@gmail.com) |
| Google Drive | Read, search, share, update | **AVAILABLE** (connected) |
| Google Calendar | authenticate / complete_authentication | Auth flow not yet run |
| Claude Docs | create, read, update, batch | **AVAILABLE** |
| Indeed | search_jobs, get_job_details, get_resume | **AVAILABLE** |
| Canva | authenticate / complete_authentication | Auth flow not yet run |
| Refine.ink | authenticate / complete_authentication | Auth flow not yet run |
| Zapier | Full suite (9 000+ apps via actions) | **AVAILABLE** (needs action enable per use) |
| plugin: claude-mem | search, smart_search, smart_outline, timeline | **AVAILABLE** |

### Capability → tool binding

| Capability | Bound tool | Fallback |
|---|---|---|
| Web search / browsing | `WebSearch` (built-in) | `WebFetch` |
| Web screenshots | puppeteer — **UNAVAILABLE** (timeout) | manual |
| Scholarly metadata | Consensus · Fast Track Literature · PubMed · Wiley | `WebFetch` on DOI/arXiv URLs |
| Reference library | sources/<project>/refs.bib (manual) | — |
| Files | `mcp__filesystem__*` | `Read`, `Write`, `Edit`, `Glob`, `Grep` |
| Code execution | `Bash` (built-in) | — |
| Versioning / drafts | local git | outputs/_drafts/ |
| Structured reasoning | `mcp__sequential-thinking__sequentialthinking` | plan in turn |

### Issues to surface to user
1. **puppeteer** timed out — web screenshot / browser-automation tasks will fail until the server is restarted or replaced with playwright (switch state to `on` in `pipeline/mcp_servers.conf` and re-run `./run_lab.sh mcp playwright`).
2. **Google Calendar**, **Canva**, **Refine.ink** — auth flows not completed; run `authenticate` tool for each if needed.
3. **arxiv**, **zotero**, **brave-search**, **github**, **lab-db** — all `off`; enable when a project requires them.

