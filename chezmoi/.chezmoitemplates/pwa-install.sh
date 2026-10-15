#!/usr/bin/env bash

# Installs PWAs as standalone apps with PWAsForFirefox, which runs them on a separate Firefox
# runtime with Widevine DRM. Every app goes into one dedicated PWAsForFirefox profile, so the DRM
# component is set up once; apps in that profile that are no longer listed get uninstalled.
# Idempotent: apps are matched to list entries by URL, and only missing ones are installed. The
# Windows counterpart is the WindowsWorkstationDSC pwa-install script.
#
# Usage: pwa-install.sh <json>, where <json> is an array of { url, name?, icon_url? } objects.
# Run by the pwas role of the macOS and Ubuntu Ansible playbooks, after Homebrew installs
# PWAsForFirefox and before the Dock pins. Exits non-zero when any app fails.

set -uo pipefail

PwasJson=${1:?usage: pwa-install.sh <json>}
ProfileName=pwas
# Some sites serve a stripped page (or no <link> tags) to unrecognized clients
UserAgent='Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0'

if [ "$(uname -s)" = Darwin ]; then
  UserDataDir="$HOME/Library/Application Support/firefoxpwa"
  RuntimeExe="$UserDataDir/runtime/Firefox.app"
else
  UserDataDir="${XDG_DATA_HOME:-$HOME/.local/share}/firefoxpwa"
  RuntimeExe="$UserDataDir/runtime/firefox"
fi
ConfigPath="$UserDataDir/config.json"

# Ansible's environment may predate Homebrew's shell setup
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"

if ! command -v firefoxpwa >/dev/null 2>&1; then
  echo "PWAsForFirefox (firefoxpwa) isn't installed" >&2
  exit 1
fi

# Runs firefoxpwa and prints its output without color codes; on failure, reports it on stderr.
firefoxpwa_quiet() {
  local output
  if ! output=$(firefoxpwa "$@" 2>&1); then
    printf 'firefoxpwa %s %s failed:\n%s\n' "$1" "$2" "$output" >&2
    return 1
  fi
  printf '%s\n' "$output" | sed $'s/\x1b\\[[0-9;]*m//g'
}

# PWAsForFirefox stores URLs normalized (lowercase host, trailing slash on a bare origin).
url_key() {
  printf '%s' "$1" | sed 's:/*$::' | tr '[:upper:]' '[:lower:]'
}

