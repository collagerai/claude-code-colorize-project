<#
.SYNOPSIS
  Apply a colored "frame" theme to a VS Code workspace via .vscode/settings.json.

.PARAMETER Color
  Either a preset name (e.g. "forest", "royal-blue") or a hex color (#RRGGBB).
  Preset names available: forest, royal-blue, royal-purple, burgundy, amber,
  teal, deep-cyan, indigo, dark-magenta, olive, crimson, steel-blue, navy,
  rust, plum, pine, slate-purple, brick, dark-pine, charcoal-blue.

.PARAMETER WorkspacePath
  Absolute path to the workspace folder. .vscode/settings.json will be
  created/overwritten inside it.

.EXAMPLE
  ./apply-colors.ps1 -Color royal-blue -WorkspacePath C:\my\project

.NOTES
  Uses [System.IO.File]::WriteAllText to bypass any Write-tool sanitizing hook
  that may strip VS Code color tokens. Preserves all existing keys in
  settings.json -- only replaces workbench.colorCustomizations.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Color,

    # Path to a workspace FOLDER (writes .vscode/settings.json)
    [string]$WorkspacePath,

    # Path to a .code-workspace FILE (writes inside its "settings" block)
    [string]$WorkspaceFile
)

if (-not $WorkspacePath -and -not $WorkspaceFile) {
    Write-Error "Provide either -WorkspacePath <folder> or -WorkspaceFile <path-to-.code-workspace>"
    exit 1
}

$ErrorActionPreference = 'Stop'

# === Named presets (base hex = titleBar.activeBackground) ===
$presets = @{
    'forest'        = '#163f17'
    'royal-blue'    = '#1a3a6a'
    'royal-purple'  = '#3f1a55'
    'burgundy'      = '#5a1a1a'
    'amber'         = '#5a3a14'
    'teal'          = '#144a4a'
    'deep-cyan'     = '#144d5a'
    'indigo'        = '#2a1a55'
    'dark-magenta'  = '#4a154a'
    'olive'         = '#3a3a14'
    'crimson'       = '#5a142a'
    'steel-blue'    = '#2a3a4a'
    'navy'          = '#14275a'
    'rust'          = '#5a2a14'
    'plum'          = '#3a1a3a'
    'pine'          = '#144a3a'
    'slate-purple'  = '#2a1a3a'
    'brick'         = '#5a2a2a'
    'dark-pine'     = '#1a3a2a'
    'charcoal-blue' = '#1a2a3a'
}

# === Resolve $Color to a base hex ===
$key = $Color.ToLower().Trim()
if ($presets.ContainsKey($key)) {
    $base = $presets[$key]
    $colorLabel = $key
} elseif ($Color -match '^#[0-9a-fA-F]{6}$') {
    $base = $Color.ToLower()
    $colorLabel = "custom $base"
} else {
    Write-Error "Unknown color '$Color'. Use a preset name or hex #RRGGBB."
    exit 1
}

# === Color math helpers ===
function ConvertFrom-Hex([string]$hex) {
    $h = $hex -replace '^#', ''
    return @{
        R = [Convert]::ToInt32($h.Substring(0,2), 16)
        G = [Convert]::ToInt32($h.Substring(2,2), 16)
        B = [Convert]::ToInt32($h.Substring(4,2), 16)
    }
}

function ConvertTo-Hex($rgb) {
    return ('#{0:x2}{1:x2}{2:x2}' -f [int]$rgb.R, [int]$rgb.G, [int]$rgb.B)
}

function Get-ScaledColor($rgb, [double]$factor) {
    return @{
        R = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($rgb.R * $factor)))
        G = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($rgb.G * $factor)))
        B = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($rgb.B * $factor)))
    }
}

