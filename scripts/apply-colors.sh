#!/usr/bin/env bash
# apply-colors.sh — macOS / Linux equivalent of apply-colors.ps1
#
# Paint VS Code window chrome in a chosen color by writing
# workbench.colorCustomizations into <workspace>/.vscode/settings.json
# and/or into the "settings" block of any .code-workspace file in that folder.
#
# Usage:
#   apply-colors.sh --color <name|hex> --workspace-path <folder>
#   apply-colors.sh --color <name|hex> --workspace-file <path.code-workspace>
#   apply-colors.sh --color <name|hex> --workspace-path <folder> --workspace-file <file>
#
# Requirements: bash, python3 (preinstalled on macOS and most Linux distros).

set -euo pipefail

COLOR=""
WORKSPACE_PATH=""
WORKSPACE_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --color|-c) COLOR="$2"; shift 2 ;;
        --workspace-path|-w) WORKSPACE_PATH="$2"; shift 2 ;;
        --workspace-file|-f) WORKSPACE_FILE="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$COLOR" ]]; then
    echo "Error: --color is required (preset name or #RRGGBB)" >&2
    exit 1
fi
if [[ -z "$WORKSPACE_PATH" && -z "$WORKSPACE_FILE" ]]; then
    echo "Error: pass --workspace-path <folder> or --workspace-file <.code-workspace>" >&2
    exit 1
fi

# All the work — color math, JSON merge, file write — happens in Python.
# Bash here is just an arg parser and dispatcher.
python3 - "$COLOR" "$WORKSPACE_PATH" "$WORKSPACE_FILE" <<'PYEOF'
import sys, os, json, glob
from collections import OrderedDict

color_arg, workspace_path, workspace_file = sys.argv[1], sys.argv[2], sys.argv[3]

PRESETS = {
    "forest":        "#163f17",
    "royal-blue":    "#1a3a6a",
    "royal-purple":  "#3f1a55",
    "burgundy":      "#5a1a1a",
    "amber":         "#5a3a14",
    "teal":          "#144a4a",
    "deep-cyan":     "#144d5a",
    "indigo":        "#2a1a55",
    "dark-magenta":  "#4a154a",
    "olive":         "#3a3a14",
    "crimson":       "#5a142a",
    "steel-blue":    "#2a3a4a",
    "navy":          "#14275a",
    "rust":          "#5a2a14",
    "plum":          "#3a1a3a",
    "pine":          "#144a3a",
    "slate-purple":  "#2a1a3a",
    "brick":         "#5a2a2a",
    "dark-pine":     "#1a3a2a",
    "charcoal-blue": "#1a2a3a",
}

# Resolve color name -> base hex
key = color_arg.strip().lower()
if key in PRESETS:
    base = PRESETS[key]
    label = key
elif len(color_arg) == 7 and color_arg.startswith("#"):
    try:
        int(color_arg[1:], 16)
        base = color_arg.lower()
        label = f"custom {base}"
    except ValueError:
        print(f"Unknown color '{color_arg}'. Use a preset name or #RRGGBB.", file=sys.stderr)
        sys.exit(1)
else:
    print(f"Unknown color '{color_arg}'. Use a preset name or #RRGGBB.", file=sys.stderr)
    sys.exit(1)

# Color math (identical to PowerShell version)
def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def rgb_to_hex(rgb):
    r, g, b = rgb
    return "#{:02x}{:02x}{:02x}".format(int(r), int(g), int(b))

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(round(v))))

def scale(rgb, factor):
    return (clamp(rgb[0] * factor), clamp(rgb[1] * factor), clamp(rgb[2] * factor))

def vibrant(rgb):
    m = max(rgb)
    if m == 0:
        return (128, 128, 128)
    s = 180.0 / m
    return (clamp(rgb[0] * s, lo=60), clamp(rgb[1] * s, lo=60), clamp(rgb[2] * s, lo=60))

br = hex_to_rgb(base)
title_active   = rgb_to_hex(br)
title_inactive = rgb_to_hex(scale(br, 0.76))
title_border   = rgb_to_hex(scale(br, 1.18))
menu_select    = rgb_to_hex(scale(br, 1.35))
frame_bg       = rgb_to_hex(scale(br, 0.70))
aux_bg         = rgb_to_hex(scale(br, 0.55))
tab_inactive   = rgb_to_hex(scale(br, 0.92))
tab_border     = rgb_to_hex(scale(br, 0.35))
tab_hover      = rgb_to_hex(scale(br, 1.15))
accent         = rgb_to_hex(vibrant(br))