# Resolves an href against the page URL.
absolute_url() {
  local base=$1 href=$2 origin
  origin=$(printf '%s' "$base" | sed -E 's#^([a-z]+://[^/]+).*#\1#')
  case "$href" in
    http://* | https://*) printf '%s' "$href" ;;
    //*) printf 'https:%s' "$href" ;;
    /*) printf '%s%s' "$origin" "$href" ;;
    *) printf '%s/%s' "$(printf '%s' "$base" | sed 's:/[^/]*$::')" "$href" ;;
  esac
}

# Prints the href of the first <link> whose rel matches $2.
link_href() {
  printf '%s' "$1" | grep -oiE '<link[^>]*>' | grep -iE "rel=[\"']?$2([\"' >]|$)" | head -1 |
    grep -oiE "href=[\"'][^\"']+" | cut -c7-
}

# Prints the href of the largest icon the page declares. sizes="NxN" gives the size; an unsized
# apple-touch-icon is conventionally 180x180; other unsized icons (usually favicon.ico) rank last.
largest_icon_href() {
  printf '%s' "$1" | grep -oiE '<link[^>]*>' | grep -iE "rel=[\"']?[^\"'>]*icon" |
    while read -r link; do
      href=$(printf '%s' "$link" | grep -oiE "href=[\"'][^\"']+" | cut -c7-)
      [ -n "$href" ] || continue
      size=$(printf '%s' "$link" | grep -oiE "sizes=[\"']?[0-9]+x" | grep -oE '[0-9]+')
      if [ -z "$size" ]; then
        if printf '%s' "$link" | grep -qi apple-touch-icon; then size=180; else size=0; fi
      fi
      printf '%s\t%s\n' "$size" "$href"
    done | sort -s -rn -k1,1 | head -1 | cut -f2
}

# Finds the site's manifest the way the browser does: a <link rel="manifest"> in the page. Sites
# without one get a minimal manifest as a data: URL, which the CLI accepts with --document-url.
# Prints the manifest URL, then a line with the icon URL to use (empty for a real manifest).
resolve_manifest() {
  local url=$1 name=$2 html href icon manifest
  # Best-effort: bot checks (e.g. Cloudflare) can block a scripted fetch, which just means no
  # manifest or icon is found here; the app itself loads the page in a real browser engine.
  html=$(curl -fsSL -A "$UserAgent" --max-time 20 "$url" 2>/dev/null || true)

  href=$(link_href "$html" manifest)
  if [ -n "$href" ]; then
    absolute_url "$url" "$href"
    printf '\n\n'
    return
  fi

  href=$(largest_icon_href "$html")
  if [ -n "$href" ]; then
    icon=$(absolute_url "$url" "$href")
  else
    icon=$(absolute_url "$url" /favicon.ico)
  fi
  [ -n "$name" ] || name=$(printf '%s' "$url" | sed -E 's#^[a-z]+://([^/]+).*#\1#')
  manifest=$(jq -cn --arg name "$name" --arg url "$url" \
    '{name: $name, start_url: $url, scope: $url, display: "standalone"}')
  printf 'data:application/manifest+json;base64,%s\n%s\n' "$(printf '%s' "$manifest" | base64 | tr -d '\n')" "$icon"
}

if [ ! -e "$RuntimeExe" ]; then
  echo "Installing the PWAsForFirefox runtime..."
  firefoxpwa_quiet runtime install >/dev/null || exit 1
fi

profile_id() {
  [ -r "$ConfigPath" ] || return 0
  jq -r --arg name "$ProfileName" '[.profiles[] | select(.name == $name)][0].ulid // empty' "$ConfigPath"
}

ProfileId=$(profile_id)
if [ -z "$ProfileId" ]; then
  echo "Creating PWAsForFirefox profile '$ProfileName'..."
  output=$(firefoxpwa_quiet profile create --name "$ProfileName" --description 'PWAs managed by chezmoi') || exit 1
  ProfileId=$(printf '%s' "$output" | grep -oE 'Profile created: [0-9A-Z]{26}' | grep -oE '[0-9A-Z]{26}$')
  if [ -z "$ProfileId" ]; then
    printf "Couldn't find the profile ID in:\n%s\n" "$output" >&2
    exit 1
  fi
fi

# "<url key>\t<site id>" for each app already in the profile
installed=$(jq -r --arg profile "$ProfileId" \
  '.profiles[$profile].sites[]? as $id | .sites[$id] | "\(.config.document_url)\t\($id)"' "$ConfigPath" |
  while IFS=$'\t' read -r url id; do printf '%s\t%s\n' "$(url_key "$url")" "$id"; done)
wanted=$(printf '%s' "$PwasJson" | jq -r '.[].url' | while read -r url; do url_key "$url"; echo; done)

failed=0
changed=0

# Fields are split on the unit separator: tab is IFS whitespace, so empty fields would collapse.
while IFS=$'\x1f' read -r url name icon_url; do
  if printf '%s\n' "$installed" | cut -f1 | grep -qxF "$(url_key "$url")"; then
    continue
  fi
  changed=1
  echo "Installing $url..."
  { read -r manifest_url; read -r resolved_icon; } < <(resolve_manifest "$url" "$name")
  args=(site install "$manifest_url" --document-url "$url" --profile "$ProfileId")
  [ -n "$name" ] && args+=(--name "$name")
  icon=${icon_url:-$resolved_icon}
  [ -n "$icon" ] && args+=(--icon-url "$icon")
  firefoxpwa_quiet "${args[@]}" >/dev/null || failed=1
done < <(printf '%s' "$PwasJson" | jq -r '.[] | [.url, .name // "", .icon_url // ""] | join("\u001f")')

while IFS=$'\t' read -r key id; do
  [ -n "$key" ] || continue
  if printf '%s\n' "$wanted" | grep -qxF "$key"; then
    continue
  fi
  changed=1
  echo "Uninstalling $key (no longer listed)..."
  firefoxpwa_quiet site uninstall "$id" --quiet >/dev/null || failed=1
done <<< "$installed"

if [ "$changed" -eq 0 ]; then
  echo "All PWAs are already installed."
fi

# Non-zero fails the Ansible task, so the next apply reruns the playbook.
exit "$failed"
