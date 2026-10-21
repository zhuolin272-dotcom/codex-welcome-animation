using System;
using System.Windows;
using System.Windows.Media;

namespace CodexWelcome {
    // One lightweight drawing surface: no per-particle controls or layout passes.
    public sealed class RainCurtain : FrameworkElement {
        private struct RainDrop { public double x,delay,duration,radius,length; }
        private readonly RainDrop[] drops=new RainDrop[640];
        private static readonly Color Paper=Color.FromRgb(247,246,242);
        private readonly Brush tail=new SolidColorBrush(Color.FromArgb(85,255,255,255));
        public double Time,Fill;
        public RainCurtain() {
            IsHitTestVisible=false;tail.Freeze();Random random=new Random(42);
            for(int i=0;i<drops.Length;i++)drops[i]=new RainDrop { x=random.NextDouble(),delay=random.NextDouble()*.42,
                duration=.52+random.NextDouble()*.28,radius=.65+random.NextDouble()*1.05,length=5+random.NextDouble()*13 };
        }
        private static double Smooth(double x) {x=Math.Max(0,Math.Min(1,x));return x*x*(3-2*x);}
        protected override void OnRender(DrawingContext context) {
            double w=ActualWidth,h=ActualHeight;if(w<=0 || h<=0)return;
            context.PushClip(new RectangleGeometry(new Rect(0,0,w,h)));
            double fill=Smooth(Fill),fade=1-Smooth((Fill-.35)/.65);
            context.DrawRectangle(new SolidColorBrush(Color.FromArgb((byte)(30*Smooth(Time/.12)*(1-fill)),0,0,0)),null,new Rect(0,0,w,h));
            if(fill>0) {
                double front=(h+100)*fill;
                LinearGradientBrush wash=new LinearGradientBrush(Paper,Color.FromArgb(0,247,246,242),new Point(0,Math.Max(0,front-72)),new Point(0,front));
                wash.MappingMode=BrushMappingMode.Absolute;
                context.DrawRectangle(wash,null,new Rect(0,0,w,Math.Min(h,front)));
            }
            if(fade>0) {
                context.PushOpacity(fade);
                foreach(RainDrop drop in drops) {
                    double age=Time-drop.delay;if(age<0)continue;
                    double p=(age%drop.duration)/drop.duration;
                    double y=-8+(h+40)*p*(.35+.65*p);
                    double x=drop.x*w+Math.Sin(Time*2+drop.x*19)*2;
                    context.DrawRoundedRectangle(tail,null,new Rect(x-drop.radius*.4,y-drop.length,drop.radius*.8,drop.length),drop.radius,drop.radius);
                    context.DrawEllipse(Brushes.White,null,new Point(x,y),drop.radius,drop.radius*1.35);
                }
                context.Pop();
            }
            context.Pop();
        }
    }
}
