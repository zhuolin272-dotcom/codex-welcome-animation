[CmdletBinding()]
param(
    [ValidateSet('fast','full')][string]$Variant = 'fast',
    [string]$CodexPath,
    [switch]$ValidateOnly,
    [switch]$TestMode
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$logDirectory = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$logFile = Join-Path $logDirectory 'launch.log'
function Write-LaunchLog([string]$Message) { Add-Content -LiteralPath $logFile -Value ("{0:o} {1}" -f [DateTime]::Now,$Message) }
function Get-DesktopTarget([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'The supplied Codex desktop path does not exist.' }
    if ($Path -match '[\\/]OpenAI[\\/]Codex[\\/]bin[\\/]') { throw 'This is a Codex command-line backend, not the desktop app. Omit CodexPath to use the registered desktop application.' }
    return @{Kind='exe';Path=[IO.Path]::GetFullPath($Path)}
}
function Find-Codex {
    if ($CodexPath) { return Get-DesktopTarget $CodexPath }
    $configPath = Join-Path $root 'config.json'
    if (Test-Path -LiteralPath $configPath) {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($config.CodexPath -and (Test-Path -LiteralPath $config.CodexPath -PathType Leaf)) { return Get-DesktopTarget $config.CodexPath }
    }
    # The Store package may display as ChatGPT and use ChatGPT.exe. Match its
    # registered identity, never the CLI backend in LocalAppData/OpenAI/Codex/bin.
    $app = Get-StartApps -ErrorAction SilentlyContinue | Where-Object { $_.AppID -match '^OpenAI\.Codex_[^!]+!' } | Select-Object -First 1
    if ($app) { return @{ Kind='app'; Path=$app.AppID } }
    $running = Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.Path -and ($_.Path -match '[\\/]OpenAI\.Codex_' -or ($_.ProcessName -eq 'Codex' -and $_.Path -notmatch '[\\/]OpenAI[\\/]Codex[\\/]bin[\\/]')) } | Select-Object -First 1
    if ($running) { return Get-DesktopTarget $running.Path }
    throw 'Codex desktop was not found. Run Install.ps1 -CodexPath with the desktop application executable, not the Codex CLI.'
}
function Find-Edge {
    $paths = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe")
    foreach ($p in $paths) { if (Test-Path -LiteralPath $p -PathType Leaf) { return $p } }
    throw 'Microsoft Edge is required for the fullscreen splash.'
}
function Start-Codex([switch]$Reveal) {
    if ($TestMode) { return }
    if ($target.Kind -eq 'exe') { Start-Process -FilePath $target.Path -WindowStyle Normal | Out-Null }
    else { Start-Process -FilePath explorer.exe -ArgumentList ('shell:AppsFolder\'+$target.Path) -WindowStyle Normal | Out-Null }
    Write-LaunchLog ("DESKTOP requested kind={0} target={1}" -f $target.Kind,$target.Path)
    if (-not $Reveal) { return }
    $activationWatch=[Diagnostics.Stopwatch]::StartNew()
    while ($activationWatch.Elapsed.TotalSeconds -lt 10) {
        $desktop=Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object {
            $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.Path -and
            (($target.Kind -eq 'exe' -and $_.Path -eq $target.Path) -or
             ($target.Kind -eq 'app' -and $_.Path -match '[\\/]OpenAI\.Codex_'))
        } | Select-Object -First 1
        if ($desktop) {
            $handle=$desktop.MainWindowHandle
            if ([WelcomeWindow]::IsIconic($handle)) { [void][WelcomeWindow]::ShowWindowAsync($handle,9) }
            [void][WelcomeWindow]::SetForegroundWindow($handle)
            Start-Sleep -Milliseconds 100
            if ([WelcomeWindow]::IsWindowVisible($handle) -and [WelcomeWindow]::GetForegroundWindow() -eq $handle) {
                Write-LaunchLog ("DESKTOP confirmed pid={0} visible=True foreground=True" -f $desktop.Id)
                return
            }
        }
        Start-Sleep -Milliseconds 100
    }
    throw 'The Codex desktop window could not be brought to the foreground. See logs/launch.log.'
}
function Close-AnimationWindow {
    if ($browserProcess) {
        $browserProcess.Refresh()
        if (-not $browserProcess.HasExited) {
            [void]$browserProcess.CloseMainWindow()
            if (-not $browserProcess.WaitForExit(700)) { Stop-Process -Id $browserProcess.Id -ErrorAction SilentlyContinue }
        }
    }
}
$listener = $null; $browserProcess = $null; $mutex = $null; $ownsMutex = $false
try {
    Write-LaunchLog ("ENTRY variant={0} test={1}" -f $Variant,$TestMode.IsPresent)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WelcomeWindow {
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int z,uint flags);
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h,int index,int value);
 [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr h,uint key,byte alpha,uint flags);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int command);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@
    $edge = Find-Edge
    $target = if ($TestMode) { @{Kind='test';Path='none'} } else { Find-Codex }
    foreach ($file in @('docs\animation.html','docs\vendor\gsap.min.js')) { if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { throw "Missing resource: $file" } }
    if ($ValidateOnly) { [pscustomobject]@{Variant=$Variant;Edge=$edge;CodexKind=$target.Kind;Codex=$target.Path;Resources='OK'} | ConvertTo-Json; exit 0 }
    $created = $false
    $mutexName = if ($TestMode) {'Local\CodexWelcomeTest'} else {'Local\CodexWelcomeLauncher'}
    $mutex = New-Object System.Threading.Mutex($true,$mutexName,[ref]$created)
    if (-not $created) { Write-LaunchLog 'BUSY another animation is running'; exit 0 }; $ownsMutex=$true
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback,0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $nonce = [Guid]::NewGuid().ToString('N')
    $profileName = if ($TestMode) {'browser-test-profile'} else {'browser-profile'}
    $profile = Join-Path $root $profileName
    $url = "http://127.0.0.1:$port/animation.html?play=1&launch=1&variant=$Variant&token=$nonce"
    $browserArgs = @('--no-first-run','--no-default-browser-check',('--user-data-dir="'+$profile+'"'),'--disable-background-timer-throttling','--disable-renderer-backgrounding')
    if ($TestMode) { $browserArgs += @('--headless=new',$url) }
    else { $browserArgs += @('--kiosk',$url,'--edge-kiosk-type=fullscreen') }
    $windowStyle = if ($TestMode) {'Hidden'} else {'Normal'}
    $browserProcess = Start-Process -FilePath $edge -ArgumentList $browserArgs -PassThru -WindowStyle $windowStyle
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $ready = $false; $complete=$false; $codexStarted=$false; $topmost=$false; $window=[IntPtr]::Zero; $fadeStarted=-1.0
    $fadeDuration = if ($Variant -eq 'fast') {.7/1.6} else {.7}
    $routes = @{ '/animation.html'='docs\animation.html'; '/vendor/gsap.min.js'='docs\vendor\gsap.min.js'; '/favicon.ico'='assets\app.ico' }
    Write-LaunchLog ("START variant={0} test={1}" -f $Variant,$TestMode.IsPresent)
    while ($watch.Elapsed.TotalSeconds -lt 45 -and -not $complete) {
        if (-not $TestMode -and -not $topmost) {
            $browserProcess.Refresh(); $window=$browserProcess.MainWindowHandle
            if ($window -ne [IntPtr]::Zero) { $topmost=[WelcomeWindow]::SetWindowPos($window,[IntPtr](-1),0,0,0,0,0x53) }
        }
        if ($ready -and $topmost -and -not $codexStarted) { Start-Codex; $codexStarted=$true }
        if ($fadeStarted -ge 0 -and $window -ne [IntPtr]::Zero) {
            $v=[Math]::Max(0,[Math]::Min(1,($watch.Elapsed.TotalSeconds-$fadeStarted)/$fadeDuration))
            $v=$v*$v*(3-2*$v)
            [void][WelcomeWindow]::SetLayeredWindowAttributes($window,0,[byte][Math]::Round(255*(1-$v)),2)
        }
        if (-not $listener.Pending()) { Start-Sleep -Milliseconds 15; continue }
        $client=$listener.AcceptTcpClient(); $client.ReceiveTimeout=1500; $client.SendTimeout=1500
        try {
            $stream=$client.GetStream(); $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::ASCII,$false,4096,$true)
            $line=$reader.ReadLine(); if (-not $line) { continue }
            $parts=$line.Split(' '); if ($parts.Count -lt 2) { continue }
            $headerBytes=0
            while ($true) { $h=$reader.ReadLine(); if (-not $h) { break }; $headerBytes += $h.Length; if ($headerBytes -gt 16384) { throw 'Headers too large' } }
            $uri=[Uri]('http://127.0.0.1'+$parts[1]);$path=$uri.AbsolutePath
            $status='200 OK'; $contentType='application/json'; $body=[Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            if ($path -in @('/ready','/fade','/complete')) {
                $match=[regex]::Match($uri.Query,'(?:\?|&)token=([^&]+)')
                if ($parts[0] -ne 'POST' -or -not $match.Success -or $match.Groups[1].Value -cne $nonce) { $status='403 Forbidden' }
                elseif ($path -eq '/ready') { $ready=$true; Write-LaunchLog 'READY' }
                elseif ($path -eq '/fade') {
                    $fadeStarted=$watch.Elapsed.TotalSeconds
                    if ($window -ne [IntPtr]::Zero) { $old=[WelcomeWindow]::GetWindowLong($window,-20);[void][WelcomeWindow]::SetWindowLong($window,-20,($old -bor 0x80000));[void][WelcomeWindow]::SetLayeredWindowAttributes($window,0,255,2) }
                    Write-LaunchLog 'FADE'
                }
                else { $complete=$true;Write-LaunchLog ("COMPLETE elapsed={0:N3}s" -f $watch.Elapsed.TotalSeconds) }
            }
            elseif ($routes.ContainsKey($path) -and (Test-Path -LiteralPath (Join-Path $root $routes[$path]))) {
                $body=[IO.File]::ReadAllBytes((Join-Path $root $routes[$path]));$contentType=if($path.EndsWith('.js')){'text/javascript; charset=utf-8'}elseif($path.EndsWith('.ico')){'image/x-icon'}else{'text/html; charset=utf-8'}
            }
            else { $status='404 Not Found';$body=[Text.Encoding]::UTF8.GetBytes('Not found');$contentType='text/plain' }
            $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n")
            $stream.Write($headers,0,$headers.Length);$stream.Write($body,0,$body.Length);$stream.Flush()
        } catch { Write-LaunchLog ('Request skipped: '+$_.Exception.Message) }
        finally { $client.Close() }
    }
    if (-not $complete) { Write-LaunchLog 'TIMEOUT fallback handoff';if ($TestMode) { throw 'Animation completion was not received.' } }
    Close-AnimationWindow
    Start-Codex -Reveal
    if ($TestMode) { [pscustomobject]@{Variant=$Variant;Completed=$complete;ElapsedSeconds=[Math]::Round($watch.Elapsed.TotalSeconds,3)} | ConvertTo-Json }
}
catch {
    Write-LaunchLog ('ERROR '+$_.Exception.Message)
    if ($TestMode -or $ValidateOnly) { Write-Error $_; exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex Welcome')
    exit 1
}
finally {
    if ($listener) { $listener.Stop() }
    Close-AnimationWindow
    if ($mutex) { if($ownsMutex){$mutex.ReleaseMutex()};$mutex.Dispose() }
}
