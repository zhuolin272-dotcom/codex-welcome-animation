using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
namespace CodexWelcome {
    // Shared precomputed 3D flight, one image brush rather than live star layout.
    public sealed class RainCurtain : FrameworkElement {
        public static readonly DependencyProperty ClockProperty=DependencyProperty.Register("Clock",typeof(double),typeof(RainCurtain),new FrameworkPropertyMetadata(0.0,FrameworkPropertyMetadataOptions.AffectsRender));
        public RainCurtain() {
            DoubleAnimation clock=new DoubleAnimation(0,1,TimeSpan.FromSeconds(1));clock.RepeatBehavior=RepeatBehavior.Forever;
            // Pump at twice the source cadence; content is sampled on absolute 120 Hz bins.
            Timeline.SetDesiredFrameRate(clock,240);BeginAnimation(ClockProperty,clock);
        }
        public double Time,Fill;
        public int Frame;
        public bool Dark;
        public ImageSource Atlas;
        private readonly ImageBrush image=new ImageBrush {ViewboxUnits=BrushMappingMode.Absolute,Stretch=Stretch.Fill};
        protected override void OnRender(DrawingContext context) {
            double w=ActualWidth,h=ActualHeight;if(w<=0||h<=0)return;
            context.DrawRectangle(new SolidColorBrush(Dark?Color.FromRgb(5,6,9):Color.FromRgb(247,246,242)),null,new Rect(0,0,w,h));
            if(Atlas==null||Time>=1.6)return;
            int frame=Math.Max(0,Math.Min(31,Frame));
            image.ImageSource=Atlas;image.Viewbox=new Rect(frame%4*1280,frame/4*800,1280,800);
            double fit=Math.Min(w/1280,h/800);
            context.DrawRectangle(image,null,new Rect((w-1280*fit)/2,(h-800*fit)/2,1280*fit,800*fit));
        }
    }
}