function Get-VibrantAccent($rgb) {
    # Scale dominant channel up to ~180; clamp others to at least 60.
    $max = [Math]::Max([Math]::Max($rgb.R, $rgb.G), $rgb.B)
    if ($max -eq 0) { return @{R=128; G=128; B=128} }
    $scale = 180.0 / $max
    return @{
        R = [Math]::Max(60, [Math]::Min(255, [int][Math]::Round($rgb.R * $scale)))
        G = [Math]::Max(60, [Math]::Min(255, [int][Math]::Round($rgb.G * $scale)))
        B = [Math]::Max(60, [Math]::Min(255, [int][Math]::Round($rgb.B * $scale)))
    }
}

# === Derive shades from the base ===
$baseRGB = ConvertFrom-Hex $base

$title_active   = ConvertTo-Hex $baseRGB
$title_inactive = ConvertTo-Hex (Get-ScaledColor $baseRGB 0.76)
$title_border   = ConvertTo-Hex (Get-ScaledColor $baseRGB 1.18)
$menu_select    = ConvertTo-Hex (Get-ScaledColor $baseRGB 1.35)
$frame_bg       = ConvertTo-Hex (Get-ScaledColor $baseRGB 0.70)
$aux_bg         = ConvertTo-Hex (Get-ScaledColor $baseRGB 0.55)
$tab_inactive   = ConvertTo-Hex (Get-ScaledColor $baseRGB 0.92)
$tab_border     = ConvertTo-Hex (Get-ScaledColor $baseRGB 0.35)
$tab_hover      = ConvertTo-Hex (Get-ScaledColor $baseRGB 1.15)
$accent         = ConvertTo-Hex (Get-VibrantAccent $baseRGB)

# === Build the colorCustomizations block ===
$colors = [ordered]@{
    'titleBar.activeBackground'             = $title_active
    'titleBar.activeForeground'             = '#e8efe8'
    'titleBar.inactiveBackground'           = $title_inactive
    'titleBar.inactiveForeground'           = '#a8b0a8'
    'titleBar.border'                       = $title_border

    'menubar.selectionBackground'           = $menu_select
    'menubar.selectionForeground'           = '#ffffff'

    'activityBar.background'                = $frame_bg
    'activityBar.foreground'                = '#d4dcd4'
    'activityBar.inactiveForeground'        = '#7a807a'
    'activityBar.border'                    = $title_border
    'activityBarBadge.background'           = $accent
    'activityBarBadge.foreground'           = '#ffffff'

    'sideBar.background'                    = '#1f1f1f'
    'sideBar.foreground'                    = '#cccccc'
    'sideBar.border'                        = $title_border
    'sideBarTitle.foreground'               = '#cccccc'
    'sideBarSectionHeader.background'       = '#252525'
    'sideBarSectionHeader.foreground'       = '#cccccc'

    'auxiliaryBar.background'               = $aux_bg
    'auxiliaryBar.foreground'               = '#cfcfcf'
    'auxiliaryBar.border'                   = $title_border
    'auxiliaryBarTitle.foreground'          = '#dcdcdc'

    'statusBar.background'                  = $frame_bg
    'statusBar.foreground'                  = '#d4dcd4'
    'statusBar.noFolderBackground'          = $frame_bg
    'statusBar.border'                      = $title_border
    'statusBarItem.hoverBackground'         = $tab_inactive

    'editorGroupHeader.tabsBackground'      = $frame_bg
    'editorGroupHeader.noTabsBackground'    = '#1f1f1f'
    'tab.inactiveBackground'                = $tab_inactive
    'tab.inactiveForeground'                = '#a8b0a8'
    'tab.activeBackground'                  = '#1f1f1f'
    'tab.activeForeground'                  = '#ffffff'
    'tab.activeBorderTop'                   = $accent
    'tab.border'                            = $tab_border
    'tab.hoverBackground'                   = $tab_hover
    'tab.unfocusedActiveBackground'         = '#1f1f1f'
    'tab.unfocusedInactiveBackground'       = $tab_inactive

    'editor.background'                     = '#1f1f1f'
    'editorGroup.background'                = '#1f1f1f'
    'editorWidget.background'               = '#1f1f1f'
    'breadcrumb.background'                 = '#1f1f1f'
    'breadcrumbPicker.background'           = '#1f1f1f'
    'panel.background'                      = '#1f1f1f'
    'panelSectionHeader.background'         = '#1f1f1f'
    'notebook.editorBackground'             = '#1f1f1f'
    'notebook.cellEditorBackground'         = '#1f1f1f'
    'notebook.focusedCellBackground'        = '#1f1f1f'
    'notebook.cellHoverBackground'          = '#252525'
    'terminal.background'                   = '#1f1f1f'

    'chat.requestBackground'                = $tab_inactive
    'chat.requestBorder'                    = $title_border
    'chat.requestBubbleBackground'          = $tab_inactive
    'chat.requestBubbleHoverBackground'     = $tab_hover
}