colors = OrderedDict([
    ("titleBar.activeBackground",             title_active),
    ("titleBar.activeForeground",             "#e8efe8"),
    ("titleBar.inactiveBackground",           title_inactive),
    ("titleBar.inactiveForeground",           "#a8b0a8"),
    ("titleBar.border",                       title_border),
    ("menubar.selectionBackground",           menu_select),
    ("menubar.selectionForeground",           "#ffffff"),
    ("activityBar.background",                frame_bg),
    ("activityBar.foreground",                "#d4dcd4"),
    ("activityBar.inactiveForeground",        "#7a807a"),
    ("activityBar.border",                    title_border),
    ("activityBarBadge.background",           accent),
    ("activityBarBadge.foreground",           "#ffffff"),
    ("sideBar.background",                    "#1f1f1f"),
    ("sideBar.foreground",                    "#cccccc"),
    ("sideBar.border",                        title_border),
    ("sideBarTitle.foreground",               "#cccccc"),
    ("sideBarSectionHeader.background",       "#252525"),
    ("sideBarSectionHeader.foreground",       "#cccccc"),
    ("auxiliaryBar.background",               aux_bg),
    ("auxiliaryBar.foreground",               "#cfcfcf"),
    ("auxiliaryBar.border",                   title_border),
    ("auxiliaryBarTitle.foreground",          "#dcdcdc"),
    ("statusBar.background",                  frame_bg),
    ("statusBar.foreground",                  "#d4dcd4"),
    ("statusBar.noFolderBackground",          frame_bg),
    ("statusBar.border",                      title_border),
    ("statusBarItem.hoverBackground",         tab_inactive),
    ("editorGroupHeader.tabsBackground",      frame_bg),
    ("editorGroupHeader.noTabsBackground",    "#1f1f1f"),
    ("tab.inactiveBackground",                tab_inactive),
    ("tab.inactiveForeground",                "#a8b0a8"),
    ("tab.activeBackground",                  "#1f1f1f"),
    ("tab.activeForeground",                  "#ffffff"),
    ("tab.activeBorderTop",                   accent),
    ("tab.border",                            tab_border),
    ("tab.hoverBackground",                   tab_hover),
    ("tab.unfocusedActiveBackground",         "#1f1f1f"),
    ("tab.unfocusedInactiveBackground",       tab_inactive),
    ("editor.background",                     "#1f1f1f"),
    ("editorGroup.background",                "#1f1f1f"),
    ("editorWidget.background",               "#1f1f1f"),
    ("breadcrumb.background",                 "#1f1f1f"),
    ("breadcrumbPicker.background",           "#1f1f1f"),
    ("panel.background",                      "#1f1f1f"),
    ("panelSectionHeader.background",         "#1f1f1f"),
    ("notebook.editorBackground",             "#1f1f1f"),
    ("notebook.cellEditorBackground",         "#1f1f1f"),
    ("notebook.focusedCellBackground",        "#1f1f1f"),
    ("notebook.cellHoverBackground",          "#252525"),
    ("terminal.background",                   "#1f1f1f"),
    ("chat.requestBackground",                tab_inactive),
    ("chat.requestBorder",                    title_border),
    ("chat.requestBubbleBackground",          tab_inactive),
    ("chat.requestBubbleHoverBackground",     tab_hover),
])

# Decide targets
targets = []
if workspace_file:
    if not os.path.isfile(workspace_file):
        print(f"WorkspaceFile not found: {workspace_file}", file=sys.stderr)
        sys.exit(1)
    targets.append(("workspace-file", workspace_file))

if workspace_path:
    vscode_dir = os.path.join(workspace_path, ".vscode")
    os.makedirs(vscode_dir, exist_ok=True)
    targets.append(("folder-settings", os.path.join(vscode_dir, "settings.json")))
    for wf in glob.glob(os.path.join(workspace_path, "*.code-workspace")):
        targets.append(("workspace-file", wf))

# Apply to each target, preserving existing keys
for kind, path in targets:
    existing = OrderedDict()
    if os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read().strip()
            if raw:
                existing = json.loads(raw, object_pairs_hook=OrderedDict)
        except json.JSONDecodeError as e:
            print(f"Warning: could not parse {path} - overwriting. Reason: {e}", file=sys.stderr)
            existing = OrderedDict()

    if kind == "workspace-file":
        settings = existing.get("settings")
        if not isinstance(settings, OrderedDict) and not isinstance(settings, dict):
            settings = OrderedDict()
        settings["workbench.colorCustomizations"] = colors
        existing["settings"] = settings
    else:
        existing["workbench.colorCustomizations"] = colors

    with open(path, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Applied '{label}' to {path}  [{kind}]")

print(f"Derived shades: title={title_active} frame={frame_bg} aux={aux_bg} tabInactive={tab_inactive} accent={accent}")
print("VS Code applies colors on the fly - no window reload needed.")
PYEOF
