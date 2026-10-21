[CmdletBinding()]
param([switch]$Force)
$ErrorActionPreference='Stop'
$library=Join-Path $PSScriptRoot 'WelcomeNative.dll'
$sources=@('WelcomeWindow.cs','HandoffOverlay.cs','RainCurtain.cs','StartupCover.cs','StartupBridge.cs') | ForEach-Object { Join-Path $PSScriptRoot $_ }
$latest=($sources | Get-Item | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
if(-not $Force -and (Test-Path -LiteralPath $library) -and (Get-Item -LiteralPath $library).LastWriteTimeUtc -ge $latest){return}
$framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$compiler=Join-Path $framework 'csc.exe'
$references=@('System.dll','System.Core.dll','System.Xaml.dll','WPF\WindowsBase.dll','WPF\PresentationCore.dll','WPF\PresentationFramework.dll') | ForEach-Object { '/reference:'+(Join-Path $framework $_) }
& $compiler /nologo /target:library /optimize+ ('/out:'+$library) $references $sources
if($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $library)){throw 'Could not build the native animation helpers.'}
