using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace CodexWelcome {
    // The real opening plays here immediately. The browser starts with the logo
    // only after this orb has fully collapsed; two visible balls are never swapped.
    public sealed class StartupCover : IDisposable {
        [StructLayout(LayoutKind.Sequential)] private struct POINT { public int x,y; }
        [StructLayout(LayoutKind.Sequential)] private struct RECT { public int left,top,right,bottom; }
        [StructLayout(LayoutKind.Sequential)] private struct MONITORINFO { public int size; public RECT monitor,work; public uint flags; }
        [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT point);
        [DllImport("user32.dll")] private static extern IntPtr MonitorFromPoint(POINT point,uint flags);
        [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr monitor,ref MONITORINFO info);
        [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
        [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr h,out RECT bounds);
        [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr h,int index);
        [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr h,int index,int value);
        [DllImport("user32.dll")] private static extern bool SetLayeredWindowAttributes(IntPtr h,uint color,byte alpha,uint flags);
        [DllImport("user32.dll")] private static extern IntPtr BeginDeferWindowPos(int count);
        [DllImport("user32.dll")] private static extern IntPtr DeferWindowPos(IntPtr batch,IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
        [DllImport("user32.dll")] private static extern bool EndDeferWindowPos(IntPtr batch);
        [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr h,int attribute,ref int value,int size);
        private readonly string imagePath;
        private Dispatcher dispatcher;
        private Window window;
        private Canvas canvas;
        private Ellipse cloud;
        private ImageBrush texture;
        private RainCurtain rain;
        private readonly Stopwatch created=Stopwatch.StartNew();
        private volatile bool atlasReady;
        private readonly object chunkGate=new object();
        private readonly Dictionary<int,BitmapSource> chunks=new Dictionary<int,BitmapSource>();
        private readonly HashSet<int> requested=new HashSet<int>();
        private int currentChunk=-1,lateFrames,flightFrames;
        private double rainEndAt=-1,lastRender=-1,firstFrameMilliseconds;
        private readonly double speed;
        private readonly bool dark;
        private readonly Stopwatch animation=Stopwatch.StartNew();
        private ScaleTransform breathing;
        private double collapseAt=-1;
        private volatile bool handoffRequested,collapsed;
        private int frames,lastFrame=-1;
        private IntPtr handle;
        private RECT monitor;
        private volatile bool ready,complete;
        private IntPtr preparedBrowser;
        private string browserPreparation;
        private volatile string failure;
        public bool IsReady { get { return ready; } }
        public bool IsComplete { get { return complete; } }
        public string Failure { get { return failure; } }
        public bool IsCollapsed { get { return collapsed; } }
        public int MotionFrames { get { return frames; } }
        public string BrowserPreparation { get { return browserPreparation; } }
        public double FirstFrameMilliseconds { get { return firstFrameMilliseconds; } }
        public double RainFill { get { return Math.Max(0,Math.Min(1,animation.Elapsed.TotalSeconds/1.6)); } }
        public bool IsTunnelReady { get { return atlasReady; } }
        public int FlightFrames { get { return flightFrames; } }
        public int StreamingDelays { get { return lateFrames; } }
        public bool IsOrbVisible { get { return rainEndAt>=0 && animation.Elapsed.TotalSeconds-rainEndAt>=.18 && !collapsed; } }
        public StartupCover(string path,double playbackSpeed):this(path,playbackSpeed,false) {}
        public StartupCover(string path,double playbackSpeed,bool darkTheme) {
            imagePath=path;speed=playbackSpeed;dark=darkTheme;
            Thread thread=new Thread(Run);thread.IsBackground=true;thread.SetApartmentState(ApartmentState.STA);thread.Start();
        }
        private void Run() {
            SetThreadDpiAwarenessContext(new IntPtr(-4));
            try {
                dispatcher=Dispatcher.CurrentDispatcher;
                POINT point;GetCursorPos(out point);
                MONITORINFO info=new MONITORINFO();info.size=Marshal.SizeOf(info);
                if(!GetMonitorInfo(MonitorFromPoint(point,2),ref info))throw new InvalidOperationException("Animation monitor was not found.");
                monitor=info.monitor;
                canvas=new Canvas { ClipToBounds=true, Background=Brushes.Transparent };
                rain=new RainCurtain {Dark=dark};canvas.Children.Add(rain);
                breathing=new ScaleTransform(1,1);
                texture=new ImageBrush { ViewboxUnits=BrushMappingMode.Absolute,Viewbox=new Rect(0,0,512,512),Stretch=Stretch.Fill };
                cloud=new Ellipse { Fill=texture,Opacity=0,RenderTransform=breathing,RenderTransformOrigin=new Point(.5,.5) };canvas.Children.Add(cloud);
                window=new Window { Title="Codex Welcome Startup",WindowStyle=WindowStyle.None,ResizeMode=ResizeMode.NoResize,
                    AllowsTransparency=false,Background=new SolidColorBrush(dark?Color.FromRgb(5,6,9):Color.FromRgb(247,246,242)),ShowInTaskbar=false,ShowActivated=false,Topmost=true,Opacity=0,
                    Width=800,Height=600,Content=canvas };
                window.Closed+=delegate { complete=true;dispatcher.BeginInvokeShutdown(DispatcherPriority.Background); };
                window.SourceInitialized+=delegate { int disable=1;DwmSetWindowAttribute(new WindowInteropHelper(window).Handle,3,ref disable,4); };
                window.SizeChanged+=delegate { LayoutCloud(); };
                window.Show();handle=new WindowInteropHelper(window).Handle;
                SetWindowLong(handle,-20,GetWindowLong(handle,-20)|0x08000000|0x00000080);
                SetWindowPos(handle,new IntPtr(-1),monitor.left,monitor.top,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0050);
                window.UpdateLayout();LayoutCloud();animation.Restart();window.Opacity=1;
                CompositionTarget.Rendering+=Render;
                ThreadPool.QueueUserWorkItem(delegate {
                    try {
                        BitmapImage image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.UriSource=new Uri(imagePath);image.EndInit();image.Freeze();
                        string tunnelPath=TunnelPath(0);
                        BitmapImage tunnel=new BitmapImage();tunnel.BeginInit();tunnel.CacheOption=BitmapCacheOption.OnLoad;tunnel.UriSource=new Uri(tunnelPath);tunnel.EndInit();tunnel.Freeze();
                        if(!complete)dispatcher.BeginInvoke(new Action(delegate {texture.ImageSource=image;rain.Atlas=tunnel;currentChunk=0;atlasReady=true;animation.Restart();lastRender=-1;LoadChunk(1);}));
                    } catch(Exception error){if(!complete)failure=error.Message;}
                });
                Dispatcher.Run();
            } catch(Exception error){failure=error.Message;complete=true;}
            finally { CompositionTarget.Rendering-=Render;if(window!=null && window.IsVisible)window.Close(); }
        }
        private string TunnelPath(int index) {
            return System.IO.Path.Combine(System.IO.Directory.GetParent(System.IO.Path.GetDirectoryName(imagePath)).FullName,"docs",String.Format("tunnel-{0}-{1:00}.png",dark?"dark":"light",index));
        }
        private void LoadChunk(int index) {
            if(index>5||complete||rainEndAt>=0)return;
            lock(chunkGate){if(!requested.Add(index))return;}
            ThreadPool.QueueUserWorkItem(delegate {
                try {
                    BitmapImage image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.UriSource=new Uri(TunnelPath(index));image.EndInit();image.Freeze();
                    lock(chunkGate){if(!complete&&rainEndAt<0&&index>=currentChunk)chunks[index]=image;}
                }catch(Exception error){if(!complete)failure=error.Message;}
            });
        }
        private void LayoutCloud() {
            if(window==null || cloud==null)return;
            double width=Math.Max(1,window.ActualWidth),height=Math.Max(1,window.ActualHeight);
            rain.Width=width;rain.Height=height;
            double fit=Math.Min(width/1920,height/1080);
            double diameter=280*fit;
            cloud.Width=cloud.Height=diameter;
            Canvas.SetLeft(cloud,(width-diameter)/2);Canvas.SetTop(cloud,(height-diameter)/2);
        }
        private void Render(object sender,EventArgs e) {
            double t=animation.Elapsed.TotalSeconds;
            // Quantize absolute time, not time since the last render: the latter
            // accidentally turns 144 Hz into 48 fps when capped to 60 fps.
            if(lastRender>=0 && (int)(t*120)==(int)(lastRender*120))return;lastRender=t;
            // Flight, focus, bloom, collapse: all measured on the same clock.
            if(atlasReady && rainEndAt<0 && t>=1.6)rainEndAt=t;
            double stage=rainEndAt<0?-1:t-rainEndAt;
            rain.Time=t;rain.Fill=RainFill;rain.InvalidateVisual();
            if(atlasReady&&t<1.6) {
                flightFrames++;
                int target=Math.Min(5,(int)(t*120)/32);
                if(target!=currentChunk) {
                    BitmapSource next=null;
                    lock(chunkGate){if(chunks.TryGetValue(target,out next)){chunks.Remove(target);chunks.Remove(currentChunk);}}
                    if(next!=null){rain.Atlas=next;currentChunk=target;LoadChunk(target+1);}else{lateFrames++;LoadChunk(target);}
                }
                rain.Frame=currentChunk==target?(int)(t*120)%32:31;
            }else if(atlasReady&&rain.Atlas!=null){rain.Atlas=null;lock(chunkGate){chunks.Clear();}}
            cloud.Opacity=stage<0?0:Math.Min(1,stage/.18);
            int frame=(int)(t*120)%128;
            if(frame!=lastFrame){texture.Viewbox=new Rect(frame%8*512,frame/8*512,512,512);lastFrame=frame;frames++;}
            double jelly=.014*Math.Sin(t*5);
            if(handoffRequested && stage>=.54 && collapseAt<0)collapseAt=t;
            double p=collapseAt<0?0:Math.Min(1,(t-collapseAt)/(.22/speed));
            double scale=1-(Math.Pow(2,10*p)-1)/1023;
            double grow=stage<0?0:Math.Min(1,stage/.42);grow=grow*grow*(3-2*grow);
            breathing.ScaleX=grow*scale*(1+jelly);breathing.ScaleY=grow*scale/(1+jelly);
            if(p>=1)collapsed=true;
            if(!ready){firstFrameMilliseconds=created.Elapsed.TotalMilliseconds;ready=true;return;}
        }
        public bool PrepareBrowserOffscreen(IntPtr browser) {
            if(!ready || complete)return false;
            IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
            try {
                // Edge kiosk/F11 animates a black fullscreen surface above other
                // windows. Use an ordinary app window and disable DWM transitions
                // while it is still offscreen, before giving it any screen area.
                int disabled=1;
                int result=DwmSetWindowAttribute(browser,3,ref disabled,4);
                if(result!=0)throw new InvalidOperationException("Could not disable animation-window transitions: "+result);
                DwmSetWindowAttribute(browser,33,ref disabled,4); // square corners on Windows 11
                SetWindowLong(browser,-16,GetWindowLong(browser,-16)&~0x00cf0000);
                SetWindowLong(browser,-20,(GetWindowLong(browser,-20)&~0x00040000)|0x00000080|0x00080000);
                if(!SetLayeredWindowAttributes(browser,0,0,2))throw new InvalidOperationException("The animation window could not be hidden during title-bar preparation.");
                if((GetWindowLong(browser,-16)&0x00cf0000)!=0)throw new InvalidOperationException("The animation app window could not be made borderless.");
                if(!SetWindowPos(browser,IntPtr.Zero,-32000,-32000,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0034))return false;
                RECT bounds;
                if(!GetWindowRect(browser,out bounds) || bounds.right>monitor.left || bounds.bottom>monitor.top)return false;
                preparedBrowser=browser;
                browserPreparation=String.Format("left={0} top={1} width={2} height={3} caption=False transitionsDisabled=True",bounds.left,bounds.top,bounds.right-bounds.left,bounds.bottom-bounds.top);
                return true;
            } finally { if(previous!=IntPtr.Zero)SetThreadDpiAwarenessContext(previous); }
        }
        public bool PlaceBrowserBehind(IntPtr browser) {
            if(!ready || complete || preparedBrowser!=browser)return false;
            IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
            try {
                // Only the already-painted app surface is brought on-screen.
                // The native moving orb stays above it in the same atomic update.
                IntPtr batch=BeginDeferWindowPos(2);
                if(batch==IntPtr.Zero)return false;
                batch=DeferWindowPos(batch,browser,new IntPtr(-1),monitor.left,monitor.top,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0050);
                if(batch==IntPtr.Zero)return false;
                batch=DeferWindowPos(batch,handle,new IntPtr(-1),0,0,0,0,0x0053);
                if(batch==IntPtr.Zero || !EndDeferWindowPos(batch))return false;
                return SetLayeredWindowAttributes(browser,0,255,2);
            } finally { if(previous!=IntPtr.Zero)SetThreadDpiAwarenessContext(previous); }
        }
        public void BeginHandoff() { handoffRequested=true; }
        public void Dismiss() {
            if(dispatcher!=null && !complete)dispatcher.BeginInvoke(new Action(delegate { window.Close(); }));
        }
        public void Dispose() {
            if(dispatcher!=null && !complete)try{dispatcher.BeginInvoke(new Action(delegate { window.Close(); }));}catch{}
        }
    }
}
