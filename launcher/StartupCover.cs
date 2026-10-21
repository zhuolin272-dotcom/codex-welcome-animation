using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
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
        [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr h,int index);
        [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr h,int index,int value);
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
        private readonly double speed;
        private readonly Stopwatch animation=Stopwatch.StartNew();
        private ScaleTransform breathing;
        private double collapseAt=-1;
        private volatile bool handoffRequested,collapsed;
        private int frames,lastFrame=-1;
        private IntPtr handle;
        private RECT monitor;
        private volatile bool ready,complete;
        private volatile string failure;
        public bool IsReady { get { return ready; } }
        public bool IsComplete { get { return complete; } }
        public string Failure { get { return failure; } }
        public bool IsCollapsed { get { return collapsed; } }
        public int MotionFrames { get { return frames; } }
        public StartupCover(string path,double playbackSpeed) {
            imagePath=path;speed=playbackSpeed;
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
                BitmapImage image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.UriSource=new Uri(imagePath);image.EndInit();image.Freeze();
                canvas=new Canvas { ClipToBounds=true, Background=new SolidColorBrush(Color.FromRgb(247,246,242)) };
                breathing=new ScaleTransform(1,1);
                texture=new ImageBrush(image) { ViewboxUnits=BrushMappingMode.Absolute,Viewbox=new Rect(0,0,256,256),Stretch=Stretch.Fill };
                cloud=new Ellipse { Fill=texture,RenderTransform=breathing,RenderTransformOrigin=new Point(.5,.5) };canvas.Children.Add(cloud);
                window=new Window { Title="Codex Welcome Startup",WindowStyle=WindowStyle.None,ResizeMode=ResizeMode.NoResize,
                    AllowsTransparency=true,Background=Brushes.Transparent,ShowInTaskbar=false,ShowActivated=false,Topmost=true,Opacity=0,
                    Width=800,Height=600,Content=canvas };
                window.Closed+=delegate { complete=true;dispatcher.BeginInvokeShutdown(DispatcherPriority.Background); };
                window.SourceInitialized+=delegate { int disable=1;DwmSetWindowAttribute(new WindowInteropHelper(window).Handle,3,ref disable,4); };
                window.SizeChanged+=delegate { LayoutCloud(); };
                window.Show();handle=new WindowInteropHelper(window).Handle;
                SetWindowLong(handle,-20,GetWindowLong(handle,-20)|0x08000000|0x00000080);
                SetWindowPos(handle,new IntPtr(-1),monitor.left,monitor.top,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0050);
                window.UpdateLayout();LayoutCloud();animation.Restart();window.Opacity=1;
                CompositionTarget.Rendering+=Render;
                Dispatcher.Run();
            } catch(Exception error){failure=error.Message;complete=true;}
            finally { CompositionTarget.Rendering-=Render;if(window!=null && window.IsVisible)window.Close(); }
        }
        private void LayoutCloud() {
            if(window==null || cloud==null)return;
            double width=Math.Max(1,window.ActualWidth),height=Math.Max(1,window.ActualHeight);
            double fit=Math.Min(width/1920,height/1080);
            double diameter=280*fit;
            cloud.Width=cloud.Height=diameter;
            Canvas.SetLeft(cloud,(width-diameter)/2);Canvas.SetTop(cloud,(height-diameter)/2);
        }
        private void Render(object sender,EventArgs e) {
            double t=animation.Elapsed.TotalSeconds;
            int frame=(int)(t*60)%64;
            if(frame!=lastFrame){texture.Viewbox=new Rect(frame%8*256,frame/8*256,256,256);lastFrame=frame;frames++;}
            double jelly=.014*Math.Sin(t*5);
            if(handoffRequested && collapseAt<0 && t>=1.5/speed)collapseAt=t;
            double p=collapseAt<0?0:Math.Min(1,(t-collapseAt)/(.22/speed));
            double scale=1-(Math.Pow(2,10*p)-1)/1023;
            breathing.ScaleX=scale*(1+jelly);breathing.ScaleY=scale/(1+jelly);
            if(p>=1)collapsed=true;
            if(!ready){ready=true;return;}
        }
        public bool PlaceBrowserBehind(IntPtr browser) {
            if(!ready || complete)return false;
            IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
            try {
                // One atomic update makes the browser topmost while keeping our
                // prepared frame above it. There is no uncovered intermediate frame.
                IntPtr batch=BeginDeferWindowPos(2);
                if(batch==IntPtr.Zero)return false;
                batch=DeferWindowPos(batch,browser,new IntPtr(-1),monitor.left,monitor.top,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0050);
                if(batch==IntPtr.Zero)return false;
                batch=DeferWindowPos(batch,handle,new IntPtr(-1),0,0,0,0,0x0053);
                return batch!=IntPtr.Zero && EndDeferWindowPos(batch);
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
