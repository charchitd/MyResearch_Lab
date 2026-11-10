#!/usr/bin/env bash
# =============================================================================
# run_lab.sh — AI Research Lab engine (Claude Code + MCP)
# =============================================================================
# The engine holds no lab-specific content. Everything it runs is discovered:
#
#   agents/*.md               specialists        → synced to .claude/agents/
#   pipeline/phases/*.md      phase registry     → run in filename order
#   pipeline/mcp_servers.conf MCP server registry
#   pipeline/lab.conf         engine settings
#   pipeline/templates/       scaffolds for new agents and phases
#
# COMMANDS
#   setup                         Create folders, sync agents into .claude/agents/
#   doctor                        Validate agents, phases, registry and tooling
#   list                          Show the phase registry
#   status <slug>                 Show which phases a project has passed
#   phase <id> <slug> "<topic>"   Run one phase through the PI
#   all <slug> "<topic>"          Run every phase in order; resumes after the last pass
#   mcp [name...]                 Register MCP servers (all `on`, or the ones named)
#   mcp-status                    List configured MCP servers and their health
#   new-agent <name>              Scaffold agents/<name>.md from the template
#   new-phase <order> <id> <name> <owner>
#                                 Scaffold pipeline/phases/<order>_<name>.md
#
# ENVIRONMENT
#   DRY_RUN=1   Print phase prompts instead of calling claude (paste into `claude`).
#   FORCE=1     Ignore unmet `requires`, re-run passed phases, re-register servers.
#   Settings in pipeline/lab.conf can also be overridden from the environment.
#
# EXTENDING
#   New specialist   ./run_lab.sh new-agent ethics-reviewer   → edit → setup
#   New phase        ./run_lab.sh new-phase 25 2b ethics_review ethics-reviewer
#                    The two-digit order prefix sets position (25 runs between 20
#                    and 30). Set `requires:` to the ids that must pass first.
#   New MCP server   add one line to pipeline/mcp_servers.conf → ./run_lab.sh mcp <name>
#   Then run         ./run_lab.sh doctor
#
# PHASE FILE FORMAT (pipeline/phases/NN_name.md)
#   id: 2b                       unique token used on the command line and in gates
#   name: Ethics review
#   owner: ethics-reviewer       agent name(s), comma-separated, or `pi`
#   requires: 1 2                ids that must have PASSED for this project
#   ---
#   <prompt to the PI>           placeholders: {{ID}} {{SLUG}} {{TOPIC}} {{DRAFTS}}
#                                {{SOURCES}} {{DATE}}
#   The engine appends the gate instruction: the PI must end with
#   `PHASE <id> PASSED` or `PHASE <id> FAILED: <open issues>`.
#
# STATE
#   reviews/<slug>.state         one line per passed phase (drives resume + requires)
#   reviews/<slug>_P<id>_session_<timestamp>.log   headless transcripts
# =============================================================================

set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$LAB_ROOT"

PHASE_DIR="pipeline/phases"
MCP_CONF="pipeline/mcp_servers.conf"
TEMPLATE_DIR="pipeline/templates"

# shellcheck disable=SC1091
[ -f pipeline/lab.conf ] && . pipeline/lab.conf
: "${PERMISSION_MODE:=acceptEdits}" "${ALLOWED_TOOLS:=}" "${CLAUDE_EXTRA_FLAGS:=}"
: "${MCP_SCOPE:=project}" "${GATE_TAIL_LINES:=15}"
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log()  { printf '\n\033[1m[lab]\033[0m %s\n' "$*"; }
warn() { printf '[lab] WARN: %s\n' "$*" >&2; }
die()  { printf '[lab] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found on PATH. $2"; }
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0;; *) return 1;; esac; }

# Lab root as a spawned MCP server will see it (native Windows path under Git Bash).
native_lab() {
  if is_windows && command -v cygpath >/dev/null 2>&1; then cygpath -w "$LAB_ROOT"; else printf '%s' "$LAB_ROOT"; fi
}

