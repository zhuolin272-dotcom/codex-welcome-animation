$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'launcher\BuildNative.ps1')
Add-Type -Path (Join-Path $root 'launcher\WelcomeNative.dll')
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('CodexWelcome-theme-'+[Guid]::NewGuid().ToString('N')+'.json')
try {
    [IO.File]::WriteAllText($temporary,'{"WelcomeName":"Keep Me","CodexAppId":"OpenAI.Codex_example!App"}')
    foreach($theme in @('dark','light','system')) {
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'launcher\Settings.ps1') -ConfigPath $temporary -Theme $theme | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Theme save failed'}
        $saved=Get-Content -LiteralPath $temporary -Raw | ConvertFrom-Json
        if($saved.WelcomeName -ne 'Keep Me' -or $saved.CodexAppId -ne 'OpenAI.Codex_example!App' -or $saved.Theme -ne $theme){throw 'Theme save lost existing preferences'}
        $resolved=[CodexWelcome.WelcomeTheme]::Resolve($temporary)
        $expected=if($theme -eq 'system'){if((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize').AppsUseLightTheme -eq 0){'dark'}else{'light'}}else{$theme}
        if($resolved -ne $expected){throw 'Native theme did not match explicit/system appearance'}
    }
    Write-Output 'Appearance PASS: system follows Windows app mode; explicit dark/light override it; name and Store identity preserved.'
} finally { if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary} }
