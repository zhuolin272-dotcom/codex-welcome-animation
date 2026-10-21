$ErrorActionPreference='Stop'
$launcher=Join-Path (Split-Path $PSScriptRoot -Parent) 'launcher\Launch.ps1'
$tokens=$null;$parseErrors=$null
$syntax=[Management.Automation.Language.Parser]::ParseFile($launcher,[ref]$tokens,[ref]$parseErrors)
foreach($name in @('Get-DesktopTarget','Find-Codex')) {
    $definition=$syntax.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    Invoke-Expression $definition.Extent.Text
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('CodexWelcome-detection-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$CodexPath=$null;$script:scanned=$false
function Get-StartApps { $script:scanned=$true;throw 'Cached startup must not scan the Windows application list' }
try {
    @{WelcomeName='Test';CodexAppId='OpenAI.Codex_example123!App'} | ConvertTo-Json | Set-Content (Join-Path $root 'config.json') -Encoding UTF8
    $target=Find-Codex
    if($target.Kind -ne 'app' -or $target.Path -ne 'OpenAI.Codex_example123!App' -or $script:scanned){throw 'Store identity cache was not used'}
    Write-Output 'Codex target check PASS: cached Store identity resolves without enumerating the Start menu.'
} finally {
    Remove-Item -LiteralPath (Join-Path $root 'config.json') -Force
    Remove-Item -LiteralPath $root
}
