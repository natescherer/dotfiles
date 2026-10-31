# Based on https://github.com/itzViking/vmware-wayland-clipboard at 04d9600, which
# writes with xclip. This writes with xsel, since vmware-user requests a TIMESTAMP
# target that xclip doesn't provide.
#
# MIT License
#
# Copyright (c) 2026
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


runtime="${XDG_RUNTIME_DIR:-/tmp}"
state="$runtime/vmware-wayland-clipboard.state"
lock="$runtime/vmware-wayland-clipboard.lock"
window_ms="${VMWARE_WAYLAND_CLIPBOARD_DEDUP_MS:-2000}"

exec 9>"$lock"
flock 9

tmp=$(mktemp "$runtime/vmware-wayland-clipboard.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# wl-paste --watch sends the selected clipboard representation to stdin.
cat > "$tmp"

# Preserve Dolphin/KDE file copy and cut operations.
#
# Dolphin advertises copied files as text/uri-list together with one or more
# KDE/portal-specific MIME types. If we republish that payload through xsel as
# plain text, the native file-copy semantics are lost and Dolphin may try to
# paste the URI/filename as text instead of copying the file.
#
# Require text/uri-list plus at least one KDE/portal marker so ordinary text
# clipboard entries are still bridged.
clipboard_types="$(wl-paste --list-types 2>/dev/null || true)"

if grep -Fxq 'text/uri-list' <<< "$clipboard_types" &&
   grep -Eq \
       '^(application/x-kde4-urilist|application/vnd\.portal\.filetransfer|application/x-kde-source-id)$' \
       <<< "$clipboard_types"; then
    exit 0
fi

hash=$(sha256sum "$tmp" | awk '{print $1}')
now=$(date +%s%3N)

oldhash=""
oldtime=0

if [[ -r "$state" ]]; then
    read -r oldhash oldtime < "$state" || true
fi

# KWin/XWayland may reflect the clipboard we just pushed into X11 back into
# Wayland. Ignore an identical value if it comes back within the de-duplication
# window, otherwise wl-paste --watch can react to its own update.
if [[ "$hash" == "$oldhash" ]] && (( now - oldtime < window_ms )); then
    exit 0
fi

printf '%s %s\n' "$hash" "$now" > "$state"

# xsel daemonizes so it can remain the X11 clipboard owner. Release and close
# our lock first, otherwise the background xsel process inherits FD 9 and can
# keep the lock indefinitely, blocking later clipboard updates.
flock -u 9
exec 9>&-

xsel --clipboard --input < "$tmp"