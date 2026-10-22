$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach($variant in @('fast')) {
    $output=& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Launch.ps1') -Variant $variant -WindowTestMode
    if($LASTEXITCODE -ne 0){throw "Visible window startup failed: $variant"}
    $result=$output | ConvertFrom-Json
    if(-not $result.Completed -or -not $result.FirstFramePrepared -or -not $result.FirstFramePresented){throw 'Visible startup did not finish its presentation handshake'}
    if(-not $result.ContentOnlyVerified){throw 'The browser still reserves space for its title bar'}
    $result | Format-List
}
