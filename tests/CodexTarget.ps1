$ErrorActionPreference='Stop'
$launcher=Join-Path (Split-Path $PSScriptRoot -Parent) 'launcher\Launch.ps1'
$tokens=$null;$parseErrors=$null
$syntax=[Management.Automation.Language.Parser]::ParseFile($launcher,[ref]$tokens,[ref]$parseErrors)
foreach($name in @('Get-DesktopTarget','Find-Codex','Disable-AnimationTranslation')) {
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
    $profile=Join-Path $root 'browser-profile'
    $default=Join-Path $profile 'Default'
    New-Item -ItemType Directory -Path $default -Force | Out-Null
    $preferences=Join-Path $default 'Preferences'
    $file=[IO.File]::Create($preferences);$file.SetLength(4MB);$file.Dispose()
    # An invalid/oversized old file must be repaired without parsing it, and
    # repeated launches must always produce exactly the same bounded config.
    Disable-AnimationTranslation $profile
    $expected=[IO.File]::ReadAllText($preferences)
    for($index=0;$index -lt 30;$index++) { Disable-AnimationTranslation $profile }
    if((Get-Item $preferences).Length -gt 512 -or [IO.File]::ReadAllText($preferences) -cne $expected){throw 'Splash preferences grow on repeated launches'}
    if(($expected | ConvertFrom-Json).translate.enabled -ne $false){throw 'Translation is not disabled'}
    Remove-Item -LiteralPath $preferences
    Remove-Item -LiteralPath $default
    Remove-Item -LiteralPath $profile
    Write-Output 'Codex target check PASS: cached Store identity resolves without enumerating the Start menu.'
    Write-Output 'Preferences check PASS: oversized old config repaired; 30 repeated writes remain below 512 bytes.'
} finally {
    Remove-Item -LiteralPath (Join-Path $root 'config.json') -Force
    Remove-Item -LiteralPath $root
}
