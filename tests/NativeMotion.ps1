$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'launcher\BuildNative.ps1')
$library=Join-Path $root 'launcher\WelcomeNative.dll'
Add-Type -Path $library
$framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$references=@($library,(Join-Path $framework 'System.dll'),(Join-Path $framework 'System.Xaml.dll'),(Join-Path $framework 'WPF\WindowsBase.dll'),(Join-Path $framework 'WPF\PresentationCore.dll'),(Join-Path $framework 'WPF\PresentationFramework.dll'))
Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
public static class NativeOrbPixels {
 public static byte[] Read(CodexWelcome.StartupCover opening) {
  FrameworkElement canvas=(FrameworkElement)typeof(CodexWelcome.StartupCover).GetField("canvas",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(opening);
  byte[] pixels=null;
  canvas.Dispatcher.Invoke(new Action(delegate {
   int width=(int)Math.Ceiling(canvas.ActualWidth),height=(int)Math.Ceiling(canvas.ActualHeight);
   RenderTargetBitmap image=new RenderTargetBitmap(width,height,96,96,PixelFormats.Pbgra32);
   image.Render(canvas);pixels=new byte[width*height*4];image.CopyPixels(pixels,width*4,0);
  }));
  return pixels;
 }
 public static int Changes(byte[] first,byte[] second) {
  if(first.Length!=second.Length)throw new Exception("Native canvas resized unexpectedly");
  int changed=0;for(int i=0;i<first.Length;i+=4)if(Math.Abs(first[i]-second[i])+Math.Abs(first[i+1]-second[i+1])+Math.Abs(first[i+2]-second[i+2])>15)changed++;
  return changed;
 }
 public static int Blue(byte[] pixels) {
  int blue=0;for(int i=0;i<pixels.Length;i+=4)if(pixels[i]>pixels[i+2]+8)blue++;return blue;
 }
}
'@
$opening=New-Object CodexWelcome.StartupCover -ArgumentList (Join-Path $root 'assets\orb-motion.png'),1.6
try {
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $opening.IsReady -and -not $opening.Failure -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
 if($opening.Failure -or -not $opening.IsReady){throw 'Native opening did not appear'}
 $first=[NativeOrbPixels]::Read($opening)
 Start-Sleep -Milliseconds 180
 $moving=[NativeOrbPixels]::Read($opening)
 $changed=[NativeOrbPixels]::Changes($first,$moving)
 if([NativeOrbPixels]::Blue($first) -lt 1000 -or $changed -lt 100){throw "Cloud texture did not flow: $changed changed pixels"}
 $opening.BeginHandoff()
 while(-not $opening.IsCollapsed -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
 if(-not $opening.IsCollapsed){throw 'Native orb never disappeared'}
 if([NativeOrbPixels]::Blue([NativeOrbPixels]::Read($opening)) -ne 0){throw 'Visible blue pixels remain at the browser handoff'}
 Write-Output "Native pixel check PASS: $changed cloud pixels changed; $($opening.MotionFrames) moving frames; zero blue pixels at handoff."
} finally { $opening.Dispose() }
