$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$references=@((Join-Path $framework 'System.dll'),(Join-Path $framework 'System.Xaml.dll'),(Join-Path $framework 'WPF\WindowsBase.dll'),(Join-Path $framework 'WPF\PresentationCore.dll'),(Join-Path $framework 'WPF\PresentationFramework.dll'))
Add-Type -Path (Join-Path $root 'launcher\HandoffOverlay.cs') -ReferencedAssemblies $references
foreach($viewport in @(@(1280,720),@(1920,1080),@(2560,1600),@(3440,1440),@(900,1200))){
    $width=$viewport[0];$height=$viewport[1];$previousArea=0
    for($i=0;$i -le 100;$i++){
        $r=[CodexWelcome.HandoffOverlay]::RevealRadii($i/100.0,$width,$height)
        if($r[0] -le 0 -or $r[1] -le 0 -or [double]::IsNaN($r[0]+$r[1])){throw 'Invalid reveal geometry'}
        $area=$r[0]*$r[1]
        if($area -lt $previousArea-0.000001){throw 'Reveal area moved backwards'}
        $previousArea=$area
        $corner=($width/2.0/$r[0])*($width/2.0/$r[0])+($height/2.0/$r[1])*($height/2.0/$r[1])
        if($i -ge 90 -and $corner -gt .95){throw 'A corner became covered near the end of the reveal'}
    }
}
Write-Output 'Jelly reveal geometry passed: continuous expansion and all corners clear at completion.'
