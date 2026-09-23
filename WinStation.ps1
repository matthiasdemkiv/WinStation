#requires -Version 5.1
<#
.SYNOPSIS
WinStation setup wizard.
.DESCRIPTION
Self-contained interactive workstation setup script.
-NoAnimation uses static display. -WhatIf performs the existing software audit.
-InstallAll retains the original unattended software-installation behavior.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [switch]$InstallAll,
    [switch]$NoAnimation
)

$ErrorActionPreference = 'Stop'

# ========================= EMBEDDED TERMINAL ART ========================
$pixels = @(
    '................HHR.............'
    '.............HRRRRRRR...........'
    '...........RRRRRRRRRRR..........'
    '.........GHHRRRRRRRRRRRG........'
    '.......GGGGGRRRRYRRRRGGGGG......'
    '.......GCCCGGYYCCCYYGGCCCG......'
    '......GGCMMYYYYCCCYYYYMMCGG.....'
    '....RHRGGMYYYYYYYYYGGGGMGGRR....'
    '....RHRGGGGGGGYYYYYYYYYGGGRR....'
    '....RRRRRGWWKKYYYYYWWKKGRRRR....'
    '...MMMRRRYWWKKYYYYYWWKKYRRRMMM..'
    '...MMMRRGGKKKKYYYYYKKKKGGRRMMM..'
    '...MMMRRRGKKKCCYYYCKKKCGRRRMMM..'
    '.....MRRRGYYCCCKKKCCCYYGRRRM....'
    '.....MMRRGGCCCCCKCCCCCGGRRMM....'
    '......MRRRGGCGCCCCCGCGGRRRM.....'
    '......MMRRRGGGGGGGGGGGRRRMM.....'
    '...RRRMMMRRRGGGGGGGGGRRRMM......'
    '...RRRM.MRRRRRRRGRRRRRRRM.......'
    '...MMMM..MMMMMMMRMMMMMMM........'
    '....GG...GGMMMMMMMMMMMGG........'
    '....GG..GGGYYCCCMCCCYYGGG.......'
    '....GG...GYYYYCCCCCYYYYG........'
    '....GGGGGGYYYYCCCCCYYYYG........'
    '.....GGGGGYYYYYCCCYYYYY.........'
    '.......GGGCCCCCYCYCCCCCGGGG.....'
    '.......GGGYGYGY.Y.YGYGYGGGG.....'
    '.....SSSSSSSSSSSSSSSSSSSSSSS....'
    '................S...............'
)

$rgb = @{
    M = '102;24;42'     # Burgundy shadow
    R = '210;51;65'     # Crimson mane
    H = '248;109;91'    # Coral highlights
    G = '184;114;53'    # Warm fur shadow
    Y = '238;184;98'    # Honey
    C = '255;225;175'   # Cream muzzle
    K = '38;25;32'      # Soft near-black
    W = '255;249;235'   # Eye sparkle
    S = '55;44;47'      # Ground shadow
}
$fallback = @{
    M='DarkRed'; R='Red'; H='Red'; G='DarkYellow'; Y='Yellow'
    C='Gray'; K='Black'; W='White'; S='DarkGray'
}
$esc = [string][char]27

# Replace control characters (and optionally ANSI sequences) so text stays on one line.
function ConvertTo-SafeText([string]$Text, [switch]$StripAnsi) {
    $pattern = if ($StripAnsi) { '\x1b\[[0-?]*[ -/]*[@-~]|[\x00-\x1f\x7f]' } else { '[\x00-\x1f\x7f]' }
    [regex]::Replace($Text, $pattern, ' ')
}

function Get-SceneFrame {
    param([int]$Tick = 0)
    $cells = @(foreach ($row in $pixels) { ,$row.ToCharArray() })
    $blink = $false
    $half = $false
    $wink = $false
    $tailActive = $false
    $tailStep = 0
    switch ($AnimationMode) {
        'Welcome' {
            $blink = $Tick -in @(22,23)
            $half = $Tick -in @(21,24)
            $tailActive = $Tick -ge 14 -and $Tick -lt 29
            $tailStep = [int][Math]::Floor(($Tick - 14) / 2)
        }
        'Goodbye' {
            $wink = $true
            $blink = $Tick -ge 10 -and $Tick -le 14
            $half = $Tick -in @(9,15)
            $tailActive = $Tick -ge 3 -and $Tick -lt 23
            $tailStep = [int][Math]::Floor($Tick / 4)
        }
    }
    if ($blink -or $half) {
        $eyes = if ($wink) { @(19) } else { @(10,19) }
        foreach ($start in $eyes) {
            for ($y = 9; $y -le 12; $y++) {
                for ($x = $start; $x -lt $start + 4; $x++) {
                    if ($blink) {
                        $cells[$y][$x] = if ($y -eq 11) { 'K' } else { 'Y' }
                    } elseif ($y -le 10) {
                        $cells[$y][$x] = 'Y'
                    }
                }
            }
        }
    }
    if ($tailActive) {
        $offset = @(0,-1,-2,-1,0,1,0)[$tailStep % 7]
        for ($y = 16; $y -le 22; $y++) {
            for ($x = 0; $x -lt 6; $x++) { $cells[$y][$x] = '.' }
            if ($y -ge 20) {
                $stem = if ($y -eq 20) { 4 + $offset } else { 4 }
                $cells[$y][$stem] = 'G'
                $cells[$y][$stem + 1] = 'G'
            }
            if ($y -ge 17 -and $y -le 19) {
                $tip = 3 + $offset
                for ($x = $tip; $x -lt [Math]::Min(6, $tip + 3); $x++) {
                    $cells[$y][$x] = if ($y -eq 19) { 'M' } else { 'R' }
                }
            }
        }
    }
    if ($AnimationMode -eq 'Goodbye' -and $Tick -ge 3 -and $Tick -lt 23) {
        # Lift the near paw; leave the far hind paw on the ground.
        for ($y = 24; $y -le 26; $y++) {
            for ($x = 18; $x -le 21; $x++) {
                $cells[$y][$x] = if ($y -eq 24) { 'G' } else { '.' }
            }
        }
        for ($x = 22; $x -le 27; $x++) { $cells[22][$x] = 'G' }
        $sway = [int][Math]::Floor(($Tick - 3) / 4) % 2
        for ($y = 20; $y -le 22; $y++) { $cells[$y][27] = 'Y' }
        for ($y = 17 + $sway; $y -le 20 + $sway; $y++) {
            for ($x = 26; $x -le 29; $x++) {
                $cells[$y][$x] = if ($y -eq (17 + $sway)) { 'C' } else { 'Y' }
            }
        }
        $cells[19 + $sway][27] = 'G'
        $cells[19 + $sway][29] = 'G'
    }
    $rows = @(foreach ($row in $cells) { -join $row })
    if ($AnimationMode -eq 'Welcome' -and $Tick -lt 14) {
        # Clip a little hop at the canvas edge; never wrap around the terminal.
        $position = $Tick / 14.0
        $offsetX = -[int][Math]::Ceiling(32 * [Math]::Pow(1 - $position, 2))
        $hop = if ($Tick -ge 4 -and $Tick -le 10) { -1 } else { 0 }
        $arrival = @()
        for ($y = 0; $y -lt 29; $y++) {
            $line = ('.' * 32).ToCharArray()
            $sourceY = $y - $hop
            if ($sourceY -ge 0 -and $sourceY -lt 29) {
                for ($x = 0; $x -lt 32; $x++) {
                    $sourceX = $x - $offsetX
                    if ($sourceX -ge 0 -and $sourceX -lt 32) {
                        $line[$x] = $rows[$sourceY][$sourceX]
                    }
                }
            }
            $arrival += -join $line
        }
        return $arrival
    }
    return $rows
}


function Get-SignatureLines {
    param([bool]$UseRgb, [int]$Columns, [string]$Message)
    $credit = '|    by Matthias Demkiv    |'
    $rule = '+' + ('-' * ($credit.Length - 2)) + '+'
    $statusWidth = [Math]::Min(60, [Math]::Max(1, $Columns - 2))
    # Keep labels on one line so they cannot displace the animation canvas.
    $label = ConvertTo-SafeText $Message
    if ($label.Length -gt $statusWidth) { $label = $label.Substring(0, $statusWidth) }
    $label = $label.PadLeft([int][Math]::Floor(($statusWidth + $label.Length) / 2)).PadRight($statusWidth)
    $padding = ' ' * [Math]::Max(0, [int][Math]::Floor(($Columns - $credit.Length) / 2))
    $statusPadding = ' ' * [Math]::Max(0, [int][Math]::Floor(($Columns - $statusWidth) / 2))
    ''
    if ($UseRgb) {
        $red = "$esc[38;2;210;51;65m"
        $gold = "$esc[38;2;238;184;98m"
        $cream = "$esc[38;2;255;225;175m"
        $muted = "$esc[38;2;157;137;130m"
        $reset = "$esc[0m"
        "$padding$red$rule$reset"
        "$padding$red|    $muted" + "by $esc[1m$($cream)Matthias $($gold)Demkiv$reset$red    |$reset"
        "$padding$red$rule$reset"
        "$statusPadding$muted$label$reset"
    } else {
        "$padding$rule"
        "$padding$credit"
        "$padding$rule"
        "$statusPadding$label"
    }
}

function Expand-CubRows {
    param([string[]]$FrameRows, [int]$PixelScale)
    foreach ($row in $FrameRows) {
        $wide = -join @($row.ToCharArray() | ForEach-Object { ([string]$_) * $PixelScale })
        for ($repeat = 0; $repeat -lt $PixelScale; $repeat++) { $wide }
    }
}