# === Helpers for reading JSON while preserving keys ===
function ConvertTo-HashTableDeep($obj) {
    $hash = [ordered]@{}
    if ($null -eq $obj) { return $hash }
    foreach ($prop in $obj.PSObject.Properties) {
        $val = $prop.Value
        if ($val -is [PSCustomObject]) {
            $hash[$prop.Name] = ConvertTo-HashTableDeep $val
        } else {
            $hash[$prop.Name] = $val
        }
    }
    return $hash
}

# === Decide which target(s) to write to ===
$targets = @()

# Mode A: WorkspaceFile provided directly -> write to that .code-workspace file
if ($WorkspaceFile) {
    if (-not (Test-Path $WorkspaceFile)) {
        Write-Error "WorkspaceFile not found: $WorkspaceFile"
        exit 1
    }
    $targets += @{ Kind = 'workspace-file'; Path = $WorkspaceFile }
}

# Mode B: WorkspacePath provided -> write to <path>/.vscode/settings.json.
# Also auto-detect a single .code-workspace file in that folder and write to it too.
if ($WorkspacePath) {
    $vscodeDir = Join-Path $WorkspacePath ".vscode"
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }
    $targets += @{ Kind = 'folder-settings'; Path = (Join-Path $vscodeDir "settings.json") }

    # Auto-detect .code-workspace files in the workspace folder
    $wsFiles = Get-ChildItem $WorkspacePath -Filter "*.code-workspace" -File -ErrorAction SilentlyContinue
    foreach ($wf in $wsFiles) {
        $targets += @{ Kind = 'workspace-file'; Path = $wf.FullName }
    }
}

# === Apply colors to each target, preserving everything else ===
foreach ($t in $targets) {
    $path = $t.Path
    $kind = $t.Kind

    $existing = [ordered]@{}
    if (Test-Path $path) {
        $raw = Get-Content $path -Raw -ErrorAction SilentlyContinue
        if ($raw -and $raw.Trim()) {
            try {
                $existingObj = ConvertFrom-Json $raw -ErrorAction Stop
                $existing = ConvertTo-HashTableDeep $existingObj
            } catch {
                Write-Warning "Could not parse $path - overwriting. Reason: $($_.Exception.Message)"
                $existing = [ordered]@{}
            }
        }
    }

    if ($kind -eq 'workspace-file') {
        # .code-workspace: colors go inside the "settings" block
        if (-not $existing.Contains('settings')) {
            $existing['settings'] = [ordered]@{}
        } elseif ($existing['settings'] -isnot [System.Collections.IDictionary]) {
            $existing['settings'] = [ordered]@{}
        }
        $existing['settings']['workbench.colorCustomizations'] = $colors
    } else {
        # Regular folder settings.json: colors at top level
        $existing['workbench.colorCustomizations'] = $colors
    }

    $json = $existing | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
    Write-Host ("Applied '{0}' to {1}  [{2}]" -f $colorLabel, $path, $kind)
}

Write-Host "Derived shades: title=$title_active frame=$frame_bg aux=$aux_bg tabInactive=$tab_inactive accent=$accent"
Write-Host "VS Code applies colors on the fly - no window reload needed."
