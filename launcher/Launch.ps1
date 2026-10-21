[CmdletBinding()]
param(
    [ValidateSet('fast','full')][string]$Variant = 'fast',
    [string]$CodexPath,
    [string]$WelcomeName,
    [switch]$ValidateOnly,
    [switch]$TestMode,
    [switch]$WindowTestMode
)
$ErrorActionPreference = 'Stop'
$verificationOnly=$TestMode -or $WindowTestMode
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
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.CodexPath -and (Test-Path -LiteralPath $config.CodexPath -PathType Leaf)) { return Get-DesktopTarget $config.CodexPath }
        # Installation resolves the Store identity once. Get-StartApps can block
        # for tens of seconds while Windows refreshes its entire Start menu.
        if ($config.CodexAppId -match '^OpenAI\.Codex_[A-Za-z0-9]+![A-Za-z0-9.]+$') { return @{Kind='app';Path=$config.CodexAppId} }
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
function Find-DesktopProcess {
    return Get-Process -Name Codex,ChatGPT -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.Path -and
        (($target.Kind -eq 'exe' -and $_.Path -eq $target.Path) -or
         ($target.Kind -eq 'app' -and $_.Path -match '[\\/]OpenAI\.Codex_'))
    } | Select-Object -First 1
}
function Prepare-MaximizedDesktop {
    $desktop=Find-DesktopProcess
    if (-not $desktop) { return $false }
    $handle=$desktop.MainWindowHandle
    if ([WelcomeWindow]::IsIconic($handle)) { [void][WelcomeWindow]::ShowWindowAsync($handle,9); return $false }
    if ([WelcomeWindow]::IsFullscreen($handle)) {
        [void][WelcomeWindow]::SetForegroundWindow($handle)
        if ($script:fullscreenExitRequestWindow -ne $handle -and [WelcomeWindow]::ExitNativeFullscreen($handle)) {
            $script:fullscreenExitRequestWindow=$handle
            Write-LaunchLog ("FULLSCREEN exit requested pid={0}" -f $desktop.Id)
        }
        return $false
    }
    if ([WelcomeWindow]::IsZoomed($handle)) { return $true }
    [void][WelcomeWindow]::ShowWindowAsync($handle,3)
    return $false
}
function Start-Codex([switch]$Reveal,[switch]$SkipLaunch) {
    if ($verificationOnly) { return }
    if (-not $SkipLaunch) {
        if ($target.Kind -eq 'exe') { Start-Process -FilePath $target.Path -WindowStyle Normal | Out-Null }
        else { Start-Process -FilePath explorer.exe -ArgumentList ('shell:AppsFolder\'+$target.Path) -WindowStyle Normal | Out-Null }
        Write-LaunchLog ("DESKTOP requested kind={0} target={1}" -f $target.Kind,$target.Path)
    }
    if (-not $Reveal) { return }
    $activationWatch=[Diagnostics.Stopwatch]::StartNew()
    while ($activationWatch.Elapsed.TotalSeconds -lt 10) {
        $prepared=Prepare-MaximizedDesktop
        $desktop=Find-DesktopProcess
        if ($desktop) {
            $handle=$desktop.MainWindowHandle
            if ([WelcomeWindow]::IsIconic($handle)) { [void][WelcomeWindow]::ShowWindowAsync($handle,9) }
            [void][WelcomeWindow]::SetForegroundWindow($handle)
            Start-Sleep -Milliseconds 100
            if ($prepared -and [WelcomeWindow]::IsWindowVisible($handle) -and [WelcomeWindow]::GetForegroundWindow() -eq $handle) {
                Write-LaunchLog ("DESKTOP confirmed pid={0} visible=True foreground=True maximized=True fullscreen=False" -f $desktop.Id)
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
function Disable-AnimationTranslation([string]$ProfilePath) {
    # This profile belongs exclusively to the splash. Never deserialize and
    # reserialize Edge's entire preferences in Windows PowerShell: adapted JSON
    # strings can accumulate metadata and grow exponentially on repeat launches.
    # A bounded, literal config also repairs an oversized previous preferences.
    $preferencesPath=Join-Path $ProfilePath 'Default\Preferences'
    New-Item -ItemType Directory -Path (Split-Path $preferencesPath -Parent) -Force | Out-Null
    $literal='{"translate":{"enabled":false},"signin":{"allowed":false},"credentials_enable_service":false,"profile":{"password_manager_enabled":false},"background_mode":{"enabled":false}}'
    [IO.File]::WriteAllText($preferencesPath,$literal,(New-Object Text.UTF8Encoding($false)))
}
$listener = $null; $browserProcess = $null; $mutex = $null; $ownsMutex = $false; $handoffOverlay=$null; $startupCover=$null
try {
    Write-LaunchLog ("ENTRY variant={0} test={1}" -f $Variant,$TestMode.IsPresent)
    $nativeLibrary=Join-Path $PSScriptRoot 'WelcomeNative.dll'
    if(-not (Test-Path -LiteralPath $nativeLibrary)){ & (Join-Path $PSScriptRoot 'BuildNative.ps1') }
    Add-Type -Path $nativeLibrary
    if(-not $ValidateOnly){
        $created = $false
        $mutexName = if ($verificationOnly) {'Local\CodexWelcomeTest'} else {'Local\CodexWelcomeLauncher'}
        $mutex = New-Object System.Threading.Mutex($true,$mutexName,[ref]$created)
        if (-not $created) { Write-LaunchLog 'BUSY another animation is running'; exit 0 }; $ownsMutex=$true
    }
    if(-not $TestMode -and -not $ValidateOnly){
        if($env:CODEX_WELCOME_OPENING_PIPE){$startupCover=New-Object CodexWelcome.StartupCoverProxy -ArgumentList $env:CODEX_WELCOME_OPENING_PIPE}
        else{$startupCover=New-Object CodexWelcome.StartupCover -ArgumentList (Join-Path $root 'assets\orb-motion.png'),$(if($Variant -eq 'full'){1.15}else{2.0})}
        $coverWatch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $startupCover.IsReady -and -not $startupCover.Failure -and $coverWatch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
        if($startupCover.Failure){throw $startupCover.Failure}
        if(-not $startupCover.IsReady){throw 'Startup frame cover was not ready.'}
        Write-LaunchLog 'RAIN visible; background prepares logo while particles fall'
    }
    $edge = Find-Edge
    $discoveryWatch=[Diagnostics.Stopwatch]::StartNew()
    $target = if ($verificationOnly) { @{Kind='test';Path='none'} } else { Find-Codex }
    Write-LaunchLog ('TARGET resolved in {0}ms' -f [Math]::Round($discoveryWatch.Elapsed.TotalMilliseconds))
    if (-not $PSBoundParameters.ContainsKey('WelcomeName')) {
        $nameConfig=Join-Path $root 'config.json'
        if(Test-Path -LiteralPath $nameConfig) { $WelcomeName=(Get-Content -LiteralPath $nameConfig -Raw -Encoding UTF8 | ConvertFrom-Json).WelcomeName }
    }
    if(-not $WelcomeName){$WelcomeName='JimmSun'}
    foreach ($file in @('assets\orb-motion.png','docs\animation.html','docs\orb-cloud.png','docs\glyphs.js','docs\personalize.js','docs\vendor\gsap.min.js')) { if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { throw "Missing resource: $file" } }
    if ($ValidateOnly) { $desktop=Find-DesktopProcess; [pscustomobject]@{Variant=$Variant;WelcomeName=$WelcomeName;Edge=$edge;CodexKind=$target.Kind;Codex=$target.Path;DesktopFullscreen=($null -ne $desktop -and [WelcomeWindow]::IsFullscreen($desktop.MainWindowHandle));DesktopMaximized=($null -ne $desktop -and [WelcomeWindow]::IsZoomed($desktop.MainWindowHandle));DesktopStyle= $(if($desktop){'0x{0:X8}' -f [WelcomeWindow]::GetWindowLong($desktop.MainWindowHandle,-16)});Resources='OK'} | ConvertTo-Json; exit 0 }
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback,0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $nonce = [Guid]::NewGuid().ToString('N')
    $profileName = if ($verificationOnly) {'browser-test-profile'} else {'browser-profile'}
    $profile = Join-Path $root $profileName
    Disable-AnimationTranslation $profile
    $url = "http://127.0.0.1:$port/animation.html?play=1&launch=1&variant=$Variant&token=$nonce&defer-start=1&native-orb=1&name=$([Uri]::EscapeDataString($WelcomeName))"
    $browserArgs = @('--no-first-run','--no-default-browser-check',('--user-data-dir="'+$profile+'"'),'--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-features=CalculateNativeWinOcclusion')
    if ($TestMode) { $browserArgs += @('--headless=new',$url) }
    else {
        $controlFile=Join-Path $profile 'DevToolsActivePort'
        if(Test-Path -LiteralPath $controlFile){Remove-Item -LiteralPath $controlFile -Force}
        $browserArgs += @(('--app='+$url),'--window-position=-32000,-32000','--window-size=800,600','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1')
    }
    $windowStyle = if ($TestMode) {'Hidden'} else {'Normal'}
    $browserProcess = Start-Process -FilePath $edge -ArgumentList $browserArgs -PassThru -WindowStyle $windowStyle
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $prepared=$false; $presented=$false; $startupPhase='waiting'
    $ready = $false; $complete=$false; $codexStarted=$false; $topmost=$false; $browserOffscreen=$false; $contentOnly=$null; $window=[IntPtr]::Zero
    $desktopPrepared=$verificationOnly; $handoffReady=$false; $skipReveal=$false; $nextPreparation=0.0; $script:fullscreenExitRequestWindow=[IntPtr]::Zero
    $routes = @{ '/orb-cloud.png'='docs\orb-cloud.png'; '/glyphs.js'='docs\glyphs.js'; '/personalize.js'='docs\personalize.js'; '/animation.html'='docs\animation.html'; '/vendor/gsap.min.js'='docs\vendor\gsap.min.js'; '/favicon.ico'='assets\app.ico' }
    Write-LaunchLog ("START variant={0} test={1}" -f $Variant,$TestMode.IsPresent)
    while ($watch.Elapsed.TotalSeconds -lt 45 -and -not $handoffReady) {
        $browserProcess.Refresh()
        if ($browserProcess.HasExited -and -not $complete) {
            if ($TestMode) { throw 'The animation browser exited before completion.' }
            $skipReveal=$true; Write-LaunchLog 'Animation window closed; completing directly'; break
        }
        if (-not $TestMode -and -not $browserOffscreen) {
            $browserProcess.Refresh(); $window=$browserProcess.MainWindowHandle
            if ($window -ne [IntPtr]::Zero) {
                $browserOffscreen=$startupCover.PrepareBrowserOffscreen($window)
                if($browserOffscreen){Write-LaunchLog ('BROWSER prepared offscreen '+$startupCover.BrowserPreparation)}
            }
        }
        if(-not $TestMode -and $browserOffscreen -and $prepared -and -not $topmost){
            . (Join-Path $PSScriptRoot 'BrowserWindow.ps1')
            $contentOnly=Set-WelcomeContentOnly -Profile $profile -PageUrl $url
            Write-LaunchLog ('BROWSER title bar removed while invisible '+$contentOnly)
            $topmost=$startupCover.PlaceBrowserBehind($window)
            if($topmost){Write-LaunchLog 'BROWSER painted before placement; moved behind native orb without fullscreen transition'}
        }
        if($startupCover -and $startupCover.Failure){throw $startupCover.Failure}
        if($prepared -and ($TestMode -or $topmost) -and $startupPhase -eq 'waiting'){$startupPhase='prepare'}
        if($presented -and $startupPhase -eq 'prepare'){
            if($TestMode){$startupPhase='play'}else{$startupCover.BeginHandoff();$startupPhase='collapsing';Write-LaunchLog 'BACKEND ready; opening continues at its fixed 2s rain deadline'}
        }
        if($startupPhase -eq 'collapsing' -and $startupCover.IsCollapsed){$startupPhase='play';Write-LaunchLog ("LIVE ORB collapsed after {0} moving frames; continue with logo" -f $startupCover.MotionFrames)}
        if($ready -and $startupCover -and -not $startupCover.IsComplete){$startupCover.Dismiss()}
        if ($ready -and $topmost -and -not $codexStarted) { Start-Codex; $codexStarted=$true }
        if ($codexStarted -and $null -eq $handoffOverlay -and -not $TestMode) {
            $handoffOverlay=New-Object CodexWelcome.HandoffOverlay -ArgumentList $window
            Write-LaunchLog 'JELLY cover preparation started'
        }
        if ($handoffOverlay -and $handoffOverlay.Failure) { throw $handoffOverlay.Failure }
        if ($codexStarted -and -not $desktopPrepared -and $watch.Elapsed.TotalSeconds -ge $nextPreparation) {
            $nextPreparation=$watch.Elapsed.TotalSeconds+.08
            $desktopPrepared=Prepare-MaximizedDesktop
            if ($desktopPrepared) { Write-LaunchLog 'MAXIMIZED ready behind animation' }
        }
        if ($complete -and $desktopPrepared -and ($TestMode -or ($handoffOverlay -and $handoffOverlay.IsReady))) { $handoffReady=$true; break }
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
            if ($path -in @('/prepared','/presented','/ready','/fade','/complete')) {
                $match=[regex]::Match($uri.Query,'(?:\?|&)token=([^&]+)')
                if ($parts[0] -ne 'POST' -or -not $match.Success -or $match.Groups[1].Value -cne $nonce) { $status='403 Forbidden' }
                elseif ($path -in @('/prepared','/presented')) {
                    $time=[regex]::Match($uri.Query,'(?:\?|&)time=([^&]+)')
                    if(-not $time.Success -or $time.Groups[1].Value -ne '1.72'){$status='409 Conflict'}
                    elseif($path -eq '/prepared'){$prepared=$true;Write-LaunchLog 'FIRST FRAME hidden logo entry prepared at t=1.72'}
                    else{$presented=$true;Write-LaunchLog 'FIRST FRAME hidden logo entry presented at t=1.72'}
                }
                elseif ($path -eq '/ready') { $ready=$true; Write-LaunchLog 'READY' }
                elseif ($path -eq '/fade') {
                    Write-LaunchLog 'JELLY COLLAPSE begin'
                }
                else { $complete=$true;Write-LaunchLog ("COMPLETE elapsed={0:N3}s" -f $watch.Elapsed.TotalSeconds) }
            }
            elseif ($path -eq '/startup') {
                $match=[regex]::Match($uri.Query,'(?:\?|&)token=([^&]+)')
                if($parts[0] -ne 'GET' -or -not $match.Success -or $match.Groups[1].Value -cne $nonce){$status='403 Forbidden'}
                else{$body=[Text.Encoding]::UTF8.GetBytes(('{"phase":"'+$startupPhase+'"}'))}
            }
            elseif ($routes.ContainsKey($path) -and (Test-Path -LiteralPath (Join-Path $root $routes[$path]))) {
                $body=[IO.File]::ReadAllBytes((Join-Path $root $routes[$path]));$contentType=if($path.EndsWith('.js')){'text/javascript; charset=utf-8'}elseif($path.EndsWith('.png')){'image/png'}elseif($path.EndsWith('.ico')){'image/x-icon'}else{'text/html; charset=utf-8'}
            }
            else { $status='404 Not Found';$body=[Text.Encoding]::UTF8.GetBytes('Not found');$contentType='text/plain' }
            $headers=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n")
            $stream.Write($headers,0,$headers.Length);$stream.Write($body,0,$body.Length);$stream.Flush()
        } catch { Write-LaunchLog ('Request skipped: '+$_.Exception.Message) }
        finally { $client.Close() }
    }
    if (-not $complete -and -not $skipReveal) { Write-LaunchLog 'TIMEOUT fallback handoff';if ($TestMode) { throw 'Animation completion was not received.' } }
    if (-not $handoffReady -and -not $skipReveal -and -not $TestMode) { $skipReveal=$true; Write-LaunchLog 'Preparation timed out; removing cover and completing directly' }
    if (-not $TestMode -and -not $skipReveal) {
        if (-not $handoffOverlay -or -not $handoffOverlay.IsReady) { throw 'The jelly transition cover was not ready.' }
        Write-LaunchLog 'JELLY REVEAL begin'
        $handoffOverlay.Reveal($(if($Variant -eq 'full'){.95}else{.8}))
        [void][WelcomeWindow]::ShowWindowAsync($window,0)
        Close-AnimationWindow
        $revealWatch=[Diagnostics.Stopwatch]::StartNew()
        while (-not $handoffOverlay.IsComplete -and $revealWatch.Elapsed.TotalSeconds -lt 5) { Start-Sleep -Milliseconds 15 }
        if ($handoffOverlay.Failure) { throw $handoffOverlay.Failure }
        if (-not $handoffOverlay.IsComplete) { throw 'The jelly transition did not finish.' }
        Write-LaunchLog 'JELLY REVEAL complete'
    } else { if ($handoffOverlay) { $handoffOverlay.Dispose() }; Close-AnimationWindow }
    Start-Codex -Reveal -SkipLaunch:$codexStarted
    if ($verificationOnly) { [pscustomobject]@{Variant=$Variant;WelcomeName=$WelcomeName;Completed=$complete;FirstFramePrepared=$prepared;FirstFramePresented=$presented;ContentOnlyVerified=($null -ne $contentOnly -and $contentOnly.StartsWith('contentOnly=True'));WindowGeometry=$contentOnly;ElapsedSeconds=[Math]::Round($watch.Elapsed.TotalSeconds,3)} | ConvertTo-Json }
}
catch {
    Write-LaunchLog ('ERROR '+$_.Exception.Message)
    if ($handoffOverlay) { $handoffOverlay.Dispose() }
    if ($startupCover) { $startupCover.Dispose() }
    Close-AnimationWindow
    if ($verificationOnly -or $ValidateOnly) { Write-Error $_; exit 1 }
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex Welcome')
    exit 1
}
finally {
    if ($listener) { $listener.Stop() }
    if ($handoffOverlay) { $handoffOverlay.Dispose() }
    if ($startupCover) { $startupCover.Dispose() }
    Close-AnimationWindow
    if ($mutex) { if($ownsMutex){$mutex.ReleaseMutex()};$mutex.Dispose() }
}
