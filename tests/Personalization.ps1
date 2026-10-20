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
    Write-Output 'Windows personalization: Unicode save, preserved CodexPath, rejected invalid input PASS'
} finally {if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}}
