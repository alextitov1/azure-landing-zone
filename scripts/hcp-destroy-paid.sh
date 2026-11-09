#!/usr/bin/env bash

# Destroys the resources tagged cost=paid in the HCP Terraform workspaces of the organization, with a targeted destroy
# run in each workspace. Runs go through the HCP API rather than `terraform destroy`: HCP refuses CLI applies on
# VCS-connected workspaces, and only remote runs have the workspaces' Azure credentials. See README.md.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ./hcp-destroy-paid.sh [--list] [--yes] [--tag <key>=<value>] [<workspace>...]
  --list         list the tagged resources only; start no runs
  --yes          apply each destroy run without asking
  --tag k=v      the tag that marks the resources; default cost=paid
  <workspace>    only these workspaces; default all in the organization
Environment: HCP_TOKEN_REF, the op:// reference of the HCP API token
EOF
  exit "${1:-2}"
}

HCP_TOKEN_REF="${HCP_TOKEN_REF:-op://IT/terraform_hcp_4esnok_tier0/credential}"
HOST=app.terraform.io
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG="$(sed -n 's/^organization:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$REPO_ROOT/HCP/config.yaml")"

list_only=false
assume_yes=false
tag_key=cost
tag_value=paid
selected=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --list) list_only=true ;;
    --yes) assume_yes=true ;;
    --tag)
      [[ ${2:-} == ?*=* ]] || usage
      tag_key=${2%%=*}
      tag_value=${2#*=}
      shift
      ;;
    -h | --help) usage 0 ;;
    -*) usage ;;
    *) selected="$selected $1" ;;
  esac
  shift
done

for cmd in op jq curl; do
  command -v "$cmd" >/dev/null || { echo "$cmd not found" >&2; exit 1; }
done
[[ -n $ORG ]] || { echo "No organization in $REPO_ROOT/HCP/config.yaml" >&2; exit 1; }

TOKEN=$(op read "$HCP_TOKEN_REF")

