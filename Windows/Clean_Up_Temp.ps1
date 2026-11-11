<#
.SYNOPSIS
    Clean up temp files: C:\Windows\Temp plus every user profile's AppData\Local\Temp. Run as admin.
.DESCRIPTION
    Deletes files older than -OlderThanDays (default 1) so in-use installer and Windows Update files are left alone,
    then removes empty folders. Skips junctions/symlinks. Locked files are skipped and counted.
    Works unattended (BeyondTrust / SYSTEM) - no prompts. Log: C:\Temp\Clean_Up_Temp_<HOST>_<yyyyMMdd_HHmmss>.log
    Exit codes: 0 = done (locked files are normal), 1 = not admin, 2 = unexpected error.
    BeyondTrust twin: Canned Script, Command Shell, elevated only:
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RESOURCE_FILE%"
    Standalone launcher: CMD\Clean_Up_Temp.cmd (put Clean_Up_Temp.ps1 beside it).
.PARAMETER OlderThanDays
    Only delete items last written more than this many days ago. 0 = everything that isn't locked.
.EXAMPLE
    .\Clean_Up_Temp.ps1 -WhatIf
    Shows sizes and what would be removed, deletes nothing.
.NOTES
    Rewrite of Old Scripts\Clean_Up_Temp.ps1, Nov 11, 2026. OS: Windows (PowerShell 5.1+).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 1
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Clean_Up_Temp needs Administrator rights. Run it as admin." -ForegroundColor Red
    exit 1
}

$logDir = 'C:\Temp'
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force -WhatIf:$false | Out-Null }
$log = Join-Path $logDir ("Clean_Up_Temp_{0}_{1:yyyyMMdd_HHmmss}.log" -f $env:COMPUTERNAME, (Get-Date))
Start-Transcript -LiteralPath $log -WhatIf:$false | Out-Null

function Clear-TempFolder {
    # Walks the folder once: deletes old files (summing bytes as it goes), then empty old subfolders.
    param([string]$Path, [string]$Label, [datetime]$Cutoff, [bool]$Delete)

    $r = [pscustomobject]@{ Label = $Label; Path = $Path; TotalMB = 0; FreedMB = 0; Files = 0; Folders = 0; Skipped = 0 }
    $total = 0L; $freed = 0L
    $dirs  = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
    $stack.Push((Get-Item -LiteralPath $Path -Force))

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try { $children = $dir.GetFileSystemInfos() }
        catch { $r.Skipped++; continue }

        foreach ($item in $children) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }   # never follow junctions/symlinks
            if ($item -is [System.IO.DirectoryInfo]) { $stack.Push($item); $dirs.Add($item); continue }

            $total += $item.Length
            if ($item.LastWriteTime -ge $Cutoff) { continue }
            if (-not $Delete) { $freed += $item.Length; continue }
            try {
                $len = $item.Length
                if ($item.IsReadOnly) { $item.IsReadOnly = $false }
                $item.Delete()
                $freed += $len; $r.Files++
            }
            catch { $r.Skipped++; Write-Verbose "Locked/denied: $($item.FullName)" }
        }
    }

    if ($Delete) {
        # Deepest first, so parents empty out as their children go.
        foreach ($d in ($dirs | Sort-Object { $_.FullName.Length } -Descending)) {
            if ($d.CreationTime -ge $Cutoff) { continue }
            try {
                if ($d.GetFileSystemInfos().Count -eq 0) { $d.Delete(); $r.Folders++ }
            }
            catch { Write-Verbose "Folder kept: $($d.FullName)" }
        }
    }

    $r.TotalMB = [math]::Round($total / 1MB, 2)
    $r.FreedMB = [math]::Round($freed / 1MB, 2)
    $r
}

try {
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $mode = if ($WhatIfPreference) { 'WHATIF - nothing deleted' } else { 'DELETE' }
    Write-Host "Clean_Up_Temp on $env:COMPUTERNAME as $env:USERNAME | $mode | older than $OlderThanDays day(s) ($cutoff)" -ForegroundColor Magenta

    # Build the folder list, de-duplicated by resolved full path (fixes 8.3 short-path double count).
    $targets = [ordered]@{}
    $add = {
        param($p, $label)
        if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Container)) { return }
        $full = (Get-Item -LiteralPath $p -Force).FullName.TrimEnd('\')
        if (-not $targets.Contains($full.ToLower())) { $targets[$full.ToLower()] = @($full, $label) }
    }
    & $add "$env:SystemRoot\Temp" 'Windows Temp'
    $skip = 'Public', 'Default', 'Default User', 'All Users'
    foreach ($userProfile in (Get-ChildItem -LiteralPath 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($userProfile.Name -in $skip -or ($userProfile.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        & $add (Join-Path $userProfile.FullName 'AppData\Local\Temp') "User $($userProfile.Name)"
    }
    & $add $env:TEMP 'Current user TEMP'

    $results = foreach ($t in $targets.Values) {
        $doDelete = $PSCmdlet.ShouldProcess($t[0], "Delete temp files older than $OlderThanDays day(s)")
        Clear-TempFolder -Path $t[0] -Label $t[1] -Cutoff $cutoff -Delete $doDelete
    }

    $results | Format-Table Label, TotalMB, FreedMB, Files, Folders, Skipped, Path -AutoSize | Out-String -Width 220 | Write-Host
    $sumTotal = ($results | Measure-Object TotalMB -Sum).Sum
    $sumFreed = ($results | Measure-Object FreedMB -Sum).Sum
    $verb = if ($WhatIfPreference) { 'Would free' } else { 'Freed' }
    Write-Host ("Temp total: {0:N2} MB | {1}: {2:N2} MB | Locked/skipped: {3}" -f $sumTotal, $verb, $sumFreed, ($results | Measure-Object Skipped -Sum).Sum) -ForegroundColor Green
    Write-Host "Log: $log"
    $rc = 0
}
catch {
    Write-Host "Clean_Up_Temp failed: $($_.Exception.Message)" -ForegroundColor Red
    $rc = 2
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
}
exit $rc
