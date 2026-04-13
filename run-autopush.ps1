$scriptPath = $PSScriptRoot
$autopushScript = Join-Path $scriptPath "autopush.ps1"

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "powershell.exe"
$pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$autopushScript`""
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

[System.Diagnostics.Process]::Start($pinfo) | Out-Null
