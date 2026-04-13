Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot
$script:configPath = Join-Path $scriptDir "autopush-config.json"
$script:isPaused = $false
$script:pauseItem = $null

function LoadConfig {
    if (-not (Test-Path $script:configPath)) {
        Write-Host "Config file not found: $script:configPath"
        exit 1
    }
    return Get-Content $script:configPath | ConvertFrom-Json
}

function CheckAndPush {
    param([PSObject]$repo, [PSObject]$config)
    
    if (-not $repo.enabled) { return }
    
    try {
        # Fetch latest from remote
        git -C $repo.path fetch origin 2>$null
        
        # Count commits ahead of remote using rev-list (locale-independent)
        $aheadCount = git -C $repo.path rev-list --count "$($repo.branch)@{u}..$($repo.branch)" 2>$null
        $aheadCount = if ($aheadCount) { [int]$aheadCount } else { 0 }
        
        if ($aheadCount -gt 0) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($repo.path): ahead by $aheadCount, pushing..."
            git -C $repo.path push origin $repo.branch
            
            # Prepare log entry
            $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($repo.path) ($($repo.branch)): "
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($repo.path): push successful"
                $logEntry += "PUSH SUCCESS ($aheadCount commit(s))"
                $title = "AutoPush Success"
                $message = "$($repo.path)`nPushed $aheadCount commit(s)"
            } else {
                # Push failed (likely merge conflict or auth issue)
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($repo.path): push failed"
                $logEntry += "PUSH FAILED ($aheadCount commit(s) ahead)"
                $title = "AutoPush Failed"
                $message = "$($repo.path)`nFailed to push $aheadCount commit(s)"
            }
            
            # Only log on actual push events (not on every check)
            if ($config.logFile) {
                Add-Content -Path $config.logFile -Value $logEntry
            }
            
            # Send notification if enabled
            if ($config.showNotifications) {
                ShowNotification -Title $title -Message $message
            }
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error on $($repo.path): $($_.Exception.Message)"
    }
}

function ShowNotification {
    param([string]$Title, [string]$Message)
    
    try {
        $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("AutoPush").Show($toast)
    }
    catch {
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(5000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        $balloon.Visible = $false
        $balloon.Dispose()
    }
}

function CreateTrayIcon {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    
    $iconRunning = $config.iconRunning
    $iconPaused = $config.iconPaused
    
    if (Test-Path $iconRunning) {
        try {
            $tray.Icon = New-Object System.Drawing.Icon($iconRunning)
        }
        catch {
            Write-Host "Failed to load icon: $iconRunning"
            $tray.Icon = [System.Drawing.SystemIcons]::Application
        }
    }
    else {
        Write-Host "Icon not found: $iconRunning"
        $tray.Icon = [System.Drawing.SystemIcons]::Application
    }
    
    $tray.Visible = $true
    $tray.Text = "AutoPush - Running"
    
    $tray | Add-Member -MemberType NoteProperty -Name IconRunning -Value $iconRunning
    $tray | Add-Member -MemberType NoteProperty -Name IconPaused -Value $iconPaused
    
    $tray.Add_MouseClick({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            # Rebuild menu fresh on each right-click so text reflects current state
            $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
            
            $pauseItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $pauseItem.Text = if ($script:isPaused) { "Resume" } else { "Pause" }
             $pauseItem.Add_Click({
                 if ($null -eq $script:pauseItem) {
                     Write-Host "Error: pauseItem reference lost"
                     return
                 }
                 
                 $script:isPaused = -not $script:isPaused
                 $script:pauseItem.Text = if ($script:isPaused) { "Resume" } else { "Pause" }
                 $tray.Text = if ($script:isPaused) { "AutoPush - Paused" } else { "AutoPush - Running" }
                 
                 if ($script:isPaused -and (Test-Path $tray.IconPaused)) {
                     try {
                         $tray.Icon = New-Object System.Drawing.Icon($tray.IconPaused)
                     }
                     catch {
                         Write-Host "Failed to load paused icon: $($_.Exception.Message)"
                     }
                 }
                 elseif (-not $script:isPaused -and (Test-Path $tray.IconRunning)) {
                     try {
                         $tray.Icon = New-Object System.Drawing.Icon($tray.IconRunning)
                     }
                     catch {
                         Write-Host "Failed to load running icon: $($_.Exception.Message)"
                     }
                 }
             })
            $script:pauseItem = $pauseItem
            $contextMenu.Items.Add($pauseItem) | Out-Null
            
            $configItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $configItem.Text = "Edit Config"
            $configItem.Add_Click({
                & notepad $script:configPath
                $contextMenu.Close()
            })
            $contextMenu.Items.Add($configItem) | Out-Null
            
            $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
            
            $closeItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $closeItem.Text = "Close Menu"
            $closeItem.Add_Click({
                $contextMenu.Close()
            })
            $contextMenu.Items.Add($closeItem) | Out-Null
            
            $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
            
            $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $exitItem.Text = "Exit"
             $exitItem.Add_Click({
                 $tray.Visible = $false
                 $contextMenu.Close()
                 [System.Windows.Forms.Application]::Exit()
             })
            $contextMenu.Items.Add($exitItem) | Out-Null
            
            $contextMenu.Show([System.Windows.Forms.Cursor]::Position)
        }
    })
    
    return $tray
}

$config = LoadConfig

# Resolve relative paths in config (relative to script directory)
if ($config.logFile -and -not [System.IO.Path]::IsPathRooted($config.logFile)) {
    $config.logFile = Join-Path $PSScriptRoot $config.logFile
}
if (-not [System.IO.Path]::IsPathRooted($config.iconRunning)) {
    $config.iconRunning = Join-Path $PSScriptRoot $config.iconRunning
}
if (-not [System.IO.Path]::IsPathRooted($config.iconPaused)) {
    $config.iconPaused = Join-Path $PSScriptRoot $config.iconPaused
}

# Register startup shortcut if autoStart is enabled
if ($config.autoStart) {
    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutPath = Join-Path $startupFolder "AutoPush.lnk"
    
    if (-not (Test-Path $shortcutPath)) {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $link = $shell.CreateShortcut($shortcutPath)
            $link.TargetPath = Join-Path $PSScriptRoot "autopush.ps1"
            $link.Arguments = "-NoProfile -ExecutionPolicy Bypass"
            $link.WorkingDirectory = $PSScriptRoot
            $link.WindowStyle = 7  # Hidden
            $link.IconLocation = $config.iconRunning  # Use running icon
            $link.Save()
            Write-Host "AutoStart enabled: shortcut created"
        }
        catch {
            Write-Host "Failed to create startup shortcut: $($_.Exception.Message)"
        }
    }
}
else {
    # Remove startup shortcut if autoStart is disabled
    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutPath = Join-Path $startupFolder "AutoPush.lnk"
    if (Test-Path $shortcutPath) {
        try {
            Remove-Item $shortcutPath -Force
            Write-Host "AutoStart disabled: shortcut removed"
        }
        catch {
            Write-Host "Failed to remove startup shortcut: $($_.Exception.Message)"
        }
    }
}
$tray = CreateTrayIcon
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $config.checkInterval * 1000

# Timer tick: check all enabled repos for unpushed commits
$timer.Add_Tick({
    if (-not $script:isPaused) {
        foreach ($repo in $config.repositories) {
            CheckAndPush $repo $config
        }
    }
})

$timer.Start()

# Run the WinForms event loop
[System.Windows.Forms.Application]::Run()
