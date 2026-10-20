using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace CodexWelcome {
    // Prepared animation pixels cover the browser's first, unpainted window.
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
        private Image cloud;
        private Stopwatch dismiss;
        private IntPtr handle;
        private RECT monitor;
        private volatile bool ready,complete;
        private volatile string failure;
        public bool IsReady { get { return ready; } }
        public bool IsComplete { get { return complete; } }
        public string Failure { get { return failure; } }
        public StartupCover(string path) {
            imagePath=path;
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
                cloud=new Image { Source=image,Stretch=Stretch.Fill };canvas.Children.Add(cloud);
                window=new Window { Title="Codex Welcome Startup",WindowStyle=WindowStyle.None,ResizeMode=ResizeMode.NoResize,
                    AllowsTransparency=true,Background=Brushes.Transparent,ShowInTaskbar=false,ShowActivated=false,Topmost=true,Opacity=0,
                    Width=800,Height=600,Content=canvas };
                window.Closed+=delegate { complete=true;dispatcher.BeginInvokeShutdown(DispatcherPriority.Background); };
                window.SourceInitialized+=delegate { int disable=1;DwmSetWindowAttribute(new WindowInteropHelper(window).Handle,3,ref disable,4); };
                window.SizeChanged+=delegate { LayoutCloud(); };
                window.Show();handle=new WindowInteropHelper(window).Handle;
                SetWindowLong(handle,-20,GetWindowLong(handle,-20)|0x08000000|0x00000080);
                SetWindowPos(handle,new IntPtr(-1),monitor.left,monitor.top,monitor.right-monitor.left,monitor.bottom-monitor.top,0x0050);
                window.UpdateLayout();LayoutCloud();window.Opacity=1;
                CompositionTarget.Rendering+=Render;
                Dispatcher.Run();
            } catch(Exception error){failure=error.Message;complete=true;}
            finally { CompositionTarget.Rendering-=Render;if(window!=null && window.IsVisible)window.Close(); }
        }
        private void LayoutCloud() {
            if(window==null || cloud==null)return;
            double width=Math.Max(1,window.ActualWidth),height=Math.Max(1,window.ActualHeight);
            double fit=Math.Min(width/1920,height/1080);
            double scale=Math.Max(9.2,Math.Sqrt(width*width+height*height)/(280*fit)*1.1);
            double diameter=280*fit*scale;
            cloud.Width=cloud.Height=diameter;
            Canvas.SetLeft(cloud,(width-diameter)/2);Canvas.SetTop(cloud,(height-diameter)/2);
        }
        private void Render(object sender,EventArgs e) {
            if(!ready){ready=true;return;}
            if(dismiss==null)return;
            double p=Math.Min(1,dismiss.Elapsed.TotalSeconds/.12);
            window.Opacity=1-p*p*(3-2*p);
            if(p>=1)window.Close();
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
        public void Dismiss() {
            if(dispatcher!=null && !complete)dispatcher.BeginInvoke(new Action(delegate { if(dismiss==null)dismiss=Stopwatch.StartNew(); }));
        }
        public void Dispose() {
            if(dispatcher!=null && !complete)try{dispatcher.BeginInvoke(new Action(delegate { window.Close(); }));}catch{}
        }
    }
}