function Write-BasicCub {
    param([string[]]$FrameRows, [int]$PixelScale, [string]$Indent)
    $expanded = @(Expand-CubRows $FrameRows $PixelScale)
    for ($y = 0; $y -lt $expanded.Count; $y += 2) {
        Write-Host $Indent -NoNewline
        for ($x = 0; $x -lt $expanded[$y].Length; $x++) {
            $top = [string]$expanded[$y][$x]
            $bottom = if ($y + 1 -lt $expanded.Count) { [string]$expanded[$y+1][$x] } else { '.' }
            if ($top -eq '.' -and $bottom -eq '.') { Write-Host ' ' -NoNewline }
            elseif ($top -eq '.') { Write-Host ([char]0x2584) -ForegroundColor $fallback[$bottom] -NoNewline }
            elseif ($bottom -eq '.') { Write-Host ([char]0x2580) -ForegroundColor $fallback[$top] -NoNewline }
            else { Write-Host ([char]0x2580) -ForegroundColor $fallback[$top] -BackgroundColor $fallback[$bottom] -NoNewline }
        }
        Write-Host
    }
}
function ConvertTo-CubLines {
    param([string[]]$FrameRows, [int]$PixelScale, [bool]$UseRgb)
    if (-not $UseRgb) { return $FrameRows }
    # Half-blocks fit square pixels into ordinary monospace terminal cells.
    $expanded = @(Expand-CubRows $FrameRows $PixelScale)
    for ($y = 0; $y -lt $expanded.Count; $y += 2) {
        $line = [Text.StringBuilder]::new()
        for ($x = 0; $x -lt $expanded[$y].Length; $x++) {
            $top = [string]$expanded[$y][$x]
            $bottom = if ($y + 1 -lt $expanded.Count) { [string]$expanded[$y+1][$x] } else { '.' }
            if ($top -eq '.' -and $bottom -eq '.') {
                [void]$line.Append("${esc}[0m ")
            } elseif ($top -eq '.') {
                [void]$line.Append("${esc}[49m${esc}[38;2;$($rgb[$bottom])m$([char]0x2584)")
            } elseif ($bottom -eq '.') {
                [void]$line.Append("${esc}[49m${esc}[38;2;$($rgb[$top])m$([char]0x2580)")
            } else {
                [void]$line.Append("${esc}[38;2;$($rgb[$top])m${esc}[48;2;$($rgb[$bottom])m$([char]0x2580)")
            }
        }
        [void]$line.Append("${esc}[0m")
        $line.ToString()
    }
}


function Show-DemkivAnimation {
    param(
        [ValidateSet('Welcome','Goodbye')][string]$Mode,
        [int]$Scale,
        [switch]$Still,
        [string]$Message
    )
    $AnimationMode = $Mode
    $useRgb = $false
    $redirected = $true
    try {
        $redirected = [Console]::IsOutputRedirected
        $useRgb = [bool]$Host.UI.SupportsVirtualTerminal -and -not $redirected
    } catch {}
    $columns = Get-ConsoleWidth
    $height = 40
    try { if ($Host.UI.RawUI.WindowSize.Height -gt 0) { $height = $Host.UI.RawUI.WindowSize.Height } } catch {}
    if ($columns -lt 67 -or $height -lt 37) { $Scale = 1 }
    $artWidth = 32 * $Scale
    $artHeight = [int][Math]::Ceiling(29 * $Scale / 2)
    $blockHeight = $artHeight + 5
    $indent = ' ' * [Math]::Max(0, [int][Math]::Floor(($columns - $artWidth) / 2))
    $animate = -not $Still -and $useRgb -and $columns -gt $artWidth -and $height -gt ($blockHeight + 1)
    $initialTick = if ($animate) { 0 } elseif ($Mode -eq 'Goodbye') { 12 } else { 32 }
    $previousCursor = $null
    try {
        if ($redirected -or $columns -lt 33) {
            Write-Host 'by Matthias Demkiv' -ForegroundColor White
            Write-Host (ConvertTo-SafeText $Message)
        } else {
            if ($animate) {
                $previousCursor = [Console]::CursorVisible
                [Console]::CursorVisible = $false
            }
            $pose = @(Get-SceneFrame -Tick $initialTick)
            $firstFrame = @(ConvertTo-CubLines -FrameRows $pose -PixelScale $Scale -UseRgb $useRgb)
            if ($useRgb) {
                foreach ($line in $firstFrame) { Write-Host ($indent + $line) }
            } else {
                Write-BasicCub -FrameRows $pose -PixelScale $Scale -Indent $indent
            }
            $footer = @(Get-SignatureLines -UseRgb $useRgb -Columns $columns -Message $Message)
            foreach ($line in $footer) { Write-Host $line -ForegroundColor White }
            if ($animate) {
                $previousLines = @($firstFrame | ForEach-Object { $indent + $_ }) + $footer
                $lastTick = if ($Mode -eq 'Welcome') { 32 } else { 28 }
                $tick = 0
                do {
                    Start-Sleep -Milliseconds 90
                    $tick++
                    $size = $Host.UI.RawUI.WindowSize
                    # Leave existing output alone if the user changes its layout.
                    if ($size.Width -ne $columns -or $size.Height -ne $height) { break }
                    $art = @(ConvertTo-CubLines -FrameRows (Get-SceneFrame -Tick $tick) -PixelScale $Scale -UseRgb $true)
                    $footer = @(Get-SignatureLines -UseRgb $true -Columns $columns -Message $Message)
                    $lines = @($art | ForEach-Object { $indent + $_ }) + $footer
                    $output = [Text.StringBuilder]::new()
                    for ($y = 0; $y -lt $lines.Count; $y++) {
                        if ($lines[$y] -cne $previousLines[$y]) {
                            $distance = $blockHeight - $y
                            [void]$output.Append("$esc[$($distance)A$([char]13)$($lines[$y])$([char]13)$esc[$($distance)B")
                        }
                    }
                    if ($output.Length) { Write-Host $output.ToString() -NoNewline }
                    $previousLines = $lines
                } until ($tick -ge $lastTick)
            }
        }
    } finally {
        if ($useRgb) { Write-Host "$esc[0m" -NoNewline }
        if ($null -ne $previousCursor) { [Console]::CursorVisible = $previousCursor }
    }
    Write-Host
}

# ======================= WINSTATION IMPLEMENTATION ======================
function New-ItemDefinition($Name, $Id, $Category, $Type = 'WinGet', $Source = 'winget') {
    [pscustomobject]@{
        Name=$Name; Id=$Id; Category=$Category; Type=$Type; Source=$Source
        Installed=$false; DetectionState='Unknown'; DetectionDetail='Not checked yet.'
    }
}


# Theme follows the mascot. Semantic success/error colors remain distinct.
$uiPalette = @{
    Red='210;51;65'; DarkRed='102;24;42'; Yellow='238;184;98'
    Cyan='238;184;98'; White='255;225;175'; Gray='219;198;178'
    DarkGray='172;151;143'; Green='163;192;145'; Magenta='248;109;91'
}
$uiUseColor = $false
try { $uiUseColor = $Host.UI.SupportsVirtualTerminal -and -not [Console]::IsOutputRedirected } catch {}

function Write-Ui {
    param(
        [Parameter(Position=0)][AllowEmptyString()][string]$Object = '',
        [ConsoleColor]$ForegroundColor = 'White',
        [switch]$NoNewline,
        [switch]$Bold
    )
    $color = $uiPalette[$ForegroundColor.ToString()]
    if ($uiUseColor -and $color) {
        $weight = if ($Bold) { "$esc[1m" } else { '' }
        Write-Host "$esc[38;2;$($color)m$weight$Object$esc[0m" -NoNewline:$NoNewline
    } else {
        Write-Host $Object -ForegroundColor $ForegroundColor -NoNewline:$NoNewline
    }
}

function Get-ConsoleWidth {
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 0) { return $Host.UI.RawUI.WindowSize.Width }
    } catch {}
    return 80
}

function Write-Centered($Text, $Color = 'White', [switch]$Bold) {
    $width = Get-ConsoleWidth
    # Wrap words in narrow windows instead of letting the terminal wrap padding.
    $limit = [Math]::Max(1, $width - 2)
    $remaining = [string]$Text
    do {
        $line = $remaining
        if ($line.Length -gt $limit) {
            $cut = $line.LastIndexOf(' ', $limit)
            if ($cut -le 0) { $cut = $limit }
            $line = $remaining.Substring(0, $cut)
            $remaining = $remaining.Substring($cut).TrimStart()
        } else { $remaining = '' }
        $padding = ' ' * [Math]::Max(0, [Math]::Floor(($width - $line.Length) / 2))
        Write-Ui ($padding + $line) -ForegroundColor $Color -Bold:$Bold
    } while ($remaining.Length)
}

function Read-Centered($Prompt) {
    $width = Get-ConsoleWidth
    $padding = [Math]::Max(0, [Math]::Floor(($width - ($Prompt.Length + 2)) / 2))
    Read-Host ((' ' * $padding) + $Prompt)
}

# Clears the screen and shows a section heading below the banner.
function Show-Screen($Title) {
    Show-Banner
    Write-Centered "[ $Title ]" 'Cyan' -Bold
    Write-Ui
}

$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$classicMenuKey = 'Registry::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'

function ConvertTo-EncodedCommand([string]$Command) {
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}