# Replace {{LAB}} in one word; use backslashes for the whole word on Windows.
expand_lab() {
  local w="$1" lab; lab="$(native_lab)"
  case "$w" in
    *'{{LAB}}'*) w="${w//\{\{LAB\}\}/"$lab"}"; if is_windows; then w="${w//\//\\}"; fi ;;
  esac
  printf '%s' "$w"
}

# Replace ${VAR} with its environment value; fail if a variable is unset.
expand_vars() {
  local s="$1" v
  while [[ "$s" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
    v="${BASH_REMATCH[1]}"
    [ -n "${!v:-}" ] || { warn "environment variable $v is not set"; return 1; }
    s="${s//"\${$v}"/"${!v}"}"
  done
  printf '%s' "$s"
}

# ----------------------------------------------------------------------------
# Agents
# ----------------------------------------------------------------------------
agent_files() { local f; for f in agents/*.md; do [ -e "$f" ] || continue; case "$(basename "$f")" in _*) continue;; esac; printf '%s\n' "$f"; done; }
agent_name()  { sed -n 's/^name:[[:space:]]*//p' "$1" | head -n 1 | tr -d '\r'; }
agent_names() { local f; while IFS= read -r f; do agent_name "$f"; done < <(agent_files); }

setup() {
  log "workspace"
  mkdir -p agents sources reviews outputs/_drafts .claude/agents "$PHASE_DIR" "$TEMPLATE_DIR"
  [ -f reviews/run_log.md ] || printf '# Lab run log\n' > reviews/run_log.md

  local n=0 f
  while IFS= read -r f; do
    [ -n "$(agent_name "$f")" ] || die "$f has no 'name:' frontmatter"
    cp "$f" ".claude/agents/$(basename "$f")"
    n=$((n+1))
  done < <(agent_files)
  [ "$n" -gt 0 ] || die "no agent files in agents/"
  log "synced $n agent(s) → .claude/agents/  (verify inside claude with /agents)"
}

# ----------------------------------------------------------------------------
# Phase registry
# ----------------------------------------------------------------------------
phase_files() { local f; for f in "$PHASE_DIR"/[0-9]*.md; do [ -e "$f" ] && printf '%s\n' "$f"; done | sort; }

# meta <file> <key> — header value above the first '---' line
meta() {
  awk -v k="$2" '
    /^---[[:space:]]*$/ { exit }
    { sub(/\r$/, ""); i = index($0, ":")
      if (i && substr($0, 1, i-1) == k) { v = substr($0, i+1); gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit } }' "$1"
}
body() { awk 'f { sub(/\r$/, ""); print } /^---[[:space:]]*$/ && !f { f = 1 }' "$1"; }

find_phase() {
  local f
  while IFS= read -r f; do
    if [ "$(meta "$f" id)" = "$1" ]; then printf '%s' "$f"; return 0; fi
  done < <(phase_files)
  return 1
}

list_phases() {
  printf '%-6s %-28s %-36s %-10s %s\n' ID NAME OWNER REQUIRES FILE
  local f
  while IFS= read -r f; do
    printf '%-6s %-28s %-36s %-10s %s\n' "$(meta "$f" id)" "$(meta "$f" name)" \
      "$(meta "$f" owner)" "$(meta "$f" requires)" "$(basename "$f")"
  done < <(phase_files)
}

render_prompt() {
  local file="$1" slug="$2" topic="$3" id text
  id="$(meta "$file" id)"
  text="$(body "$file")"
  text="${text//\{\{ID\}\}/"$id"}"
  text="${text//\{\{SLUG\}\}/"$slug"}"
  text="${text//\{\{TOPIC\}\}/"$topic"}"
  text="${text//\{\{DRAFTS\}\}/"outputs/_drafts/$slug"}"
  text="${text//\{\{SOURCES\}\}/"sources/$slug"}"
  text="${text//\{\{DATE\}\}/"$(date +%Y%m%d)"}"
  printf '%s\n\n' "$text"
  printf 'Gate: follow CLAUDE.md §4 (verify, score, decide). End your reply with exactly one\n'
  printf 'final line: `PHASE %s PASSED` or `PHASE %s FAILED: <open issues>`.\n' "$id" "$id"
}

# ----------------------------------------------------------------------------
# Project state
# ----------------------------------------------------------------------------
state_file() { printf 'reviews/%s.state' "$1"; }
has_passed() { [ -f "$(state_file "$1")" ] && grep -q "^$2 PASSED " "$(state_file "$1")"; }
mark_passed() { printf '%s PASSED %s\n' "$2" "$(date +%Y-%m-%dT%H:%M:%S)" >> "$(state_file "$1")"; }

check_slug() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug must be kebab-case (a-z, 0-9, -)"; }

status() {
  check_slug "$1"
  printf '%-6s %-28s %s\n' ID NAME STATE
  local f id
  while IFS= read -r f; do
    id="$(meta "$f" id)"
    if has_passed "$1" "$id"; then printf '%-6s %-28s %s\n' "$id" "$(meta "$f" name)" PASSED
    else printf '%-6s %-28s %s\n' "$id" "$(meta "$f" name)" pending; fi
  done < <(phase_files)
}

# ----------------------------------------------------------------------------
# Phase runner
# ----------------------------------------------------------------------------
run_phase() {
  local id="$1" slug="$2" topic="$3" file prompt req out
  check_slug "$slug"
  file="$(find_phase "$id")" || die "no phase with id '$id' — see: ./run_lab.sh list"
  prompt="$(render_prompt "$file" "$slug" "$topic")"

  if [ "$DRY_RUN" = "1" ]; then
    printf '\n===== PHASE %s — %s (paste into `claude`) =====\n%s\n' "$id" "$(meta "$file" name)" "$prompt"
    return 0
  fi

  if [ "$FORCE" != "1" ]; then
    for req in $(meta "$file" requires); do
      has_passed "$slug" "$req" || die "phase $id requires phase $req, which has not passed for '$slug' (FORCE=1 to override)"
    done
  fi

  need claude "Install Claude Code first."
  [ -d .claude/agents ] || die "agents not synced — run: ./run_lab.sh setup"
  mkdir -p "outputs/_drafts/$slug" "sources/$slug" reviews

  local cmd=(claude -p "$prompt" --permission-mode "$PERMISSION_MODE")
  [ -z "$ALLOWED_TOOLS" ] || cmd+=(--allowedTools "${ALLOWED_TOOLS// /,}")
  # shellcheck disable=SC2206
  [ -z "$CLAUDE_EXTRA_FLAGS" ] || cmd+=($CLAUDE_EXTRA_FLAGS)

  out="reviews/${slug}_P${id}_session_$(date +%Y%m%d-%H%M%S).log"
  log "Phase $id ($(meta "$file" name)) → transcript: $out"
  "${cmd[@]}" | tee "$out"

  if tail -n "$GATE_TAIL_LINES" "$out" | grep -q "PHASE $id PASSED"; then
    mark_passed "$slug" "$id"
    log "Phase $id passed the PI gate"
  else
    die "Phase $id did not pass the PI gate — see $out and the scorecards in reviews/"
  fi
}

run_all() {
  local slug="$1" topic="$2" f id
  check_slug "$slug"
  while IFS= read -r f; do
    id="$(meta "$f" id)"
    if [ "$DRY_RUN" != "1" ] && [ "$FORCE" != "1" ] && has_passed "$slug" "$id"; then
      log "Phase $id already passed — skipping"
      continue
    fi
    run_phase "$id" "$slug" "$topic"
  done < <(phase_files)
  [ "$DRY_RUN" = "1" ] || log "Pipeline complete → outputs/$slug/"
}

# ----------------------------------------------------------------------------
# MCP registry
# ----------------------------------------------------------------------------
register_server() {
  local name="$1" transport="$2" extras="$3" target="$4"
  local args=(--scope "$MCP_SCOPE") headers=() item value w
  local -a parts words

  if claude mcp get "$name" >/dev/null 2>&1; then
    if [ "$FORCE" = "1" ]; then
      claude mcp remove "$name" --scope "$MCP_SCOPE" >/dev/null 2>&1 || true
    else
      log "mcp: '$name' already registered — skipping (FORCE=1 to replace)"
      return 0
    fi
  fi

  if [ "$extras" != "-" ] && [ -n "$extras" ]; then
    IFS=';' read -ra parts <<< "$extras"
    for item in "${parts[@]}"; do
      item="$(trim "$item")"; [ -n "$item" ] || continue
      value="$(expand_vars "$(expand_lab "$item")")" || { warn "skipping '$name'"; return 0; }
      if [ "$transport" = "http" ]; then headers+=(--header "$value"); else args+=(--env "$value"); fi
    done
  fi

  log "mcp: registering '$name' ($transport, scope $MCP_SCOPE)"
  case "$transport" in
    http)
      claude mcp add "${args[@]}" --transport http "$name" "$target" ${headers[@]+"${headers[@]}"} || warn "could not register $name"
      ;;
    stdio)
      read -ra words <<< "$target"
      local launch=()
      if is_windows; then launch=(cmd /c); fi
      for w in "${words[@]}"; do launch+=("$(expand_lab "$w")"); done
      # MSYS_NO_PATHCONV stops Git Bash rewriting '/c' into 'C:\'.
      MSYS_NO_PATHCONV=1 claude mcp add "${args[@]}" "$name" -- "${launch[@]}" || warn "could not register $name"
      ;;
    *) warn "'$name': unknown transport '$transport'" ;;
  esac
}

