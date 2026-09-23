@echo off
setlocal DisableDelayedExpansion
rem Keep this launcher beside WinStation.ps1. No fixed drive letter.
set "WINSTATION_SCRIPT=%~dp0WinStation.ps1"
set "WINSTATION_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
rem Use native 64-bit Windows PowerShell when launched from a 32-bit process.
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "WINSTATION_POWERSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%WINSTATION_SCRIPT%" (
    echo The companion WinStation.ps1 file is missing.
    echo Copy this BAT file and its PS1 file into the same folder, then try again.
    pause
    exit /b 1
)
rem The BAT uses Windows PowerShell only as a bootstrapper. If Windows Terminal
rem is available, the elevated wizard opens there; otherwise it falls back to a
rem normal PowerShell window with black background and white text.
"%WINSTATION_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $target=$env:WINSTATION_SCRIPT; if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'The companion WinStation.ps1 file is missing.' }; $workDir=Split-Path -Parent $target; $literal=$target.Replace('''',''''''); $inner='$Host.UI.RawUI.BackgroundColor=''Black''; $Host.UI.RawUI.ForegroundColor=''White''; Clear-Host; & '''+$literal+''''; $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner)); $psArgs=@('-NoLogo','-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded); $wt=Get-Command wt.exe -ErrorAction SilentlyContinue; if ($wt) { Start-Process -FilePath $wt.Source -ArgumentList (@('-w','0','nt','--title','WinStation','--suppressApplicationTitle','powershell.exe') + $psArgs) -WorkingDirectory $workDir -Verb RunAs -WindowStyle Normal -ErrorAction Stop; exit 0 }; Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $psArgs -WorkingDirectory $workDir -Verb RunAs -WindowStyle Normal -ErrorAction Stop; exit 0 } catch { Write-Host ('WinStation could not start: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
    echo Launch cancelled or failed. No installation was requested by this launcher.
    pause
    exit /b 1
)
exit /b 0