# ============================================================================
# CUSTOMIZE THE SOFTWARE CATALOG HERE
# ============================================================================
# WinGet applications use this format:
#   New-ItemDefinition 'Display name' 'Publisher.PackageId' 'Any category name'
#
# Microsoft Store applications use this format:
#   New-ItemDefinition 'Display name' 'StoreProductId' 'Any category name' 'WinGet' 'msstore'
#
# Find a package ID with: winget search "application name"
# Categories are created automatically. Add, remove, copy, or reorder lines below;
# the audit and selection menus require no other code changes.
# Types PowerShell, AzureCLI, and Module are handled specially by this script.
# ============================================================================
$catalog = @(
    New-ItemDefinition 'Google Chrome' 'Google.Chrome' 'Web Browsers'
    New-ItemDefinition 'Git' 'Git.Git' 'Development Tools'
    New-ItemDefinition 'Node.js' 'OpenJS.NodeJS' 'Development Tools'
    New-ItemDefinition 'Python 3' 'Python.Python.3.14' 'Development Tools'
    New-ItemDefinition 'Visual Studio Code' 'Microsoft.VisualStudioCode' 'Development Tools'
    New-ItemDefinition '7-Zip' '7zip.7zip' 'Development Tools'
    New-ItemDefinition 'Windows Terminal' 'Microsoft.WindowsTerminal' 'Development Tools'
    New-ItemDefinition 'Obsidian' 'Obsidian.Obsidian' 'Productivity'
    New-ItemDefinition 'Claude' 'Anthropic.Claude' 'AI'
    New-ItemDefinition 'Tailscale' 'Tailscale.Tailscale' 'Networking and Security'
    New-ItemDefinition 'Bitwarden' 'Bitwarden.Bitwarden' 'Networking and Security'
    New-ItemDefinition 'Nextcloud' 'Nextcloud.NextcloudDesktop' 'Networking and Security'
    New-ItemDefinition 'Discord' 'Discord.Discord' 'Communication'
    New-ItemDefinition 'WhatsApp' '9NKSQGP7F2NH' 'Communication' 'WinGet' 'msstore'
    New-ItemDefinition 'Spotify' 'Spotify.Spotify' 'Media'
    New-ItemDefinition 'Kodi' 'XBMCFoundation.Kodi' 'Media'
    New-ItemDefinition 'K-Lite Codec Pack' 'CodecGuide.K-LiteCodecPack.Standard' 'Media'
    New-ItemDefinition 'Steam' 'Valve.Steam' 'Gaming'
    New-ItemDefinition 'Bambu Studio' 'Bambulab.Bambustudio' '3D Printing'
    New-ItemDefinition 'ChatGPT' '9PLM9XGG6VKS' 'AI' 'WinGet' 'msstore'
    New-ItemDefinition 'Logi Options+' 'Logitech.OptionsPlus' 'Hardware and Apple'
    New-ItemDefinition 'iCloud' '9PKTQ5699M62' 'Hardware and Apple' 'WinGet' 'msstore'
    New-ItemDefinition 'PowerShell 7' 'PowerShell7' 'Azure and Microsoft 365' 'PowerShell' 'Official MSI'
    New-ItemDefinition 'Azure CLI 64-bit' 'AzureCLI' 'Azure and Microsoft 365' 'AzureCLI' 'Official MSI'
    New-ItemDefinition 'Azure PowerShell (Az)' 'Az' 'Azure and Microsoft 365' 'Module' 'PSGallery'
    New-ItemDefinition 'Microsoft Graph PowerShell' 'Microsoft.Graph' 'Azure and Microsoft 365' 'Module' 'PSGallery'
    New-ItemDefinition 'Exchange Online PowerShell' 'ExchangeOnlineManagement' 'Azure and Microsoft 365' 'Module' 'PSGallery'
    New-ItemDefinition 'SharePoint Online PowerShell' 'Microsoft.Online.SharePoint.PowerShell' 'Azure and Microsoft 365' 'Module' 'PSGallery'
    New-ItemDefinition 'Microsoft Teams PowerShell' 'MicrosoftTeams' 'Azure and Microsoft 365' 'Module' 'PSGallery'
    New-ItemDefinition 'PnP PowerShell' 'PnP.PowerShell' 'Azure and Microsoft 365' 'Module' 'PSGallery'
)

function Show-Banner {
    param([switch]$Welcome, [switch]$Waiting, [switch]$Goodbye, [switch]$Still)
    try { $Host.UI.RawUI.WindowTitle = 'WinStation Setup | Demkiv' } catch {}
    try { if (-not [Console]::IsOutputRedirected) { Clear-Host } } catch {}
    $rule = '-' * [Math]::Min(64, [Math]::Max(1, (Get-ConsoleWidth) - 4))
    Write-Centered $rule 'DarkRed'
    Write-Centered 'W I N S T A T I O N' 'Red' -Bold
    Write-Ui
    if ($Goodbye) {
        Show-DemkivAnimation -Mode Goodbye -Scale 1 -Still:$NoAnimation -Message 'See you next time!'
        return
    }
    if ($Welcome -or $Waiting) {
        if ($Waiting) {
            Show-DemkivAnimation -Mode Welcome -Scale 1 -Still -Message 'Ready for your next action'
        } else {
            Show-DemkivAnimation -Mode Welcome -Scale 1 -Still:($NoAnimation -or $Still) -Message 'Welcome to WinStation Setup'
        }
        # Preserve the final frame when the main menu appears.
    } else {
        Write-Centered 'by Matthias Demkiv' 'White' -Bold
        Write-Ui
    }
    Write-Centered 'APPS  |  DRIVERS  |  DEVELOPMENT  |  AZURE  |  MICROSOFT 365' 'Cyan'
    Write-Centered $rule 'DarkRed'
    Write-Ui
}

function Confirm-Action($Message) {
    Write-Ui $Message -ForegroundColor Yellow
    $answer = (Read-Host 'Type Y and press Enter to confirm (anything else cancels)').Trim().ToUpper()
    return ($answer -eq 'Y')
}

function Test-Installed($Item) {
    $state = 'Unknown'
    $detail = ''
    try { switch ($Item.Type) {
        'WinGet' {
            if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
                $detail = 'WinGet is unavailable. Install or update App Installer from Microsoft Store, then reopen WinStation.'
                break
            }
            $previousPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = (& winget.exe list --id $Item.Id --exact --source $Item.Source --accept-source-agreements --disable-interactivity 2>&1 | Out-String).Trim()
                $code = $LASTEXITCODE
                if ($code -eq 0) { $state = 'Installed' }
                elseif ($code -eq -1978335212) { $state = 'Missing' } # No applications found, not a source/network failure.
                else { $detail = "WinGet could not check this item (exit $code). $output" }
            } finally {
                $ErrorActionPreference = $previousPreference
            }
        }
        'PowerShell' {
            $state = if (Test-Path $pwshPath) { 'Installed' } else { 'Missing' }
        }
        'AzureCLI' {
            $x64 = Join-Path $env:ProgramFiles 'Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
            $x86 = if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Microsoft SDKs\Azure\CLI2\wbin\az.cmd' }
            $state = if ((Test-Path $x64) -or ($x86 -and (Test-Path $x86))) { 'Installed' } else { 'Missing' }
        }
        'Module' {
            if (-not (Test-Path $pwshPath)) {
                $state = 'Missing'
                $detail = 'Requires PowerShell 7; it will be included in the installation plan.'
                break
            }
            $id = $Item.Id.Replace("'", "''")
            $command = "try { if(Get-Module -ListAvailable '$id' -ErrorAction Stop){exit 0}else{exit 1} } catch { exit 2 }"
            & $pwshPath -NoLogo -NoProfile -NonInteractive -EncodedCommand (ConvertTo-EncodedCommand $command) 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $state = 'Installed' }
            elseif ($LASTEXITCODE -eq 1) { $state = 'Missing' }
            else { $detail = "PowerShell module check failed (exit $LASTEXITCODE)." }
        }
        default { $detail = "Unsupported catalog type: $($Item.Type)" }
    } } catch { $state = 'Unknown'; $detail = $_.Exception.Message }
    $detail = ConvertTo-SafeText $detail -StripAnsi
    if ($detail.Length -gt 500) { $detail = $detail.Substring(0,500) + '...' }
    [pscustomobject]@{ State=$state; Detail=$detail }
}

function Get-DetectionStyle($State) {
    switch ($State) {
        'Installed' { @{ Label='Installed'; Color='Green' } }
        'Missing' { @{ Label='Missing'; Color='Yellow' } }
        default { @{ Label='Could not check'; Color='Red' } }
    }
}

function Invoke-Audit {
    Write-Ui 'Scanning installed software...' -ForegroundColor Yellow
    for ($i=0; $i -lt $catalog.Count; $i++) {
        $item = $catalog[$i]
        Write-Ui ('  [{0}/{1}] {2} ... ' -f ($i + 1), $catalog.Count, $item.Name) -ForegroundColor Gray -NoNewline
        $detection = Test-Installed $item
        if ($detection.State -notin @('Installed','Missing','Unknown')) { throw 'Software scan returned an invalid status.' }
        $item.DetectionState = $detection.State
        $item.DetectionDetail = $detection.Detail
        $item.Installed = $detection.State -eq 'Installed'
        $style = Get-DetectionStyle $detection.State
        Write-Ui $style.Label -ForegroundColor $style.Color
    }
}