mcp_setup() {
  need claude "Install Claude Code first: https://code.claude.com/docs"
  [ -f "$MCP_CONF" ] || die "$MCP_CONF not found"
  local wanted=" $* " name state transport extras target found=0
  while IFS='|' read -r name state transport extras target || [ -n "$name" ]; do
    name="$(trim "${name%$'\r'}")"
    case "$name" in ''|'#'*) continue;; esac
    state="$(trim "$state")"; transport="$(trim "$transport")"
    extras="$(trim "$extras")"; target="$(trim "${target%$'\r'}")"
    if [ $# -gt 0 ]; then
      case "$wanted" in *" $name "*) ;; *) continue;; esac
    elif [ "$state" != "on" ]; then
      continue
    fi
    found=$((found+1))
    register_server "$name" "$transport" "$extras" "$target"
  done < "$MCP_CONF"
  [ "$found" -gt 0 ] || die "no matching server in $MCP_CONF"
  mcp_status
  printf '\n[lab] Next: start `claude` in this directory, approve the project servers when\n'
  printf '      prompted, and run /mcp. Tools appear as mcp__<server>__<tool>.\n'
}

mcp_status() {
  need claude "Install Claude Code first."
  log "Configured MCP servers"
  claude mcp list || true
}

# ----------------------------------------------------------------------------
# Scaffolding
# ----------------------------------------------------------------------------
new_agent() {
  local name="$1" file text
  [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || die "agent name must be kebab-case"
  file="agents/${name//-/_}.md"
  [ ! -e "$file" ] || die "$file already exists"
  text="$(cat "$TEMPLATE_DIR/agent.md")"
  printf '%s\n' "${text//\{\{NEW_NAME\}\}/"$name"}" > "$file"
  log "created $file — fill it in, then run: ./run_lab.sh setup"
}

new_phase() {
  local order="$1" id="$2" name="$3" owner="$4" file text
  [[ "$order" =~ ^[0-9][0-9]$ ]] || die "order must be two digits, e.g. 25"
  [[ "$id" =~ ^[A-Za-z0-9]+$ ]] || die "id must be alphanumeric, e.g. 2b"
  [[ "$name" =~ ^[a-z0-9_]+$ ]] || die "name must be snake_case, e.g. ethics_review"
  find_phase "$id" >/dev/null && die "phase id '$id' is already used"
  file="$PHASE_DIR/${order}_${name}.md"
  [ ! -e "$file" ] || die "$file already exists"
  text="$(cat "$TEMPLATE_DIR/phase.md")"
  text="${text//\{\{NEW_ID\}\}/"$id"}"
  text="${text//\{\{NEW_NAME\}\}/"${name//_/ }"}"
  text="${text//\{\{NEW_OWNER\}\}/"$owner"}"
  printf '%s\n' "$text" > "$file"
  log "created $file — set 'requires:' and the deliverable, then run: ./run_lab.sh doctor"
}

# ----------------------------------------------------------------------------
# Doctor
# ----------------------------------------------------------------------------
doctor() {
  local errors=0 f id owner o req ids=" " names
  bad() { printf '  FAIL  %s\n' "$*"; errors=$((errors+1)); }
  ok()  { printf '  ok    %s\n' "$*"; }
  note(){ printf '  note  %s\n' "$*"; }

  log "tooling"
  for o in claude npx; do if command -v "$o" >/dev/null 2>&1; then ok "$o on PATH"; else note "$o not on PATH"; fi; done

  log "agents"
  while IFS= read -r f; do
    if [ -z "$(agent_name "$f")" ]; then bad "$f: missing 'name:'"; continue; fi
    grep -q '^description:' "$f" || bad "$f: missing 'description:'"
    if cmp -s "$f" ".claude/agents/$(basename "$f")"; then ok "$(agent_name "$f")"
    else note "$(agent_name "$f") not synced — run ./run_lab.sh setup"; fi
  done < <(agent_files)
  names=" pi $(agent_names | tr '\n' ' ')"

  log "phases"
  while IFS= read -r f; do id="$(meta "$f" id)"; [ -n "$id" ] && ids="$ids$id "; done < <(phase_files)
  local seen=" "
  while IFS= read -r f; do
    id="$(meta "$f" id)"
    [ -n "$id" ] || { bad "$f: missing 'id:'"; continue; }
    case "$seen" in *" $id "*) bad "$f: duplicate id '$id'";; esac
    seen="$seen$id "
    [ -n "$(meta "$f" name)" ] || bad "$f: missing 'name:'"
    grep -q '^---[[:space:]]*$' "$f" || bad "$f: missing '---' separator"
    owner="$(meta "$f" owner)"
    [ -n "$owner" ] || bad "$f: missing 'owner:'"
    for o in ${owner//,/ }; do
      case "$names" in *" $o "*) ;; *) bad "$f: owner '$o' is not an agent in agents/";; esac
    done
    for req in $(meta "$f" requires); do
      case "$ids" in *" $req "*) ;; *) bad "$f: requires unknown phase '$req'";; esac
    done
    ok "phase $id ($(basename "$f"))"
  done < <(phase_files)

  log "mcp"
  if [ -f "$MCP_CONF" ]; then ok "$MCP_CONF"; else bad "$MCP_CONF missing"; fi
  if [ -f .mcp.json ]; then ok ".mcp.json present"; else note "no .mcp.json — run ./run_lab.sh mcp"; fi

  if [ "$errors" -gt 0 ]; then die "$errors problem(s) found"; fi
  log "doctor: no problems found"
}

# ----------------------------------------------------------------------------
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"; }

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  setup)      setup ;;
  doctor)     doctor ;;
  list)       list_phases ;;
  status)     [ $# -eq 1 ] || die 'usage: ./run_lab.sh status <slug>'; status "$1" ;;
  phase)      [ $# -eq 3 ] || die 'usage: ./run_lab.sh phase <id> <slug> "<topic>"'; run_phase "$@" ;;
  all)        [ $# -eq 2 ] || die 'usage: ./run_lab.sh all <slug> "<topic>"'; run_all "$@" ;;
  mcp)        mcp_setup "$@" ;;
  mcp-status) mcp_status ;;
  new-agent)  [ $# -eq 1 ] || die 'usage: ./run_lab.sh new-agent <name>'; new_agent "$1" ;;
  new-phase)  [ $# -eq 4 ] || die 'usage: ./run_lab.sh new-phase <order> <id> <name> <owner>'; new_phase "$@" ;;
  *)          usage ;;
esac
