$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach($variant in @('fast','full')) {
    $output=& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Launch.ps1') -Variant $variant -TestMode
    if($LASTEXITCODE -ne 0){throw "Launcher smoke test failed: $variant"}
    $result=$output | ConvertFrom-Json
    if(-not $result.Completed){throw "No animation completion callback: $variant"}
    $result | Format-List
}