function Show-Audit {
    foreach ($group in ($catalog | Group-Object Category)) {
        Write-Ui "`n[$($group.Name)]" -ForegroundColor Cyan
        foreach ($item in $group.Group) {
            $style = Get-DetectionStyle $item.DetectionState
            Write-Ui ("  [$($style.Label)]".PadRight(20)) -NoNewline -ForegroundColor $style.Color
            Write-Ui "$($item.Name)  ($($item.Source))"
            if ($item.DetectionDetail) { Write-Ui "    $($item.DetectionDetail)" -ForegroundColor DarkGray }
        }
    }
    $installed = @($catalog | Where-Object Installed).Count
    $missing = @($catalog | Where-Object DetectionState -eq 'Missing').Count
    $unknown = @($catalog | Where-Object DetectionState -eq 'Unknown').Count
    Write-Ui "`nAudit complete: $installed installed, $missing missing, $unknown could not be checked." -ForegroundColor Cyan
    if ($unknown) { Write-Ui 'Unchecked items are excluded from installation. Resolve the check errors and scan again.' -ForegroundColor Yellow }
    Write-Ui

    Write-Ui '[Windows 11 Actions]' -ForegroundColor Cyan
    $menuState = if (Test-Path $classicMenuKey) { 'Enabled' } else { 'Not enabled' }
    $tcpip = Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    $domainState = if ($tcpip.Domain) { $tcpip.Domain } else { 'Workgroup / not domain joined' }
    Write-Ui "  Classic full context menu: $menuState"
    Write-Ui "  Computer name: $env:COMPUTERNAME"
    Write-Ui "  Current user: $env:USERNAME"
    Write-Ui "  Domain/workgroup: $domainState"
    Write-Ui
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator($Purpose) {
    if (Test-IsAdministrator) { return $true }
    Write-Ui "Run this script as Administrator to $Purpose." -ForegroundColor Red
    return $false
}

# Returns the trimmed answer, or $null when the user types B to cancel.
function Read-ActionInput($Prompt) {
    Write-Ui '[B] Cancel and return to Windows 11 actions' -ForegroundColor DarkGray
    $answer = (Read-Host $Prompt).Trim()
    if ($answer -ieq 'B') { Write-Ui 'Action cancelled.' -ForegroundColor Yellow; return $null }
    return $answer
}

function Enable-ClassicContextMenu {
    if (-not (Confirm-Action 'Enable the classic full Windows 11 context menu?')) {
        Write-Ui 'Action cancelled.' -ForegroundColor Yellow
        return
    }
    if (-not $PSCmdlet.ShouldProcess('Current user', 'Enable the classic full Windows 11 context menu')) { return }
    New-Item -Path $classicMenuKey -Force | Out-Null
    Set-Item -Path $classicMenuKey -Value ''
    Write-Ui 'Classic context menu enabled. Sign out or restart Windows Explorer to apply it.' -ForegroundColor Green
}

function Rename-ThisComputer {
    if (-not (Assert-Administrator 'rename the computer')) { return }
    $newName = Read-ActionInput "New computer name (current: $env:COMPUTERNAME)"
    if ($null -eq $newName) { return }
    if ($newName -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$') {
        Write-Ui 'Invalid name. Use 1-15 letters, numbers, or hyphens; no hyphen at the end.' -ForegroundColor Red
        return
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename computer to $newName")) { return }
    Rename-Computer -NewName $newName -Force
    Write-Ui "Computer renamed to $newName. A restart is required." -ForegroundColor Green
}

function Rename-LocalAccountInteractive {
    if (-not (Assert-Administrator 'rename a local account')) { return }
    $localUsers = @(Get-LocalUser | Sort-Object Name)
    Write-Ui 'Local accounts:' -ForegroundColor Cyan
    $localUsers | ForEach-Object { Write-Ui "  - $($_.Name)" }
    Write-Ui
    Write-Ui 'Step 1 of 2: enter the CURRENT account name to rename.' -ForegroundColor Yellow
    $oldName = Read-ActionInput "Current account name (signed in as: $env:USERNAME)"
    if ($null -eq $oldName) { return }
    if (-not (Get-LocalUser -Name $oldName -ErrorAction SilentlyContinue)) { Write-Ui 'Local account not found.' -ForegroundColor Red; return }
    Write-Ui
    Write-Ui "Step 2 of 2: enter the NEW name for '$oldName'." -ForegroundColor Yellow
    $newName = Read-ActionInput 'New local account name'
    if ($null -eq $newName) { return }
    if (-not $newName -or $newName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { Write-Ui 'Invalid account name.' -ForegroundColor Red; return }
    Write-Ui 'Note: this does not rename the existing C:\Users profile folder.' -ForegroundColor Yellow
    if (-not $PSCmdlet.ShouldProcess($oldName, "Rename local account to $newName")) { return }
    Rename-LocalUser -Name $oldName -NewName $newName
    Write-Ui "Local account renamed to $newName. Sign out to apply it everywhere." -ForegroundColor Green
}

function Join-DomainInteractive {
    if (-not (Assert-Administrator 'join a domain')) { return }
    $domain = Read-ActionInput 'Active Directory domain name (for example corp.example.com)'
    if ($null -eq $domain) { return }
    if ($domain -notmatch '^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$') {
        Write-Ui 'Invalid DNS domain name.' -ForegroundColor Red
        return
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Join Active Directory domain $domain")) { return }
    $credential = Get-Credential -Message "Credentials permitted to join $domain"
    if ($null -eq $credential) { Write-Ui 'Action cancelled.' -ForegroundColor Yellow; return }
    Add-Computer -DomainName $domain -Credential $credential -Force
    Write-Ui "Domain join requested for $domain. A restart is required." -ForegroundColor Green
}

function Get-DriverUpdateKind($Update) {
    # Metadata varies by publisher. An unknown class is never bulk-selected.
    $driverClass = ''
    $hardwareId = ''
    try { $driverClass = [string]$Update.DriverClass } catch {}
    try { $hardwareId = [string]$Update.DriverHardwareID } catch {}
    $description = "$driverClass $hardwareId $($Update.Title)"
    if ($description -match '(?i)firmware|\bBIOS\b|\bUEFI\b') { return 'Firmware' }
    if ([string]::IsNullOrWhiteSpace($driverClass)) { return 'Review' }
    'Driver'
}

function Install-DriversFromWindowsUpdate {
    Show-Screen 'DRIVER UPDATES'
    if (-not (Assert-Administrator 'install drivers')) { return }
    try {
        Write-Ui 'Scanning hardware and Windows Update for drivers. This can take several minutes...' -ForegroundColor Yellow
        # Keep COM update objects in the foreground and this workflow text-only.
        # Never trigger device re-enumeration, EULA acceptance or downloads here.
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searcher.Online = $true
        $result = $searcher.Search("IsInstalled=0 and Type='Driver'")
        if ($result.ResultCode -notin @(2,3)) { throw "Driver scan did not complete (result $($result.ResultCode))." }
        if ($result.ResultCode -eq 3) { Write-Ui 'The driver scan completed with errors; this list may be incomplete.' -ForegroundColor Yellow }
        if ($result.Updates.Count -eq 0) { Write-Ui 'No applicable driver updates were found.' -ForegroundColor Green; return }

        Write-Ui "Found $($result.Updates.Count) driver update(s):" -ForegroundColor Cyan
        $kinds = @()
        for ($i=0; $i -lt $result.Updates.Count; $i++) {
            $update = $result.Updates.Item($i)
            $kind = Get-DriverUpdateKind $update
            $kinds += $kind
            $label = switch ($kind) { 'Firmware' { ' [BIOS / FIRMWARE]' }; 'Review' { ' [REVIEW: class unavailable]' }; default { '' } }
            Write-Ui "  [$($i+1)] $($update.Title)$label"
        }

        Write-Ui "`n[A] Select all regular drivers (excludes firmware and unclassified updates)"
        Write-Ui '[S] Select individual drivers by number'
        Write-Ui '[C] Cancel and return to the main menu' -ForegroundColor DarkGray
        Write-Ui 'Type A, S, or C and press Enter.' -ForegroundColor DarkGray
        $choice = (Read-Host 'Selection').Trim().ToUpper()
        if ($choice -eq 'A') { $indexes = @(0..($result.Updates.Count-1) | Where-Object { $kinds[$_] -eq 'Driver' }) }
        elseif ($choice -eq 'S') {
            Write-Ui 'Example: 1,3,5 and then press Enter.' -ForegroundColor DarkGray
            $numbers = @(Read-Numbers $result.Updates.Count 'Driver numbers (comma-separated)')
            $indexes = @($numbers | ForEach-Object { $_ - 1 })
        } else {
            Write-Ui 'Driver installation cancelled. Nothing was downloaded or installed.' -ForegroundColor Yellow
            return
        }
        if (-not $indexes.Count) { Write-Ui 'No drivers selected.' -ForegroundColor Yellow; return }

        Write-Ui "`nSelected driver updates:" -ForegroundColor Cyan
        $indexes | ForEach-Object { Write-Ui "  - $($result.Updates.Item($_).Title)" }
        if (@($indexes | Where-Object { $kinds[$_] -eq 'Firmware' }).Count) {
            Write-Ui 'Firmware selected. Check the manufacturer instructions, connect AC power and have your BitLocker recovery key available. Do not interrupt an update or its restart.' -ForegroundColor Yellow
            if ((Read-Host 'Type FIRMWARE and press Enter to include these updates').Trim() -cne 'FIRMWARE') {
                Write-Ui 'Firmware confirmation cancelled. Nothing was downloaded or installed.' -ForegroundColor Yellow
                return
            }
        }
        if (@($indexes | Where-Object { $kinds[$_] -eq 'Review' }).Count) {
            Write-Ui 'Some selected updates have no driver class. Their titles may not identify firmware; review them before continuing.' -ForegroundColor Yellow
        }
        if (-not (Confirm-Action 'Download and install the selected driver updates?')) {
            Write-Ui 'Driver installation cancelled. Nothing was downloaded or installed.' -ForegroundColor Yellow
            return
        }
        if (-not $PSCmdlet.ShouldProcess('This computer', "Download and install $($indexes.Count) selected driver update(s)")) { return }

        $updates = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($index in $indexes) {
            $update = $result.Updates.Item($index)
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            [void]$updates.Add($update)
        }

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $updates
        Write-Ui 'Downloading driver updates...' -ForegroundColor Yellow
        $downloadResult = $downloader.Download()
        $ready = New-Object -ComObject Microsoft.Update.UpdateColl
        $report = @()
        $readyRows = @()
        for ($i=0; $i -lt $updates.Count; $i++) {
            $update = $updates.Item($i)
            $download = $downloadResult.GetUpdateResult($i)
            $row = [pscustomobject]@{ Name=$update.Title; Status='Download failed'; Detail="Result $($download.ResultCode), HRESULT $($download.HResult)"; Reboot=$false }
            $report += $row
            if ($download.ResultCode -eq 2 -and $update.IsDownloaded) {
                [void]$ready.Add($update)
                $readyRows += $row
                $row.Status = 'Not installed'
                $row.Detail = 'Downloaded successfully.'
            }
        }
        $reboot = $false
        if ($ready.Count) {
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $ready
            Write-Ui "Installing $($ready.Count) downloaded driver update(s)..." -ForegroundColor Yellow
            try {
                $installResult = $installer.Install()
                $reboot = [bool]$installResult.RebootRequired
                for ($i=0; $i -lt $ready.Count; $i++) {
                    $installed = $installResult.GetUpdateResult($i)
                    $readyRows[$i].Status = switch ([int]$installed.ResultCode) {
                        2 { 'Installed' }; 3 { 'Completed with errors' }; 5 { 'Cancelled' }; default { 'Installation failed' }
                    }
                    $readyRows[$i].Detail = "Result $($installed.ResultCode), HRESULT $($installed.HResult)"
                    $readyRows[$i].Reboot = [bool]$installed.RebootRequired
                    $reboot = $reboot -or $readyRows[$i].Reboot
                }
            } catch {
                $installationError = $_.Exception.Message
                foreach ($row in $readyRows | Where-Object Status -eq 'Not installed') {
                    $row.Status = 'Outcome unknown'
                    $row.Detail = $installationError
                }
            }
        }
        Write-Ui "`n[ DRIVER RESULTS ]" -ForegroundColor Cyan
        foreach ($row in $report) {
            $color = if ($row.Status -eq 'Installed') { 'Green' } else { 'Yellow' }
            Write-Ui "  [$($row.Status)] $($row.Name)" -ForegroundColor $color
            if ($row.Status -ne 'Installed') { Write-Ui "    $($row.Detail)" -ForegroundColor DarkGray }
            if ($row.Reboot) { Write-Ui '    Restart required.' -ForegroundColor Yellow }
        }
        $completed = @($report | Where-Object Status -eq 'Installed').Count
        Write-Ui "$completed installed, $($report.Count - $completed) need attention." -ForegroundColor Cyan
        if ($reboot) { Write-Ui 'A restart is required to finish installing drivers. WinStation will not restart automatically.' -ForegroundColor Yellow }
    } catch {
        Write-Ui "Driver installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-WindowsActions {
    $menuLines = @(
        @{ Text='[1]  Enable classic full context menu'; Color='White' },
        @{ Text='[2]  Rename this computer'; Color='White' },
        @{ Text='[3]  Rename a local account'; Color='White' },
        @{ Text='[4]  Join an Active Directory domain'; Color='White' },
        @{ Text='[B]  Back to main menu'; Color='DarkGray' }
    )
    do {
        Show-Banner
        $action = Show-ChoiceMenu -Title 'WINDOWS 11 ACTIONS' -MenuLines $menuLines -ExitKey 'B' -ExitHint 'Esc: back | B: select back' -ShortcutHint '1-4: select a shortcut, then press Enter.' -EscapeToExit
        if ($action -eq 'B') { return }
        if ($action -notin @('1','2','3','4')) {
            Write-Ui 'Invalid selection.' -ForegroundColor Yellow
        } else {
            Show-Screen 'WINDOWS 11 ACTIONS'
            Write-Ui ($menuLines[([int]$action - 1)].Text.Substring(5)) -ForegroundColor Yellow -Bold
            Write-Ui
            try {
                switch ($action) {
                    '1' { Enable-ClassicContextMenu }
                    '2' { Rename-ThisComputer }
                    '3' { Rename-LocalAccountInteractive }
                    '4' { Join-DomainInteractive }
                }
            } catch {
                Write-Ui ("Action failed: " + $_.Exception.Message) -ForegroundColor Red
            }
        }
        Write-Ui
        [void](Read-Host 'Press Enter to return to Windows 11 actions')
    } while ($true)
}

function Read-Numbers($Maximum, $Prompt) {
    $result = @()
    foreach ($token in ((Read-Host $Prompt) -split ',')) {
        $number = 0
        if ([int]::TryParse($token.Trim(), [ref]$number) -and $number -ge 1 -and $number -le $Maximum) { $result += $number }
    }
    @($result | Select-Object -Unique)
}

function Select-InstallItems {
    $missing = @($catalog | Where-Object DetectionState -eq 'Missing')
    if (-not $missing.Count) { return @() }
    $menuLines = @(
        @{ Text='[1]  Install all missing items'; Color='White' },
        @{ Text='[2]  Select categories'; Color='White' },
        @{ Text='[3]  Select individual items'; Color='White' },
        @{ Text='[B]  Back to the main menu'; Color='DarkGray' }
    )
    $choice = Show-ChoiceMenu -Title 'SOFTWARE INSTALLATION' -MenuLines $menuLines -ExitKey 'B' -ExitHint 'Esc: back | B: select back' -ShortcutHint '1-3: select a shortcut, then press Enter.' -EscapeToExit
    if ($choice -eq 'B') { return @() }
    if ($choice -eq '1') { return $missing }
    if ($choice -eq '2') {
        $categories = @($missing.Category | Sort-Object -Unique)
        for ($i=0; $i -lt $categories.Count; $i++) {
            $count = @($missing | Where-Object Category -eq $categories[$i]).Count
            Write-Ui "[$($i+1)] $($categories[$i]) ($count missing)"
        }
        Write-Ui 'Example: 1,3 and then press Enter.' -ForegroundColor DarkGray
        $numbers = Read-Numbers $categories.Count 'Category numbers (comma-separated)'
        $chosen = @($numbers | ForEach-Object { $categories[$_-1] })
        return @($missing | Where-Object { $_.Category -in $chosen })
    }
    if ($choice -eq '3') {
        for ($i=0; $i -lt $missing.Count; $i++) { Write-Ui "[$($i+1)] $($missing[$i].Category) / $($missing[$i].Name)" }
        Write-Ui 'Example: 1,4,7 and then press Enter.' -ForegroundColor DarkGray
        $numbers = Read-Numbers $missing.Count 'Item numbers (comma-separated)'
        return @($numbers | ForEach-Object { $missing[$_-1] })
    }
    @()
}

function New-InstallResult($Item, $Status, $Detail='', $Code=0, [bool]$Reboot=$false) {
    [pscustomobject]@{ Item=$Item; Name=$Item.Name; Status=$Status; Detail=$Detail; Code=$Code; Reboot=$Reboot }
}

function ConvertTo-ProcessArgument([string]$Value) {
    # Windows native argument quoting: preserve embedded quotes and trailing slashes.
    '"' + ([regex]::Replace($Value, '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-SetupProcess([string]$FilePath, [string[]]$Arguments) {
    $argumentLine = ($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $process = $null
    try {
        # Keep native download/installer output visible in the current terminal.
        $process = Start-Process -FilePath $FilePath -ArgumentList $argumentLine -NoNewWindow -PassThru -ErrorAction Stop
        # Windows PowerShell 5.1 needs an open handle to retain the exit code.
        $null = $process.Handle
        $nextNotice = 15
        while (-not $process.WaitForExit(1000)) {
            if ($clock.Elapsed.TotalSeconds -ge $nextNotice) {
                Write-Ui ('  Still working - elapsed {0:mm\:ss}.' -f $clock.Elapsed) -ForegroundColor DarkGray
                $nextNotice += 15
            }
        }
        $process.WaitForExit()
        if ($null -eq $process.ExitCode) { throw 'The installer exited without a readable exit code. Check its result before retrying.' }
        return [int]$process.ExitCode
    } finally {
        if ($null -ne $process) { $process.Dispose() }
        $clock.Stop()
    }
}

function Install-Msi($Item, $Url, [string[]]$Properties=@()) {
    if (-not $PSCmdlet.ShouldProcess($Item.Name, "Download and install official MSI from $Url")) {
        return (New-InstallResult $Item 'Skipped' 'Installation was not approved.')
    }
    $path = Join-Path ([IO.Path]::GetTempPath()) "workstation-$([guid]::NewGuid()).msi"
    try {
        Write-Ui "Downloading $($Item.Name)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing -ErrorAction Stop
        Write-Ui "Installing $($Item.Name)..." -ForegroundColor Yellow
        $code = Invoke-SetupProcess 'msiexec.exe' (@('/i',$path,'/qn','/norestart')+$Properties)
        if ($code -notin @(0,1641,3010)) { return (New-InstallResult $Item 'Failed' "MSI exit code $code." $code) }
        return (New-InstallResult $Item 'Installed' '' $code ($code -in @(1641,3010)))
    } catch { return (New-InstallResult $Item 'Failed' $_.Exception.Message 'MSI') }
    finally {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }
}

function Install-One($Item) {
    try {
    if ($Item.Type -eq 'WinGet') {
        if (-not $PSCmdlet.ShouldProcess($Item.Name, 'Install with WinGet')) { return (New-InstallResult $Item 'Skipped') }
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) { return (New-InstallResult $Item 'Failed' 'WinGet is unavailable. Install or update App Installer from Microsoft Store, then scan again.' 'WINGET') }
        Write-Ui "Installing $($Item.Name)..." -ForegroundColor Yellow
        $code = Invoke-SetupProcess $winget.Source @('install','--id',$Item.Id,'--exact','--source',$Item.Source,'--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
        if ($code -eq 0) { return (New-InstallResult $Item 'Installed') }
        if ($code -in @(-1978334967,-1978334965)) { return (New-InstallResult $Item 'Installed' 'The installer reported a restart.' $code $true) }
        if ($code -eq -1978334966) { return (New-InstallResult $Item 'Failed' 'Restart Windows before retrying this installation.' $code $true) }
        if ($code -eq -1978335189) {
            $detection = Test-Installed $Item
            if ($detection.State -eq 'Installed') { return (New-InstallResult $Item 'Already installed' 'No applicable update.') }
        }
        return (New-InstallResult $Item 'Failed' "WinGet exit code $code. See the installer output above and WinGet diagnostic logs." $code)
    }
    if ($Item.Type -eq 'AzureCLI') { Install-Msi $Item 'https://aka.ms/installazurecliwindowsx64'; return }
    if ($Item.Type -eq 'PowerShell') {
        if (-not $PSCmdlet.ShouldProcess($Item.Name, 'Find and install latest stable official MSI')) { return (New-InstallResult $Item 'Skipped') }
        Write-Ui 'Finding the latest stable PowerShell release...' -ForegroundColor Yellow
        $release = Invoke-RestMethod 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -TimeoutSec 60
        $nativeArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
        $arch = if ($nativeArch -eq 'ARM64') {'arm64'} else {'x64'}
        $asset = $release.assets | Where-Object name -match "win-$arch\.msi$" | Select-Object -First 1
        if (-not $asset) { throw "No stable PowerShell MSI found for $arch." }
        Install-Msi $Item $asset.browser_download_url @('ADD_PATH=1','USE_MU=1','ENABLE_MU=1')
        return
    }
    if ($Item.Type -eq 'Module') {
        if (-not $PSCmdlet.ShouldProcess($Item.Name, 'Install from PSGallery in PowerShell 7')) { return (New-InstallResult $Item 'Skipped') }
        if (-not (Test-Path $pwshPath)) { return (New-InstallResult $Item 'Failed' 'PowerShell 7 is not available. Its installation may have failed or may require a restart.' 'PWSH') }
        Write-Ui "Installing $($Item.Name)..." -ForegroundColor Yellow
        $id = $Item.Id.Replace("'", "''")
        $command = "try { `$ErrorActionPreference='Stop'; Install-Module '$id' -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -Confirm:`$false -ErrorAction Stop; if(-not (Get-Module -ListAvailable '$id' -ErrorAction Stop)){throw 'Module not found after installation.'}; exit 0 } catch { Write-Host `$_.Exception.Message -ForegroundColor Red; exit 1 }"
        $code = Invoke-SetupProcess $pwshPath @('-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand',(ConvertTo-EncodedCommand $command))
        if ($code -eq 0) { return (New-InstallResult $Item 'Installed') }
        return (New-InstallResult $Item 'Failed' "Module installation failed (exit $code). See the error above." $code)
    }
    return (New-InstallResult $Item 'Failed' "Unsupported catalog type: $($Item.Type)")
    } catch { return (New-InstallResult $Item 'Failed' $_.Exception.Message 'INSTALL') }
}

function Resolve-InstallDependencies([object[]]$Items) {
    $plan = @($Items)
    if (@($plan | Where-Object Type -eq 'Module').Count -and
        -not (Test-Path $pwshPath) -and
        -not @($plan | Where-Object Type -eq 'PowerShell').Count) {
        $dependency = $catalog | Where-Object Type -eq 'PowerShell' | Select-Object -First 1
        if (-not $dependency) { $dependency = New-ItemDefinition 'PowerShell 7' 'PowerShell7' 'Azure and Microsoft 365' 'PowerShell' 'Official MSI' }
        Write-Ui 'PowerShell 7 is required by the selected modules and has been added to the plan.' -ForegroundColor Yellow
        $plan += $dependency
    }
    @($plan | Sort-Object @{Expression={if($_.Type-eq'PowerShell'){0}elseif($_.Type-eq'Module'){2}else{1}}})
}

function Invoke-SoftwareWorkflow([switch]$All) {
    Show-Screen 'SOFTWARE'
    Invoke-Audit
    Show-Audit
    $missing = @($catalog | Where-Object DetectionState -eq 'Missing')
    if (-not $missing.Count) {
        Write-Ui 'No missing software was found.' -ForegroundColor Green
        return $true
    }
    $selected = if ($All) { $missing } else { @(Select-InstallItems) }
    if (-not $selected.Count) { return $false }
    $selected = @(Resolve-InstallDependencies $selected)
    Write-Ui "`nSelected $($selected.Count) item(s):" -ForegroundColor Cyan
    $selected | ForEach-Object { Write-Ui "  - $($_.Name)" }
    if (-not $All -and -not (Confirm-Action 'Install the selected software?')) {
        Write-Ui 'Installation cancelled.' -ForegroundColor Yellow
        return $false
    }
    $successStatuses = @('Installed','Already installed')
    $results = @()
    $position = 0
    foreach ($item in $selected) {
        $position++
        Write-Ui "`n[$position/$($selected.Count)] $($item.Name)" -ForegroundColor Cyan
        try { $result = Install-One $item }
        catch { $result = New-InstallResult $item 'Failed' $_.Exception.Message }
        if ($null -eq $result) { $result = New-InstallResult $item 'Failed' 'Installer returned no result.' }
        $results += $result
        $color = if ($result.Status -in $successStatuses) { 'Green' } else { 'Yellow' }
        Write-Ui "  $($result.Status)" -ForegroundColor $color
        if ($result.Detail) { Write-Ui "  $($result.Detail)" -ForegroundColor DarkGray }
    }
    Write-Ui "`n[ SOFTWARE RESULTS ]" -ForegroundColor Cyan
    foreach ($result in $results) {
        $color = if ($result.Status -in $successStatuses) { 'Green' } else { 'Yellow' }
        Write-Ui "  [$($result.Status)] $($result.Name)" -ForegroundColor $color
        if ($result.Detail) { Write-Ui "    $($result.Detail)" -ForegroundColor DarkGray }
        if ($result.Reboot) { Write-Ui '    Restart required.' -ForegroundColor Yellow }
    }
    $completed = @($results | Where-Object { $_.Status -in $successStatuses }).Count
    $failed = @($results | Where-Object Status -eq 'Failed').Count
    $skipped = @($results | Where-Object Status -eq 'Skipped').Count
    Write-Ui "$completed completed, $failed failed, $skipped skipped." -ForegroundColor Cyan
    if (@($results | Where-Object Reboot).Count) { Write-Ui 'A restart is required. WinStation will not restart automatically.' -ForegroundColor Yellow }
    Write-Ui 'Restart the terminal before using newly installed command-line tools.' -ForegroundColor DarkGray
    return $true
}

# Read-only hardware inventory; no Windows Update calls, installers or files.
function Read-HardwareData {
    param([scriptblock]$Query)
    try { [pscustomobject]@{ Available=$true; Items=@(& $Query) } }
    catch { [pscustomobject]@{ Available=$false; Items=@() } }
}

function Format-HardwareSize($Bytes) {
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    return ('{0:N1} GiB' -f ($Bytes / 1GB))
}

function New-HardwareRow($Label, $Value, [Nullable[double]]$Percent=$null, [string]$MeterLabel='') {
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { $Value = 'Unavailable' }
    [pscustomobject]@{ Label=$Label; Value=[string]$Value; Percent=$Percent; MeterLabel=$MeterLabel }
}

function Get-SystemInformation {
    $system = Read-HardwareData { Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
    $os = Read-HardwareData { Get-CimInstance Win32_OperatingSystem -ErrorAction Stop }
    $release = Read-HardwareData {
        Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop
    }
    $cpus = Read-HardwareData { Get-CimInstance Win32_Processor -ErrorAction Stop }
    $memory = Read-HardwareData { Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop }
    $graphics = Read-HardwareData { Get-CimInstance Win32_VideoController -ErrorAction Stop }
    $disks = Read-HardwareData { Get-PhysicalDisk -ErrorAction Stop }
    $volumes = Read-HardwareData { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop }
    $network = Read-HardwareData { Get-NetAdapter -Physical -ErrorAction Stop }
    $batteries = Read-HardwareData { Get-CimInstance Win32_Battery -ErrorAction Stop }

    if ($system.Items.Count) {
        $pc = $system.Items[0]
        New-HardwareRow 'Computer' (($pc.Manufacturer, $pc.Model -join ' ').Trim())
        New-HardwareRow 'Computer name' $pc.Name
    } else { New-HardwareRow 'Computer' 'Unavailable' }
    if ($os.Items.Count) {
        $windows = $os.Items[0]
        New-HardwareRow 'Windows' ("{0} / {1} / version {2} / build {3}" -f $windows.Caption, $windows.OSArchitecture, $windows.Version, $windows.BuildNumber)
    } else { New-HardwareRow 'Windows' 'Unavailable' }
    # DisplayVersion is the release label (e.g. 25H2), not the internal NT version.
    $releaseLabel = if ($release.Items.Count) { $release.Items[0].DisplayVersion } else { $null }
    New-HardwareRow 'Windows release' $releaseLabel

    if (-not $cpus.Items.Count) { New-HardwareRow 'CPU' 'Unavailable' }
    foreach ($cpu in $cpus.Items) {
        New-HardwareRow 'CPU' ("{0} / {1} cores / {2} logical processors" -f ([string]$cpu.Name).Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
    }
    if ($memory.Items.Count) {
        $capacity = ($memory.Items | Measure-Object Capacity -Sum).Sum
        New-HardwareRow 'Installed RAM' ("{0} / {1} memory device(s)" -f (Format-HardwareSize $capacity), $memory.Items.Count)
        $index = 0
        foreach ($module in $memory.Items) {
            $index++
            $kind = switch ($module.SMBIOSMemoryType) {
                24 { 'DDR3' }; 26 { 'DDR4' }; 34 { 'DDR5' }
                default { 'Type unknown (SMBIOS {0})' -f $module.SMBIOSMemoryType }
            }
            $speed = if ($module.ConfiguredClockSpeed -gt 0) { "$($module.ConfiguredClockSpeed) MHz configured (firmware)" } else { 'Configured speed unknown' }
            New-HardwareRow ("Memory {0}" -f $index) ("{0} / {1} / {2}" -f (Format-HardwareSize $module.Capacity), $kind, $speed)
        }
    } elseif ($system.Items.Count -and $system.Items[0].TotalPhysicalMemory -gt 0) {
        New-HardwareRow 'RAM (OS usable)' (Format-HardwareSize $system.Items[0].TotalPhysicalMemory)
        New-HardwareRow 'Memory details' 'Unavailable'
    } else { New-HardwareRow 'RAM' 'Unavailable' }

    if (-not $graphics.Items.Count) { New-HardwareRow 'Graphics' 'Unavailable' }
    foreach ($gpu in $graphics.Items) {
        # Do not use AdapterRAM: its 32-bit value cannot describe modern VRAM reliably.
        New-HardwareRow 'Graphics' ("{0} / driver {1}" -f $gpu.Name, $gpu.DriverVersion)
    }
    if ($disks.Items.Count) {
        foreach ($disk in ($disks.Items | Sort-Object DeviceId)) {
            New-HardwareRow ("Physical disk {0}" -f $disk.DeviceId) ("{0} / {1} / {2} / {3}" -f $disk.FriendlyName, (Format-HardwareSize $disk.Size), $disk.MediaType, $disk.BusType)
        }
    } else {
        $diskFallback = Read-HardwareData { Get-CimInstance Win32_DiskDrive -ErrorAction Stop }
        if (-not $diskFallback.Items.Count) { New-HardwareRow 'Physical disks' 'Unavailable' }
        foreach ($disk in ($diskFallback.Items | Sort-Object Index)) {
            New-HardwareRow ("Physical disk {0}" -f $disk.Index) ("{0} / {1} / media type unavailable" -f $disk.Model, (Format-HardwareSize $disk.Size))
        }
    }
    # Volume capacity/free space belong together, never to an arbitrary physical disk.
    if (-not $volumes.Items.Count) { New-HardwareRow 'Volumes' 'Unavailable' }
    foreach ($volume in ($volumes.Items | Sort-Object DeviceID)) {
        $used = if ($volume.Size -gt 0 -and $null -ne $volume.FreeSpace -and $volume.FreeSpace -ge 0 -and $volume.FreeSpace -le $volume.Size) {
            100.0 * (1.0 - $volume.FreeSpace / $volume.Size)
        } else { $null }
        New-HardwareRow ("Volume {0}" -f $volume.DeviceID) ("{0} total / {1} free / {2}" -f (Format-HardwareSize $volume.Size), (Format-HardwareSize $volume.FreeSpace), $volume.FileSystem) $used 'used'
    }
    if (-not $network.Items.Count) { New-HardwareRow 'Network' 'No physical adapters detected, or data unavailable' }
    foreach ($adapter in ($network.Items | Sort-Object Name)) {
        New-HardwareRow 'Network' ("{0} / {1} / {2} / {3}" -f $adapter.Name, $adapter.InterfaceDescription, $adapter.Status, $adapter.LinkSpeed)
    }
    if (-not $batteries.Available) { New-HardwareRow 'Battery' 'Unavailable' }
    elseif (-not $batteries.Items.Count) { New-HardwareRow 'Battery' 'Not present' }
    foreach ($battery in $batteries.Items) {
        $chargePercent = $null
        $charge = if ($null -ne $battery.EstimatedChargeRemaining -and $battery.EstimatedChargeRemaining -ge 0 -and $battery.EstimatedChargeRemaining -le 100) {
            $chargePercent = [double]$battery.EstimatedChargeRemaining
            "$($battery.EstimatedChargeRemaining)% charge"
        } else { 'Charge unknown' }
        New-HardwareRow 'Battery' ("{0} / {1}" -f $battery.Name, $charge) $chargePercent 'charged'
    }
}

function Split-HardwareText {
    param([string]$Text, [int]$Width)
    $limit = [Math]::Max(1, $Width)
    $remaining = [regex]::Replace($Text, '\x1b\[[0-?]*[ -/]*[@-~]|[\x00-\x1f\x7f]', ' ')
    while ($remaining.Length -gt $limit) {
        $cut = $remaining.LastIndexOf(' ', $limit)
        if ($cut -le 0) { $cut = $limit }
        $remaining.Substring(0, $cut)
        $remaining = $remaining.Substring($cut).TrimStart()
    }
    $remaining
}

function Get-HardwareDisplayBlocks {
    param([object[]]$Rows, [int]$Width=80)
    $contentWidth = [Math]::Max(1, [Math]::Min(96, $Width - 4))
    $indent = ' ' * [Math]::Max(0, [Math]::Floor(($Width - $contentWidth) / 2))
    $sections = @(
        @{ Title='COMPUTER & WINDOWS'; Pattern='^(Computer|Windows)' },
        @{ Title='PROCESSOR & MEMORY'; Pattern='^(CPU|Installed RAM|RAM|Memory)' },
        @{ Title='STORAGE'; Pattern='^(Physical disk|Volume)' },
        @{ Title='GRAPHICS'; Pattern='^Graphics$' },
        @{ Title='NETWORK'; Pattern='^Network$' },
        @{ Title='BATTERY'; Pattern='^Battery$' }
    )
    $knownPatterns = ($sections | ForEach-Object { '(' + $_.Pattern + ')' }) -join '|'
    $sections += @{ Title='OTHER'; Pattern='^(?!' + $knownPatterns + ').*$' }
    foreach ($section in $sections) {
        $items = @($Rows | Where-Object Label -match $section.Pattern)
        if (-not $items.Count) { continue }
        [pscustomobject]@{ Prefix=''; Text=''; Color='White'; Bold=$false }
        foreach ($line in (Split-HardwareText $section.Title $contentWidth)) {
            [pscustomobject]@{ Prefix=$indent; Text=$line; Color='Yellow'; Bold=$true }
        }
        [pscustomobject]@{ Prefix=$indent; Text=('-' * $contentWidth); Color='DarkRed'; Bold=$false }
        $labelWidth = [Math]::Min(24, ($items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum)
        foreach ($row in $items) {
            $valueWidth = $contentWidth
            $valueIndent = $indent
            if ($contentWidth -ge 50 -and $row.Label.Length -le $labelWidth) {
                $valueWidth = $contentWidth - $labelWidth - 3
                $prefix = $indent + $row.Label.PadRight($labelWidth) + '   '
                $valueIndent = $indent + (' ' * ($labelWidth + 3))
            } else {
                foreach ($line in (Split-HardwareText ($row.Label.TrimEnd(':') + ':') $contentWidth)) {
                    [pscustomobject]@{ Prefix=$indent; Text=$line; Color='Gray'; Bold=$false }
                }
                $prefix = $indent
            }
            foreach ($line in (Split-HardwareText $row.Value $valueWidth)) {
                $valueColor = if ($row.Value -in @('Unavailable','Not present')) { 'DarkGray' } else { 'White' }
                [pscustomobject]@{ Prefix=$prefix; Text=$line; Color=$valueColor; Bold=($row.Label -eq 'Windows release') }
                $prefix = $valueIndent
            }
            if ($null -ne $row.Percent -and $row.Percent -ge 0 -and $row.Percent -le 100) {
                $caption = '{0:0}% {1}' -f $row.Percent, $row.MeterLabel
                $barWidth = [Math]::Min(20, $valueWidth - $caption.Length - 3)
                $meter = $caption
                if ($barWidth -ge 5) {
                    $filled = [int][Math]::Floor($barWidth * $row.Percent / 100)
                    $meter = '[' + ('#' * $filled) + ('.' * ($barWidth - $filled)) + '] ' + $caption
                }
                foreach ($line in (Split-HardwareText $meter $valueWidth)) {
                    [pscustomobject]@{ Prefix=$valueIndent; Text=$line; Color='Yellow'; Bold=$false }
                }
            }
            if ($contentWidth -lt 50) { [pscustomobject]@{ Prefix=''; Text=''; Color='White'; Bold=$false } }
        }
    }
}

function Show-SystemInformation {
    Show-Banner
    Write-Ui
    Write-Centered '[ SYSTEM INFORMATION ]' 'Cyan' -Bold
    Write-Centered 'Reading local hardware information...' 'DarkGray'
    $rows = @(Get-SystemInformation)
    Show-Banner
    Write-Ui
    Write-Centered '[ SYSTEM INFORMATION ]' 'Cyan' -Bold
    Write-Centered 'Local hardware overview' 'DarkGray'
    foreach ($block in (Get-HardwareDisplayBlocks -Rows $rows -Width (Get-ConsoleWidth))) {
        Write-Ui $block.Prefix -ForegroundColor DarkGray -NoNewline
        Write-Ui $block.Text -ForegroundColor $block.Color -Bold:$block.Bold
    }
    Write-Ui
}

# Local USB storage identification only. Never modifies devices or Intune policies.
function ConvertTo-UsbDeviceRecord {
    param($Disk)
    $instancePath = [string]$Disk.PNPDeviceID
    $serial = $null
    $candidate = $null
    # Preserve the legacy extraction as an explicitly unverified candidate.
    # Ampersands can occur in instance IDs; a format check cannot validate them.
    if ($instancePath -match '^USBSTOR\\[^\\]+\\(?<Instance>[^\\]+)$') {
        $candidate = $Matches.Instance -replace '&0$', ''
        if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = $null }
    }
    $status = 'Unavailable - verify the device instance path in Device Manager or Defender.'
    # Accept only the documented USBSTOR shape; generated IDs with extra "&"
    # components and SCSI/UASP instance IDs must not be presented as serials.
    if ($instancePath -match '^USBSTOR\\[^\\]+\\(?<Serial>[A-Za-z0-9._-]+)(?:&0)?$') {
        $serial = $Matches.Serial
        $status = 'Candidate from USBSTOR path - verify against the serial used by your policy.'
    }
    if ($null -eq $serial -and $null -ne $candidate) {
        $status = 'Unverified format - SerialCandidate preserves the old extraction; verify in Defender before using it in a policy.'
    }
    [pscustomobject]@{
        Model = [string]$Disk.Model
        SizeGiB = if ($null -ne $Disk.Size -and $Disk.Size -gt 0) { [math]::Round($Disk.Size / 1GB, 2) } else { $null }
        DiskNumber = $Disk.Index
        SerialNumberId = $serial
        SerialCandidate = $candidate
        SerialStatus = $status
        DeviceReportedSerial = ([string]$Disk.SerialNumber).Trim()
        InterfaceType = [string]$Disk.InterfaceType
        InstancePathId = $instancePath
    }
}

function Get-UsbDeviceReport {
    # Disk Index and Get-Disk Number identify the same OS disk, unlike drive letters.
    $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)
    $usbNumbers = @()
    $warning = ''
    try {
        $usbNumbers = @(Get-Disk -ErrorAction Stop | Where-Object { $_.BusType -eq 'USB' } |
            ForEach-Object { if ($null -ne $_.Number) { [int]$_.Number } })
    } catch {
        $warning = 'USB bus lookup unavailable; some USB/UASP devices may be missing.'
    }
    $devices = @(
        foreach ($disk in $disks) {
            if ($disk.InterfaceType -eq 'USB' -or ([string]$disk.PNPDeviceID).StartsWith('USBSTOR\', [StringComparison]::OrdinalIgnoreCase) -or
                ($null -ne $disk.Index -and $usbNumbers -contains [int]$disk.Index)) {
                ConvertTo-UsbDeviceRecord $disk
            }
        }
    )
    [pscustomobject]@{ Devices=$devices; Warning=$warning }
}

function Show-UsbDeviceIds {
    Show-Banner
    Write-Ui
    Write-Centered '[ USB DEVICE IDs ]' 'Cyan' -Bold
    Write-Ui
    try { $report = Get-UsbDeviceReport }
    catch {
        Write-Ui 'Could not read USB storage information. Check permissions and try again.' -ForegroundColor Red
        return
    }
    if ($report.Warning) { Write-Ui $report.Warning -ForegroundColor Yellow }
    if (-not $report.Devices.Count) {
        Write-Ui 'No USB storage devices detected. Connect a USB drive and run this option again.' -ForegroundColor Yellow
        return
    }
    Write-Ui 'Verify device IDs before using them in an Intune or Defender policy.' -ForegroundColor DarkGray
    foreach ($device in $report.Devices) {
        Write-Ui
        foreach ($property in @('Model','SizeGiB','DiskNumber','SerialNumberId','SerialCandidate','SerialStatus','DeviceReportedSerial','InterfaceType','InstancePathId')) {
            $value = [string]$device.$property
            if ([string]::IsNullOrWhiteSpace($value)) { $value = 'Unavailable' }
            # No Format-Table truncation or embedded control characters.
            $value = [regex]::Replace($value, '[\x00-\x1f\x7f]', ' ')
            Write-Ui ("  {0}: {1}" -f $property, $value) -ForegroundColor White
        }
    }
    Write-Ui
}

function Read-MainMenuKey {
    [Console]::ReadKey($true)
}

function Write-ArrowMenu {
    param([object[]]$Items, [int]$Selected, [int]$Width, [string]$ExitHint, [string]$ShortcutHint)
    $menuWidth = ($Items | ForEach-Object { $_.Text.Length } | Measure-Object -Maximum).Maximum + 3
    $padding = ' ' * [Math]::Max(0, [Math]::Floor(($Width - $menuWidth) / 2))
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $active = $i -eq $Selected
        $marker = if ($active) { ' > ' } else { '   ' }
        $color = if ($active) { 'Yellow' } else { $Items[$i].Color }
        Write-Ui ($padding + $marker + $Items[$i].Text.PadRight($menuWidth - 3)) -ForegroundColor $color -Bold:$active
    }
    Write-Ui
    Write-Centered "Up/Down: select | Enter: open | $ExitHint" 'DarkGray'
    Write-Centered $ShortcutHint 'DarkGray'
}

function Show-MainMenu {
    $menuLines = @(
        @{ Text='[1]  Check drivers and choose updates'; Color='White' },
        @{ Text='[2]  Check apps and choose installs'; Color='White' },
        @{ Text='[3]  Windows 11 actions'; Color='White' },
        @{ Text='[4]  System information'; Color='White' },
        @{ Text='[5]  USB device IDs'; Color='White' },
        @{ Text='[Q]  Quit'; Color='DarkGray' }
    )
    Show-ChoiceMenu -Title 'MAIN MENU' -MenuLines $menuLines -ExitKey 'Q' -ExitHint 'Q: select quit' -ShortcutHint '1-5: select a shortcut, then press Enter.'
}

function Show-ChoiceMenu {
    param(
        [string]$Title,
        [object[]]$MenuLines,
        [string]$ExitKey,
        [string]$ExitHint,
        [string]$ShortcutHint,
        [switch]$EscapeToExit
    )
    Write-Ui
    Write-Centered "[ $Title ]" 'Cyan' -Bold
    Write-Ui
    $width = Get-ConsoleWidth
    $menuWidth = ($menuLines | ForEach-Object { $_.Text.Length } | Measure-Object -Maximum).Maximum
    $minimumWidth = [Math]::Max(48, $menuWidth + 4)
    $keys = @($menuLines | ForEach-Object { $_.Text.Substring(1,1) })
    $useArrows = $false
    try {
        $useArrows = $Host.Name -eq 'ConsoleHost' -and
            -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
            $width -ge $minimumWidth -and [Console]::WindowHeight -ge ($menuLines.Count + 8)
    } catch {}
    if ($useArrows) {
        $selected = 0
        $previousCursor = $null
        try {
            $previousCursor = [Console]::CursorVisible
            [Console]::CursorVisible = $false
            $redraw = $true
            $reserveSpace = $true
            $height = [Console]::WindowHeight
            while ($true) {
                $newWidth = Get-ConsoleWidth
                $newHeight = [Console]::WindowHeight
                if ($newWidth -ne $width -or $newHeight -ne $height) {
                    $width = $newWidth
                    $height = $newHeight
                    # Rebuild the current screen after terminal reflow.
                    Show-Banner -Still
                    if ($width -lt $minimumWidth -or $height -lt ($menuLines.Count + 8)) {
                        return (Show-ChoiceMenu -Title $Title -MenuLines $MenuLines -ExitKey $ExitKey -ExitHint $ExitHint -ShortcutHint $ShortcutHint -EscapeToExit:$EscapeToExit)
                    }
                    Write-Ui
                    Write-Centered "[ $Title ]" 'Cyan' -Bold
                    Write-Ui
                    $reserveSpace = $true
                    $redraw = $true
                }
                if ($reserveSpace) {
                    # Reserve rows first so scrolling cannot invalidate the menu position.
                    $rowCount = $menuLines.Count + 3
                    for ($row = 0; $row -lt $rowCount; $row++) { Write-Ui }
                    $menuTop = [Console]::CursorTop - $rowCount
                    $reserveSpace = $false
                }
                if ($redraw) {
                    [Console]::SetCursorPosition(0, $menuTop)
                    Write-ArrowMenu -Items $menuLines -Selected $selected -Width $width -ExitHint $ExitHint -ShortcutHint $ShortcutHint
                    $redraw = $false
                }
                if (-not [Console]::KeyAvailable) {
                    Start-Sleep -Milliseconds 50
                    continue
                }
                $key = Read-MainMenuKey
                switch ($key.Key.ToString()) {
                    'UpArrow' { $selected = ($selected + $menuLines.Count - 1) % $menuLines.Count; $redraw = $true }
                    'DownArrow' { $selected = ($selected + 1) % $menuLines.Count; $redraw = $true }
                    'Home' { $selected = 0; $redraw = $true }
                    'End' { $selected = $menuLines.Count - 1; $redraw = $true }
                    'Enter' { return $keys[$selected] }
                    'Escape' { if ($EscapeToExit) { return $ExitKey } }
                    default {
                        $shortcut = ([string]$key.KeyChar).ToUpperInvariant()
                        $index = [Array]::IndexOf($keys, $shortcut)
                        if ($index -ge 0) { $selected = $index; $redraw = $true }
                    }
                }
            }
        } catch {
            # Hosts without reliable cursor/key access retain the text prompt.
            Write-Ui
            Write-Ui "Keyboard navigation unavailable. Use a number or $ExitKey below." -ForegroundColor DarkGray
        } finally {
            if ($null -ne $previousCursor) {
                try { [Console]::CursorVisible = $previousCursor } catch {}
            }
        }
    }
    $padding = ' ' * [Math]::Max(0, [Math]::Floor(($width - $menuWidth) / 2))
    foreach ($line in $menuLines) {
        if ($width -le $menuWidth + 2) { Write-Centered $line.Text $line.Color }
        else {
            $keyColor = if ($line.Text.Substring(1,1) -eq $ExitKey) { 'DarkGray' } else { 'Red' }
            Write-Ui ($padding + $line.Text.Substring(0,3)) -ForegroundColor $keyColor -NoNewline
            Write-Ui $line.Text.Substring(3) -ForegroundColor $line.Color
        }
    }
    Write-Ui
    Write-Centered 'Type a menu number/letter and press Enter.' 'DarkGray'
    (Read-Centered 'Selection').Trim().ToUpper()
}


# ============================== ENTRY POINT ==============================
Show-Banner -Welcome
if ($WhatIfPreference) {
    Invoke-Audit
    Show-Audit
    Write-Ui 'WHAT-IF audit finished. Nothing was downloaded or installed.' -ForegroundColor Magenta
    return
}
if ($InstallAll) { [void](Invoke-SoftwareWorkflow -All); return }

do {
    $mainChoice = Show-MainMenu
    $pauseBeforeMenu = $mainChoice -notin @('2','3','Q')
    try {
        switch ($mainChoice) {
            '1' { Install-DriversFromWindowsUpdate }
            '2' { $pauseBeforeMenu = [bool](Invoke-SoftwareWorkflow) }
            '3' { Show-WindowsActions }
            '4' { Show-SystemInformation }
            '5' { Show-UsbDeviceIds }
            'Q' { Show-Banner -Goodbye }
            default { Write-Ui 'Invalid selection.' -ForegroundColor Yellow }
        }
    } catch {
        Write-Ui ("Action failed: " + $_.Exception.Message) -ForegroundColor Red
        $pauseBeforeMenu = $true
    }
    if ($mainChoice -ne 'Q') {
        if ($pauseBeforeMenu) { [void](Read-Host 'Press Enter to return to the main menu') }
        Show-Banner -Waiting
    }
} until ($mainChoice -eq 'Q')
