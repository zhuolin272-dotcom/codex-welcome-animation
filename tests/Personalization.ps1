$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('CodexWelcome-name-'+[Guid]::NewGuid().ToString('N')+'.json')
try {
    [IO.File]::WriteAllText($temporary,'{"CodexPath":"C:\\Codex\\App.exe","Preserved":42}',(New-Object Text.UTF8Encoding($false)))
    foreach($name in @('Alex Sun',([string][char]0x5C0F+[char]0x660E))) {
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Settings.ps1') -ConfigPath $temporary -WelcomeName $name | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Could not save the name.'}
        $saved=Get-Content -LiteralPath $temporary -Raw -Encoding UTF8 | ConvertFrom-Json
        if($saved.WelcomeName -cne $name -or $saved.CodexPath -ne 'C:\Codex\App.exe' -or $saved.Preserved -ne 42){throw 'Name did not round-trip or existing configuration was lost.'}
    }
    $ErrorActionPreference='Continue'
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Settings.ps1') -ConfigPath $temporary -WelcomeName ('x'*21) 2>$null | Out-Null
    $ErrorActionPreference='Stop'
    if($LASTEXITCODE -eq 0){throw 'Overlong name was accepted.'}
    if((Get-Content -LiteralPath $temporary -Raw -Encoding UTF8 | ConvertFrom-Json).WelcomeName -cne $name){throw 'Invalid name changed saved configuration.'}
    & powershell.exe -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Settings.ps1') -ConfigPath $temporary -TestUI | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Settings window could not save.'}
    $saved=Get-Content -LiteralPath $temporary -Raw -Encoding UTF8 | ConvertFrom-Json
    if($saved.WelcomeName -cne 'Alex+Sun' -or $saved.Preserved -ne 42){throw 'The actual settings save-button handler failed.'}
    # Match a normal -File launch: omit ConfigPath, and use an unrelated cwd.
    # Keep the default config isolated from the user's installation.
    $sandbox=Join-Path ([IO.Path]::GetTempPath()) ('Codex Welcome default '+[Guid]::NewGuid().ToString('N'))
    $sandboxLauncher=Join-Path $sandbox 'launcher'
    New-Item -ItemType Directory -Path $sandboxLauncher -Force | Out-Null
    $sandboxScript=Join-Path $sandboxLauncher 'Settings.ps1'
    Copy-Item -LiteralPath (Join-Path $root 'launcher\Settings.ps1') -Destination $sandboxScript
    Push-Location $env:WINDIR
    try {
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $sandboxScript -WelcomeName 'Default Name' | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Default settings path failed without ConfigPath.'}
    } finally {Pop-Location}
    $defaultConfig=Join-Path $sandbox 'config.json'
    if(-not(Test-Path -LiteralPath $defaultConfig)){throw 'Default config was written outside the installation.'}
    if((Get-Content -LiteralPath $defaultConfig -Raw -Encoding UTF8 | ConvertFrom-Json).WelcomeName -cne 'Default Name'){throw 'Default name did not save.'}
    Write-Output 'Windows personalization: Unicode save, preserved CodexPath, rejected invalid input PASS'
    Write-Output 'Default settings path: normal -File launch, spaces in path, unrelated cwd PASS'
} finally {
    if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}
    # Remove only the explicit leaves created above; no recursive deletion.
    if($sandbox){
        foreach($leaf in @($sandboxScript,$defaultConfig)){if($leaf -and (Test-Path -LiteralPath $leaf)){Remove-Item -LiteralPath $leaf}}
        if(Test-Path -LiteralPath $sandboxLauncher){Remove-Item -LiteralPath $sandboxLauncher}
        if(Test-Path -LiteralPath $sandbox){Remove-Item -LiteralPath $sandbox}
    }
}
