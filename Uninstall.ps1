$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($PSScriptRoot)
if(-not (Test-Path -LiteralPath (Join-Path $root '.codex-welcome-install'))) { throw 'Run the copy of Uninstall.ps1 in the installation folder.' }
$shell=New-Object -ComObject WScript.Shell
$locations=@([Environment]::GetFolderPath('Desktop'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Welcome'))
foreach($location in $locations){foreach($name in @('Codex (5.1s).lnk','Codex (8.1s).lnk','Codex Settings.lnk')){$file=Join-Path $location $name;if(Test-Path -LiteralPath $file){$link=$shell.CreateShortcut($file);if($link.Arguments -like ('*'+$root+'*') -or $link.TargetPath -eq (Join-Path $root 'CodexWelcome.exe')){Remove-Item -LiteralPath $file}}}}
Write-Output 'Removed the managed shortcuts. Installation files were preserved.'
Write-Output "You can now delete this folder manually: $root"