# api <method> <path or URL> [<JSON body>]
# The token reaches curl through a file descriptor rather than its arguments, which other local users can see in ps.
# Redirects are followed for the state and plan downloads; curl drops the header if one leaves the host.
api() {
  local url=$2
  local args=(--request "$1")
  [[ $url == https://* ]] || url="https://$HOST/api/v2$url"
  if [[ $# -ge 3 ]]; then args+=(--data-binary "$3"); fi
  curl --silent --show-error --fail-with-body --location \
    --header @<(printf 'Authorization: Bearer %s\n' "$TOKEN") \
    --header 'Content-Type: application/vnd.api+json' \
    "${args[@]}" "$url"
}

# Bash clears `set -e` inside command substitutions, so functions called as $(...) check each call themselves.

# One line per workspace: id, name, execution mode, current state version ("-" if none)
list_workspaces() {
  local page=1 res
  while [[ -n $page ]]; do
    res=$(api GET "/organizations/$ORG/workspaces?page%5Bsize%5D=100&page%5Bnumber%5D=$page") || return 1
    jq -r '.data[] | [.id, .attributes.name, .attributes["execution-mode"],
      (.relationships["current-state-version"].data.id // "-")] | @tsv' <<<"$res"
    page=$(jq -r '.meta.pagination["next-page"] // empty' <<<"$res")
  done
}

# Waits until the run needs confirmation or has finished; prints "confirmable" or the final status
wait_run() {
  local run status last=""
  while :; do
    run=$(api GET "/runs/$1") || return 1
    status=$(jq -r .data.attributes.status <<<"$run")
    if [[ $status != "$last" ]]; then
      echo "   $status" >&2
      last=$status
    fi
    if [[ $(jq -r '.data.attributes.actions["is-confirmable"]' <<<"$run") == true ]]; then
      echo confirmable
      return
    fi
    case $status in
      applied | planned_and_finished | errored | discarded | canceled | force_canceled)
        echo "$status"
        return
        ;;
    esac
    sleep 5
  done
}

# A run waiting for an answer blocks every later run of its workspace, so one left behind by an error or Ctrl-C
# is discarded, or canceled while it is still planning. A run already applying is left to finish.
run_id=""
# shellcheck disable=SC2329 # called by the trap
cleanup() {
  if [[ -n $run_id ]]; then
    echo "   stopped: discarding $run_id" >&2
    api POST "/runs/$run_id/actions/discard" '{"comment": "hcp-destroy-paid.sh stopped"}' >/dev/null 2>&1 ||
      api POST "/runs/$run_id/actions/cancel" '{"comment": "hcp-destroy-paid.sh stopped"}' >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

failed=0

# destroy <workspace id> <workspace name> <JSON array of addresses>
destroy() {
  local body status answer=""

  # auto-apply false: the workspaces auto-apply, and API runs follow the workspace setting unless told otherwise
  body=$(jq -n --arg ws "$1" --argjson targets "$3" \
    --arg message "Destroy resources tagged $tag_key=$tag_value (scripts/hcp-destroy-paid.sh)" \
    '{data: {type: "runs",
      attributes: {"is-destroy": true, "target-addrs": $targets, "auto-apply": false, message: $message},
      relationships: {workspace: {data: {type: "workspaces", id: $ws}}}}}')
  run_id=$(api POST /runs "$body" | jq -r .data.id)
  echo "   run https://$HOST/app/$ORG/workspaces/$2/runs/$run_id"

  status=$(wait_run "$run_id")
  if [[ $status != confirmable ]]; then
    run_id=""
    if [[ $status != planned_and_finished ]]; then failed=1; fi
    return
  fi

  # Targets plus everything that depends on them, which Terraform destroys too
  echo "   plan destroys:"
  api GET "/runs/$run_id/plan/json-output" |
    jq -r '.resource_changes[]? | select(.change.actions | index("delete")) | "     " + .address'

  if ! $assume_yes; then
    read -r -p "   Destroy them in $2? [y/N] " answer </dev/tty || answer=""
    if [[ $answer != [yY]* ]]; then
      api POST "/runs/$run_id/actions/discard" '{"comment": "Declined in hcp-destroy-paid.sh"}' >/dev/null
      echo "   discarded"
      run_id=""
      return
    fi
  fi

  api POST "/runs/$run_id/actions/apply" '{"comment": "hcp-destroy-paid.sh"}' >/dev/null
  local applying=$run_id
  run_id=""
  status=$(wait_run "$applying")
  if [[ $status != applied ]]; then failed=1; fi
}

# Managed resources whose tags match, with their full addresses. The state holds secrets (e.g. generated passwords),
# so it goes straight from curl to jq and only addresses come out.
# shellcheck disable=SC2016 # $key and $value are jq variables
TAGGED='def modules: ., (.child_modules[]? | modules);
  [.values.root_module // {} | modules | .resources[]?
    | select(.mode == "managed" and ((.values.tags? // {})[$key]? == $value)) | .address]'

workspaces=$(list_workspaces)
seen=""
echo "Resources tagged $tag_key=$tag_value in $ORG"
while IFS=$'\t' read -r ws_id name mode sv_id; do
  [[ -n $ws_id ]] || continue
  if [[ -n $selected && " $selected " != *" $name "* ]]; then continue; fi
  seen="$seen $name"
  echo "== $name"

  if [[ $mode == local ]]; then
    echo "   skipped: local execution, HCP can't run it"
    continue
  fi
  if [[ $sv_id == - ]]; then
    echo "   no state"
    continue
  fi

  sv=$(api GET "/state-versions/$sv_id")
  json_url=$(jq -r '.data.attributes["hosted-json-state-download-url"] // empty' <<<"$sv")
  if [[ $(jq -r '.data.attributes["resources-processed"]' <<<"$sv") != true || -z $json_url ]]; then
    echo "   skipped: HCP hasn't processed the latest state yet; try again in a minute"
    failed=1
    continue
  fi

  targets=$(api GET "$json_url" | jq -c --arg key "$tag_key" --arg value "$tag_value" "$TAGGED")
  if [[ $targets == "[]" ]]; then
    echo "   nothing tagged"
    continue
  fi
  jq -r '.[] | "   " + .' <<<"$targets"

  if ! $list_only; then destroy "$ws_id" "$name" "$targets"; fi
done <<<"$workspaces"

for name in $selected; do
  if [[ " $seen " != *" $name "* ]]; then
    echo "No workspace $name in $ORG" >&2
    failed=1
  fi
done

exit "$failed"
