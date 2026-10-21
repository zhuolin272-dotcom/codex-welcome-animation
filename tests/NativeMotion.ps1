param([switch]$LoadOnly,[switch]$Dark)
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
using System.Windows.Controls;
using System.IO;
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
 public static int White(byte[] pixels) {
  int count=0;for(int i=0;i<pixels.Length;i+=4)if(pixels[i]>200&&pixels[i+1]>200&&pixels[i+2]>200)count++;return count;
 }
 public static int Opaque(byte[] pixels) {
  int count=0;for(int i=3;i<pixels.Length;i+=4)if(pixels[i]==255)count++;return count;
 }
 public static void RenderRain(string path,double time,double fill) {
  Grid root=new Grid { Width=640,Height=400,Background=new SolidColorBrush(Color.FromRgb(30,34,41)) };
  root.Children.Add(new CodexWelcome.RainCurtain {Time=time,Fill=fill});
  root.Measure(new Size(640,400));root.Arrange(new Rect(0,0,640,400));root.UpdateLayout();
  RenderTargetBitmap image=new RenderTargetBitmap(640,400,96,96,PixelFormats.Pbgra32);image.Render(root);
  PngBitmapEncoder encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(image));using(FileStream output=File.Create(path))encoder.Save(output);
 }
}
'@
if($LoadOnly){return}
$opening=New-Object CodexWelcome.StartupCover -ArgumentList (Join-Path $root 'assets\orb-motion.png'),2.0,([bool]$Dark)
try {
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $opening.IsReady -and -not $opening.Failure -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
 if($opening.Failure -or -not $opening.IsReady){throw 'Native opening did not appear'}
 while(-not $opening.IsTunnelReady -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
 Start-Sleep -Milliseconds 120
 $rainFirst=[NativeOrbPixels]::Read($opening)
 Start-Sleep -Milliseconds 180
 $rainSecond=[NativeOrbPixels]::Read($opening)
 $rainChanged=[NativeOrbPixels]::Changes($rainFirst,$rainSecond)
 if($rainChanged -lt 100){throw 'The opening rain did not move before the orb'}

 # Simulate a backend that is not ready: rain must still finish at two seconds.
 while($watch.Elapsed.TotalSeconds -lt 1.05){Start-Sleep -Milliseconds 5}
 if($opening.RainFill -lt .15 -or $opening.RainFill -ge 1){throw 'Rain is not filling progressively before backend readiness'}
 while(-not $opening.IsOrbVisible -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 5}
 if($watch.Elapsed.TotalSeconds -gt 3.2 -or $opening.RainFill -ne 1){throw 'Rain did not finish within two seconds independently of backend readiness'}
 $first=[NativeOrbPixels]::Read($opening)
 # A fractional-DPI viewport can leave one antialiased edge row/column.
 if([NativeOrbPixels]::Opaque($first) -lt ($first.Length/4)*.995){throw 'Rain did not completely cover the desktop before the orb'}
 Start-Sleep -Milliseconds 75
 $moving=[NativeOrbPixels]::Read($opening)
 $changed=[NativeOrbPixels]::Changes($first,$moving)
 if([NativeOrbPixels]::Blue($first) -lt 1000 -or $changed -lt 100){throw "Cloud texture did not flow after rain: $changed changed pixels"}
 if($opening.IsCollapsed){throw 'Orb collapsed before the backend was ready'}
 $opening.BeginHandoff()
 while(-not $opening.IsCollapsed -and $watch.Elapsed.TotalSeconds -lt 5){Start-Sleep -Milliseconds 10}
 if(-not $opening.IsCollapsed){throw 'Native orb never disappeared'}
 if([NativeOrbPixels]::Blue([NativeOrbPixels]::Read($opening)) -ne 0){throw 'Visible blue pixels remain at the browser handoff'}
 Write-Output "Native pixel check PASS: $rainChanged rain pixels changed before orb; $changed cloud pixels changed; zero blue pixels at handoff; first frame $([Math]::Round($opening.FirstFrameMilliseconds))ms."
} finally { $opening.Dispose() }
