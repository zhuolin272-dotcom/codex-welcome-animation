[CmdletBinding()]
param([string]$CodexPath,[string]$InstallRoot=(Join-Path $env:LOCALAPPDATA 'CodexWelcome'))
$ErrorActionPreference='Stop'
$source=[IO.Path]::GetFullPath($PSScriptRoot)
$destination=[IO.Path]::GetFullPath($InstallRoot)
if ($destination -eq $source) { throw 'Choose an installation folder different from this download folder.' }
$marker=Join-Path $destination '.codex-welcome-install'
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $marker) -and @(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0) { throw 'The destination is not an existing Codex Welcome installation. Choose an empty folder.' }
if ($CodexPath -and -not (Test-Path -LiteralPath $CodexPath -PathType Leaf)) { throw 'CodexPath does not exist.' }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($folder in @('docs','launcher','assets')) { Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $destination -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $source 'Uninstall.ps1') -Destination $destination -Force
Set-Content -LiteralPath $marker -Value 'CodexWelcome v1' -Encoding ASCII
if ($CodexPath) { @{CodexPath=[IO.Path]::GetFullPath($CodexPath)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'config.json') -Encoding UTF8 }
$validation = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $destination 'launcher\Launch.ps1') -ValidateOnly
if ($LASTEXITCODE -ne 0) { throw 'Installation files copied, but Edge/Codex detection failed. Retry with -CodexPath.' }
$shell=New-Object -ComObject WScript.Shell
$shortcutNames=@('Codex (5.1s).lnk','Codex (8.1s).lnk')
$locations=@([Environment]::GetFolderPath('Desktop'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Welcome'))
foreach($location in $locations) {
    New-Item -ItemType Directory -Path $location -Force | Out-Null
    for($i=0;$i -lt 2;$i++) {
        $file=Join-Path $location $shortcutNames[$i]
        if(Test-Path -LiteralPath $file) {
            $existing=$shell.CreateShortcut($file)
            if($existing.Arguments -notlike ('*'+$destination+'*')) { throw "An unrelated shortcut already exists: $file" }
        }
        $link=$shell.CreateShortcut($file)
        $link.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe'
        $variant=if($i -eq 0){'fast'}else{'full'}
        $link.Arguments='"'+(Join-Path $destination 'launcher\Start.vbs')+'" '+$variant
        $link.WorkingDirectory=$destination
        $link.IconLocation=(Join-Path $destination 'assets\app.ico')+',0'
        $link.Description=if($i -eq 0){'Codex with the recommended 5.1-second welcome'}else{'Codex with the full 8.1-second welcome'}
        $link.WindowStyle=7
        $link.Save()
    }
}
Write-Output "Installed: $destination"
Write-Output 'Desktop and Start Menu shortcuts: Codex (5.1s), Codex (8.1s).'
