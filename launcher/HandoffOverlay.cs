using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace CodexWelcome {
    // A transparent, animated aperture reveals the live desktop window below.
    // No screenshot of the user's app is taken or retained.
    public sealed class HandoffOverlay : IDisposable {
        [StructLayout(LayoutKind.Sequential)] private struct RECT { public int left, top, right, bottom; }
        [StructLayout(LayoutKind.Sequential)] private struct MONITORINFO { public int size; public RECT monitor, work; public uint flags; }
        [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
        [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
        [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
        [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr h, int index);
        [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr h, int index, int value);

        private readonly IntPtr splash;
        private readonly bool dark;
        private readonly Thread thread;
        private Dispatcher dispatcher;
        private Window window;
        private RadialGradientBrush aperture;
        private Stopwatch animation;
        private double duration;
        private int started;
        private volatile bool ready, complete;
        private volatile string failure;
        public bool IsReady { get { return ready; } }
        public bool IsComplete { get { return complete; } }
        public string Failure { get { return failure; } }

        public HandoffOverlay(IntPtr splashWindow):this(splashWindow,false) {}
        public HandoffOverlay(IntPtr splashWindow,bool darkTheme) {
            splash = splashWindow;dark=darkTheme;
            thread = new Thread(Run);
            thread.IsBackground = true;
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
        }

        public static double[] RevealRadii(double progress, double width, double height) {
            double p = Math.Max(0, Math.Min(1, progress));
            double eased = p*p*p*(p*(p*6-15)+10);
            double jelly = .16*Math.Sin(3*Math.PI*p)*Math.Sin(Math.PI*p)*(1-p);
            double radius = Math.Max(.01, Math.Sqrt(width*width+height*height)*.56*eased);
            return new double[] { radius*(1+jelly), radius/(1+jelly) };
        }

        private void Run() {
            SetThreadDpiAwarenessContext(new IntPtr(-4));
            try {
                dispatcher = Dispatcher.CurrentDispatcher;
                MONITORINFO info = new MONITORINFO(); info.size = Marshal.SizeOf(info);
                if (!GetMonitorInfo(MonitorFromWindow(splash, 2), ref info)) throw new InvalidOperationException("Could not locate the animation monitor.");
                Color paper = dark?Color.FromRgb(5,6,9):Color.FromRgb(247,246,242);
                aperture = new RadialGradientBrush();
                aperture.MappingMode = BrushMappingMode.Absolute;
                aperture.RadiusX = aperture.RadiusY = .01;
                aperture.GradientStops.Add(new GradientStop(Color.FromArgb(0,paper.R,paper.G,paper.B),0));
                aperture.GradientStops.Add(new GradientStop(Color.FromArgb(0,paper.R,paper.G,paper.B),.975));
                aperture.GradientStops.Add(new GradientStop(paper,1));
                window = new Window {
                    Title = "Codex Welcome Transition", WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize, AllowsTransparency = true,
                    Background = Brushes.Transparent, ShowInTaskbar = false,
                    ShowActivated = false, Topmost = true, Opacity = 0,
                    Width = 800, Height = 600,
                    Content = new Rectangle { Fill = aperture }
                };
                window.Closed += delegate { complete = true; dispatcher.BeginInvokeShutdown(DispatcherPriority.Background); };
                window.SizeChanged += delegate { if(animation == null) UpdateAperture(0); };
                window.Show();
                IntPtr handle = new WindowInteropHelper(window).Handle;
                SetWindowLong(handle,-20,GetWindowLong(handle,-20)|0x08000000|0x00000080);
                // Place the cover directly behind the splash before it is visible.
                SetWindowPos(handle,splash,info.monitor.left,info.monitor.top,
                    info.monitor.right-info.monitor.left,info.monitor.bottom-info.monitor.top,0x0050);
                window.UpdateLayout();
                UpdateAperture(0);
                window.Opacity = 1;
                CompositionTarget.Rendering += Render;
                ready = true;
                Dispatcher.Run();
            } catch(Exception e) {
                failure = e.Message; complete = true;
            } finally {
                CompositionTarget.Rendering -= Render;
                if(window != null && window.IsVisible) window.Close();
            }
        }

        private void UpdateAperture(double p) {
            double width = Math.Max(1, window.ActualWidth), height = Math.Max(1, window.ActualHeight);
            double[] radii = RevealRadii(p,width,height);
            aperture.Center = aperture.GradientOrigin = new Point(width/2,height/2);
            aperture.RadiusX = radii[0]; aperture.RadiusY = radii[1];
        }

        private void Render(object sender, EventArgs e) {
            if(animation == null) return;
            double p = animation.Elapsed.TotalSeconds/duration;
            UpdateAperture(Math.Min(1,p));
            // Keep one transparent frame before removing the cover.
            if(p >= 1.06) window.Close();
        }

        public void Reveal(double seconds) {
            if(!ready || dispatcher == null) throw new InvalidOperationException("The transition cover is not ready.");
            if(Interlocked.Exchange(ref started,1) != 0) return;
            dispatcher.BeginInvoke(new Action(delegate { duration = Math.Max(.3,seconds); animation = Stopwatch.StartNew(); }));
        }

        public void Dispose() {
            if(dispatcher != null && !complete) {
                try { dispatcher.BeginInvoke(new Action(delegate { if(window != null) window.Close(); })); } catch {}
            }
        }
    }
}
