$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$launcher=Join-Path $root 'launcher\Launch.ps1'
$output=& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $launcher -ValidateOnly
if($LASTEXITCODE -ne 0){throw 'Desktop detection failed'}
$result=$output | ConvertFrom-Json
if($result.Codex -match '[\\/]OpenAI[\\/]Codex[\\/]bin[\\/]'){throw 'CLI backend was selected as desktop app'}
$registered=Get-StartApps | Where-Object {$_.AppID -match '^OpenAI\.Codex_[^!]+!'} | Select-Object -First 1
if($registered -and ($result.CodexKind -ne 'app' -or $result.Codex -ne $registered.AppID)){throw 'Registered desktop app was not selected'}
$bin=Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
if(Test-Path -LiteralPath $bin){
    $backend=Get-ChildItem -LiteralPath $bin -Filter codex.exe -File -Recurse | Select-Object -First 1
    if($backend){
        $previousPreference=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        $failure=& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $launcher -ValidateOnly -CodexPath $backend.FullName 2>&1
        $failureCode=$LASTEXITCODE
        $ErrorActionPreference=$previousPreference
        $failureLog=Get-Content -LiteralPath (Join-Path $root 'logs\launch.log') -Tail 1
        if($failureCode -eq 0 -or $failureLog -notmatch 'ERROR.*command-line backend'){throw 'Explicit CLI backend was not rejected'}
    }
}
Write-Output 'Desktop detection passed; CLI backend is excluded.'
