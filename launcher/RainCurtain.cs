using System;
using System.Windows;
using System.Windows.Media;
namespace CodexWelcome {
    // Shared precomputed 3D flight, one image brush rather than live star layout.
    public sealed class RainCurtain : FrameworkElement {
        public double Time,Fill;
        public bool Dark;
        public ImageSource Atlas;
        private readonly ImageBrush image=new ImageBrush {ViewboxUnits=BrushMappingMode.Absolute,Stretch=Stretch.Fill};
        protected override void OnRender(DrawingContext context) {
            double w=ActualWidth,h=ActualHeight;if(w<=0||h<=0)return;
            context.DrawRectangle(new SolidColorBrush(Dark?Color.FromRgb(5,6,9):Color.FromRgb(247,246,242)),null,new Rect(0,0,w,h));
            if(Atlas==null||Time>=1.6)return;
            int frame=Math.Min(95,(int)(Math.Max(0,Time)*60));
            image.ImageSource=Atlas;image.Viewbox=new Rect(frame%8*640,frame/8*400,640,400);
            double fit=Math.Min(w/640,h/400);
            context.DrawRectangle(image,null,new Rect((w-640*fit)/2,(h-400*fit)/2,640*fit,400*fit));
        }
    }
}
