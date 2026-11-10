# AI Research Lab

A **multi-agent academic research workspace** built on [Claude Code](https://claude.com/claude-code). Drop in a research question; the lab runs it through a gated pipeline of specialist AI agents — strategist → literature review → analysis → manuscript → peer audit — and only promotes work that passes a scored quality gate.

---

## How it works

```
You
 └── PI Orchestrator  (CLAUDE.md)
      ├── research-strategist    — novelty verification, experimental design
      ├── literature-specialist  — paper retrieval, citation matrix, BibTeX
      ├── data-scientist         — simulation, statistical analysis, figures
      ├── academic-writer        — manuscript drafting to venue guidelines
      └── peer-reviewer          — citation audit, adversarial red-team review
```

Every specialist is a Claude Code sub-agent defined in `agents/`. They report only to the PI; they never talk to each other directly. Nothing reaches the `outputs/` folder without an **APPROVE** scorecard in `reviews/`.

---

## Pipeline

Phases are defined in `pipeline/phases/` and run in filename order. The default pipeline:

| Phase | ID | Owner | Deliverable |
|---|---|---|---|
| Bootstrap / MCP inventory | `0` | PI | `reviews/run_log.md` |
| Research strategy | `1` | research-strategist | `outputs/_drafts/<project>/01_strategy.md` |
| Literature review | `2` | literature-specialist | `02_literature_matrix.md`, `sources/<project>/refs.bib` |
| Data & analysis | `3` | data-scientist | `03_analysis/` (code + figures + `RESULTS.md`) |
| Write & audit | `4` | academic-writer → peer-reviewer | `04_manuscript.*`, `05_audit.md` |

Each phase file carries an `id`, `owner`, `requires` (gate prerequisites), and a prompt template. The engine (`run_lab.sh`) discovers phases at runtime — adding a phase is a file, not a code change.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/charchitd/MyResearch_Lab.git
cd MyResearch_Lab

# 2. Bootstrap folders and sync agents into .claude/agents/
./run_lab.sh setup

# 3. Register MCP servers marked `on` in pipeline/mcp_servers.conf
./run_lab.sh mcp

# 4. Validate everything
./run_lab.sh doctor

# 5. Run a single phase interactively (open Claude Code first)
./run_lab.sh phase 1 my-project "Effect of sleep deprivation on working memory"

# 6. Or run the full pipeline automatically
./run_lab.sh all my-project "Effect of sleep deprivation on working memory"
```

The engine resumes from the last passed phase, so a failed or interrupted run just picks up where it left off.

---

## Engine commands

| Command | What it does |
|---|---|
| `setup` | Create folders, sync agents to `.claude/agents/` |
| `doctor` | Validate agents, phases, MCP registry, and tooling |
| `list` | Print the phase registry |
| `status <slug>` | Show which phases a project has passed |
| `phase <id> <slug> "<topic>"` | Run one phase through the PI |
| `all <slug> "<topic>"` | Run every phase in order; resumes after last pass |
| `mcp [name…]` | Register all `on` servers, or specific ones by name |
| `mcp-status` | List configured servers and their health |
| `new-agent <name>` | Scaffold `agents/<name>.md` from the template |
| `new-phase <order> <id> <name> <owner>` | Scaffold a new phase file |

Override behaviour with environment flags: `DRY_RUN=1` (print prompts instead of running), `FORCE=1` (ignore gate prerequisites).

---

## MCP server registry

`pipeline/mcp_servers.conf` controls which MCP servers the lab registers. Flip `off → on` and run `./run_lab.sh mcp <name>` to activate:

| Server | Default | Capability |
|---|---|---|
| `sequential-thinking` | **on** | Structured multi-step reasoning |
| `filesystem` | **on** | Scoped file access (sources/, outputs/, reviews/) |
| `puppeteer` | **on** | Web browsing / screenshots |
| `playwright` | off | Alternative browser automation |
| `arxiv` | off | arXiv search + PDF download |
| `zotero` | off | Zotero desktop integration |
| `brave-search` | off | Web search (needs `BRAVE_API_KEY`) |
| `github` | off | GitHub remote operations (needs `GITHUB_PAT`) |
| `lab-db` | off | Custom SQLite results database |

Cloud-hosted connectors (Consensus, PubMed, Fast Track Literature, Wiley, Gmail, Google Drive, Claude Docs) are available through the Claude.ai MCP layer when running inside Claude Code — no additional setup required.

---

## Extending the lab

| To add | Command |
|---|---|
| A new specialist | `./run_lab.sh new-agent <name>` → fill `agents/<name>.md` → `./run_lab.sh setup` |
| A new phase | `./run_lab.sh new-phase <order> <id> <name> <owner>` → set `requires:` |
| A new MCP server | Add a line to `pipeline/mcp_servers.conf` → `./run_lab.sh mcp <name>` |
| Any change | Finish with `./run_lab.sh doctor` |

---

## Workspace layout

```
.
├── agents/                   Specialist definitions (source of truth)
├── .claude/agents/           Runtime copies (synced by run_lab.sh setup)
├── pipeline/
│   ├── phases/               Phase registry files (NN_<name>.md)
│   ├── templates/            Scaffolds for new agents and phases
│   ├── mcp_servers.conf      MCP server registry
│   └── lab.conf              Engine settings
├── sources/                  PDFs, BibTeX, datasets (per project)
├── outputs/
│   ├── _drafts/              Working artifacts (unapproved)
│   └── <project>/            Approved, promoted artifacts
├── reviews/                  Scorecards and run log
├── CLAUDE.md                 PI Orchestrator instructions
└── run_lab.sh                Lab engine
```

---

## Quality rules

- No fabricated citations, data, or results. Every reference must be retrieved through a tool or found in `sources/`; unverified claims are marked `UNVERIFIED`.
- Synthetic or simulated data is labeled as such in every table, figure caption, and sentence that uses it.
- Every factual claim carries provenance: tool name, query or identifier, retrieval date.
- The PI reads the artifact, not the summary. Spot-checks are logged in the scorecard.

---

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI
- Bash (Git Bash on Windows)
- Node.js / `npx` (for stdio MCP servers)
- `uv` / `uvx` (optional, for arXiv and Zotero servers)
