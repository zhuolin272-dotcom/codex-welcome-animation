[CmdletBinding()]
param([string]$CodexPath,[string]$InstallRoot=(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CodexWelcome'))
$ErrorActionPreference='Stop'
$source=[IO.Path]::GetFullPath($PSScriptRoot)
$destination=[IO.Path]::GetFullPath($InstallRoot)
if ($destination -eq $source) { throw 'Choose an installation folder different from this download folder.' }
$marker=Join-Path $destination '.codex-welcome-install'
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $marker) -and @(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0) { throw 'The destination is not an existing Codex Welcome installation. Choose an empty folder.' }
if ($CodexPath -and -not (Test-Path -LiteralPath $CodexPath -PathType Leaf)) { throw 'CodexPath does not exist.' }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($folder in @('docs','launcher','assets')) { Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $destination -Recurse -Force }
foreach($entry in @('Uninstall.ps1','Settings.cmd')) { Copy-Item -LiteralPath (Join-Path $source $entry) -Destination $destination -Force }
foreach ($required in @('launcher\StartupCover.cs','assets\startup-cloud.png','launcher\Settings.ps1','docs\glyphs.js','docs\personalize.js','launcher\Launch.ps1','launcher\HandoffOverlay.cs','docs\animation.html','docs\vendor\gsap.min.js','assets\openai-transparent.ico')) {
    if (-not (Test-Path -LiteralPath (Join-Path $destination $required) -PathType Leaf)) { throw "Installation is incomplete: $required" }
}
Set-Content -LiteralPath $marker -Value 'CodexWelcome v1' -Encoding ASCII
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$bootstrap=Join-Path $destination 'CodexWelcome.exe'
& $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $destination 'assets\openai-transparent.ico')) ('/out:'+$bootstrap) (Join-Path $destination 'launcher\Bootstrap.cs')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bootstrap)) { throw 'Could not build the native Windows launcher.' }
if ($CodexPath) {
    $configPath=Join-Path $destination 'config.json'
    $config=if(Test-Path -LiteralPath $configPath){Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json}else{[pscustomobject]@{}}
    $config | Add-Member -NotePropertyName CodexPath -NotePropertyValue ([IO.Path]::GetFullPath($CodexPath)) -Force
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding UTF8
}
$validation = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $destination 'launcher\Launch.ps1') -ValidateOnly
if ($LASTEXITCODE -ne 0) { throw 'Installation files copied, but Edge/Codex detection failed. Retry with -CodexPath.' }
$shell=New-Object -ComObject WScript.Shell
$shortcutNames=@('Codex (5.1s).lnk','Codex (8.1s).lnk','Codex Settings.lnk')
$locations=@([Environment]::GetFolderPath('Desktop'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Welcome'))
foreach($location in $locations) {
    New-Item -ItemType Directory -Path $location -Force | Out-Null
    for($i=0;$i -lt $shortcutNames.Count;$i++) {
        $file=Join-Path $location $shortcutNames[$i]
        if(Test-Path -LiteralPath $file) {
            $existing=$shell.CreateShortcut($file)
            $previousRoot=Split-Path $existing.TargetPath -Parent
            $managedNative=(Split-Path $existing.TargetPath -Leaf) -eq 'CodexWelcome.exe' -and (Test-Path -LiteralPath (Join-Path $previousRoot '.codex-welcome-install'))
            $legacyRoot=Join-Path $env:LOCALAPPDATA 'CodexWelcome'
            $managedScript=$existing.Arguments -like ('*'+$legacyRoot+'\launcher\*') -and (Test-Path -LiteralPath (Join-Path $legacyRoot '.codex-welcome-install'))
            if($existing.Arguments -notlike ('*'+$destination+'*') -and $existing.TargetPath -ne $bootstrap -and -not $managedNative -and -not $managedScript) { throw "An unrelated shortcut already exists: $file" }
        }
        $temporaryLink=Join-Path $location ('CodexWelcome-'+[Guid]::NewGuid().ToString('N')+'.lnk')
        $link=$shell.CreateShortcut($temporaryLink)
        $link.TargetPath=$bootstrap
        $variant=if($i -eq 0){'fast'}elseif($i -eq 1){'full'}else{'--settings'}
        $link.Arguments=$variant
        $link.WorkingDirectory=$destination
        $link.IconLocation=(Join-Path $destination 'assets\openai-transparent.ico')+',0'
        $link.Description=if($i -eq 0){'Codex with the recommended 5.1-second welcome'}elseif($i -eq 1){'Codex with the full 8.1-second welcome'}else{'Change the welcome name for both animation speeds'}
        $link.WindowStyle=1
        $link.Save()
        Move-Item -LiteralPath $temporaryLink -Destination $file -Force
    }
}
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class WelcomeShellRefresh{[DllImport("shell32.dll")]public static extern void SHChangeNotify(uint e,uint f,IntPtr a,IntPtr b);}'
[WelcomeShellRefresh]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
Write-Output "Installed: $destination"
Write-Output 'Desktop and Start Menu shortcuts: Codex (5.1s), Codex (8.1s), Codex Settings.'
