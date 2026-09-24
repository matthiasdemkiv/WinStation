# WinStation Notes

WinStation is a self-contained PowerShell 5.1+ script. No module, font, image,
or extra asset file needs to be copied alongside it.

## Open The Wizard

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\WinStation.ps1"
```

Opening the menu does not start a scan. Select the workflow you want to use from
the menu. Software and driver installs require item selection in the interactive
wizard. Windows actions retain their own confirmations and should be reviewed
before use.

The explicit `-InstallAll` switch remains an unattended software-installation
option. It installs only items reported as missing, includes PowerShell 7 when
required by selected modules, and bypasses the
interactive software selection flow. Do not use it just to preview the script.

## Checks And Installation Results

App checks report `Installed`, `Missing`, or `Could not check`. Missing WinGet,
source failures and unexpected exit codes are check errors, not proof that an
app is missing. Unchecked items are excluded from installation. Install or update
App Installer from Microsoft Store if WinGet is unavailable, then reopen the wizard.

Selecting a module without PowerShell 7 adds the official PowerShell MSI to the
plan shown before confirmation. PowerShell runs first. Module failures are
reported individually if the dependency could not be installed.

Software installation shows the current item and native installer output. The
final summary includes each result and reported restart requirements, and failed
items can be retried with `R`. WinStation does not request an automatic restart;
third-party installers still control their own behavior.

## Separate Admin Account

When an employee is signed in without administrator rights and an IT account
(for example `admmatik`) elevates WinStation, results go to the employee or to
all users, never only to the admin profile:

- WinGet apps install machine-wide. Apps that only have a per-user installer, or
  refuse administrator rights, install for the signed-in employee.
- Microsoft Store apps always install for the signed-in employee.
- PowerShell modules install for all users (`AllUsers`), so both the employee and
  the admin account can use them for Azure and Microsoft Graph.
- The app scan checks what the signed-in employee has installed.
- The classic context menu is written to the employee's registry.

Per-user installs run through a temporary scheduled task as the signed-in user;
the task and its files are removed afterwards.

## Preparing A PC For Someone Else

When the administrator is also the signed-in account, WinStation asks who the
apps are for before installing:

- `[1]` the signed-in account: everything installs, per-user apps for that account.
- `[2]` someone who signs in later: only apps with a machine-wide installer are
  installed. Microsoft Store apps and per-user-only apps (for example Discord or
  Spotify) are skipped and listed at the end.

Recommended workflow: prepare the PC with `[2]`, join the domain, and after the
user's first sign-in run WinStation again from the admin account to add the
remaining apps. Per-user settings such as the classic context menu belong in
Group Policy on domain PCs.

## Driver Selection

The driver list labels recognized BIOS/firmware and updates whose driver class
is unavailable. `Select all regular drivers` excludes both groups. Individual
selection can include them; recognized firmware additionally requires typing
`FIRMWARE` before the normal installation confirmation.

Classification uses the driver class, hardware ID and update title supplied by
Windows Update. It cannot guarantee that every firmware package is recognized.
Follow the manufacturer's update instructions. Firmware can affect BitLocker
recovery; see [Microsoft's recovery guidance](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/recovery-overview).
WinStation does not suspend BitLocker or change recovery settings.

Download and installation results are checked per update. Failed downloads do
not enter the installation batch; partial failures are shown as needing attention.
The summary also shows restart requirements reported by Windows Update.

## Terminal Behavior

- Windows Terminal is preferred by the BAT launcher when available.
- The launcher falls back to Windows PowerShell 5.1 on clean Windows installs.
- The launcher sets a black background and white text before starting the script.
- The welcome display stays visible after playback; short windows may scroll.
- Driver checks and installation use text-only status messages.
- The main menu supports Up/Down and Enter; number shortcuts and Q select an item
  that is confirmed with Enter.
- Windows 11 actions uses the same navigation. B selects Back and Enter confirms;
  Esc returns immediately.
- Prompts inside Windows 11 actions show B as an explicit Cancel option. Empty
  or invalid values still show their validation message.
- Driver checks are available from the main menu, not duplicated in Windows actions.
- Returning to the main menu is immediate and leaves the mascot visible in a
  static waiting pose.
- System information groups hardware into sections with aligned values, volume
  usage and battery charge bars. Narrow windows wrap values without truncation.
- Small windows and hosts without console key access use a typed selection.
- Resizing rebuilds the current menu using the new terminal size.
- Redirected output uses text instead of terminal cursor drawing.
- Use `-NoAnimation` if a static display is preferred.

`-WhatIf` retains the software-audit-only behavior. It does not install
software, but the audit can read WinGet sources and their metadata.

## Validation

Local development tests use fake package detections and Windows Update objects.
They cover software scan results/errors, cancellation, confirmation, driver
`-WhatIf`, quitting, hardware inventory and USB IDs.

These tests are not included in the production-only repository tree and do not
verify actual application or driver installation on every computer.
