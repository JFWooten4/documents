#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
source_script="$script_dir/Convert DOCX and Publish.applescript"
app_dir="$HOME/Applications"
app_path="$app_dir/Convert DOCX & Publish.app"

fail() {
  print -u2 -- "$1"
  exit 1
}

[[ -f "$source_script" ]] || fail "AppleScript launcher is missing: $source_script"

mkdir -p "$app_dir"
rm -rf -- "$app_path"

# Compile the existing launcher into a normal macOS application bundle.
/usr/bin/osacompile -o "$app_path" "$source_script"

# Reuse the icon from an installed copy of Agenda.
agenda_app=""
for candidate in "/Applications/Agenda.app" "$HOME/Applications/Agenda.app"; do
  if [[ -d "$candidate" ]]; then
    agenda_app="$candidate"
    break
  fi
done

if [[ -n "$agenda_app" ]]; then
  icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$agenda_app/Contents/Info.plist" 2>/dev/null || true)"
  [[ -z "$icon_name" || "$icon_name" == *.icns ]] || icon_name="$icon_name.icns"

  agenda_icon=""
  if [[ -n "$icon_name" && -f "$agenda_app/Contents/Resources/$icon_name" ]]; then
    agenda_icon="$agenda_app/Contents/Resources/$icon_name"
  else
    agenda_icon="$(find "$agenda_app/Contents/Resources" -maxdepth 1 -type f -name '*.icns' -print -quit 2>/dev/null || true)"
  fi

  if [[ -n "$agenda_icon" && -f "$agenda_icon" ]]; then
    # osacompile applications use applet.icns by default, so replacing it
    # preserves the bundle metadata while giving the launcher Agenda's icon.
    cp -- "$agenda_icon" "$app_path/Contents/Resources/applet.icns"
  else
    print -u2 -- "Warning: Agenda was found, but its .icns file could not be located."
  fi
else
  print -u2 -- "Warning: Agenda.app was not found; keeping the default app icon."
fi

# The icon replacement changes the compiled bundle, so ad-hoc sign it again.
/usr/bin/codesign --force --deep --sign - "$app_path" >/dev/null 2>&1 || true
/usr/bin/touch "$app_path"
/usr/bin/open -R "$app_path"

print -- "Created $app_path"
