$ErrorActionPreference='Stop'
$launcher=Join-Path (Split-Path $PSScriptRoot -Parent) 'launcher\Launch.ps1'
$tokens=$null;$parseErrors=$null
$syntax=[Management.Automation.Language.Parser]::ParseFile($launcher,[ref]$tokens,[ref]$parseErrors)
$definition=$syntax.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Start-Codex'},$true)
Invoke-Expression $definition.Extent.Text
$verificationOnly=$false;$script:existing=[pscustomobject]@{Id=12345}
$script:launches=@();$script:messages=@()
function Find-DesktopProcess { return $script:existing }
function Start-Process { param($FilePath,$ArgumentList,$WindowStyle) $script:launches+=@{File=$FilePath;Arguments=$ArgumentList} }
function Write-LaunchLog($Message) { $script:messages+=$Message }
foreach($kind in @('app','exe')) {
    $target=@{Kind=$kind;Path=$(if($kind -eq 'app'){'OpenAI.Codex_example!App'}else{'C:\Codex\Codex.exe'})}
    $script:existing=[pscustomobject]@{Id=12345};$script:launches=@();$script:messages=@()
    Start-Codex
    if($script:launches.Count -ne 0 -or $script:messages[0] -notmatch 'reused existing window pid=12345'){throw 'An existing Codex window was reopened'}
    $script:existing=$null
    Start-Codex
    if($script:launches.Count -ne 1){throw 'Codex was not launched when no existing window was found'}
    Start-Codex -SkipLaunch
    if($script:launches.Count -ne 1){throw 'The final reveal launched Codex a second time'}
}
Write-Output 'Existing desktop PASS: Store and EXE windows are reused; cold launch still works; final reveal does not relaunch.'
