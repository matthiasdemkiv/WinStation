# Customize WinStation

This guide is for editing WinStation without needing to understand the whole
PowerShell script. Most people only need to edit the software catalog.

## Files You Normally Edit

WinStation has one production script:

- `WinStation.ps1`

The portable launcher does not contain the app list:

- `Run-WinStation.bat`

It only starts the PowerShell script as administrator.

## Find The Catalog

Open the script and search for this heading:

```powershell
# CUSTOMIZE THE SOFTWARE CATALOG HERE
```

The catalog starts like this:

```powershell
$catalog = @(
    New-ItemDefinition 'Google Chrome' 'Google.Chrome' 'Web Browsers'
    New-ItemDefinition 'Git' 'Git.Git' 'Development Tools'
)
```

Each line is one installable item.

## Add A Normal WinGet App

Normal WinGet apps use this format:

```powershell
New-ItemDefinition 'Display Name' 'Publisher.PackageId' 'Category Name'
```

Example:

```powershell
New-ItemDefinition 'Steam' 'Valve.Steam' 'Gaming'
```

The category name is created automatically. If you add a new category, the menu
will show it without any other code change.

## Add A Microsoft Store App

Microsoft Store apps use a Store product ID and the `msstore` source:

```powershell
New-ItemDefinition 'Display Name' 'StoreProductId' 'Category Name' 'WinGet' 'msstore'
```

Examples:

```powershell
New-ItemDefinition 'ChatGPT' '9PLM9XGG6VKS' 'AI' 'WinGet' 'msstore'
New-ItemDefinition 'WhatsApp' '9NKSQGP7F2NH' 'Communication' 'WinGet' 'msstore'
```

Store IDs can change when publishers replace an app with a newer listing. If an
app installs the wrong product, search the Microsoft Store source again before
assuming the script is broken.

## Find The Right Package ID

Use these commands in PowerShell or Windows Terminal.

Search normal WinGet packages:

```powershell
winget search "app name" --source winget
```

Search Microsoft Store packages:

```powershell
winget search "app name" --source msstore
```

Show package details before adding it:

```powershell
winget show --id Package.Id --exact --source winget
```

For Store apps:

```powershell
winget show --id StoreProductId --exact --source msstore
```

Prefer exact IDs over search names. Search names can match the wrong app.

## Remove Or Disable An App

To remove an app from the menu, delete its `New-ItemDefinition` line.

To temporarily disable an app, comment the line by adding `#` at the beginning:

```powershell
# New-ItemDefinition 'Steam' 'Valve.Steam' 'Gaming'
```

## Rename Or Move An App

Rename the first value to change what the menu displays:

```powershell
New-ItemDefinition 'Google Chrome' 'Google.Chrome' 'Web Browsers'
```

Change the third value to move the app to another category:

```powershell
New-ItemDefinition 'Google Chrome' 'Google.Chrome' 'Browsers'
```

## PowerShell, Azure CLI, And Modules

These entries are special and should only be copied if you understand what they
do:

```powershell
New-ItemDefinition 'PowerShell 7' 'PowerShell7' 'Azure and Microsoft 365' 'PowerShell' 'Official MSI'
New-ItemDefinition 'Azure CLI 64-bit' 'AzureCLI' 'Azure and Microsoft 365' 'AzureCLI' 'Official MSI'
New-ItemDefinition 'Microsoft Graph PowerShell' 'Microsoft.Graph' 'Azure and Microsoft 365' 'Module' 'PSGallery'
```

The script handles these differently from normal WinGet applications. Do not use
`Module` for a regular app.

## Editing Rules That Prevent Pain

- Use straight single quotes: `'like this'`.
- Do not use smart quotes copied from Word or a website.
- Keep one app per line.
- Do not add commas between catalog lines.
- Keep the app ID exact, including dots and capitalization.
- Keep the catalog lines in a predictable order so the scan result is easy to read.

## Test Without Installing

First, check that the script still opens, then quit from the main menu:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File ".\WinStation.ps1"
```

Then run the wizard normally and choose the software scan. The scan only checks
what is installed. It does not install anything until you explicitly select apps
and confirm the install.

To check the catalog without opening the menu, use PowerShell `-WhatIf`. It runs
only the software audit and exits; it never installs anything:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File ".\WinStation.ps1" -WhatIf
```

## Example Change

Before:

```powershell
New-ItemDefinition 'Spotify' 'Spotify.Spotify' 'Media'
```

After adding VLC under the same category:

```powershell
New-ItemDefinition 'Spotify' 'Spotify.Spotify' 'Media'
New-ItemDefinition 'VLC media player' 'VideoLAN.VLC' 'Media'
```

Run the script again. The new app will appear in the software scan and selection
menu automatically.

## When Something Installs The Wrong App

Check these first:

1. Confirm the package ID with `winget show`.
2. Confirm the source is correct: `winget` or `msstore`.
3. Search online for the current official package or Store ID.
4. Update the catalog line and test again.

This happened with ChatGPT: the old Store ID now installs ChatGPT Classic, while
the current ChatGPT app uses a newer Store product ID.
