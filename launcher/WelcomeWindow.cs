using System;
using System.Runtime.InteropServices;
public static class WelcomeWindow {
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int z,uint flags);
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h,int index,int value);
 [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr h,uint key,byte alpha,uint flags);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int command);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr h,uint flags);
 [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr monitor,ref MONITORINFO info);
 [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr h,int attribute,out RECT rect,int size);
 [DllImport("user32.dll")] private static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 [StructLayout(LayoutKind.Sequential)] private struct RECT {public int left,top,right,bottom;}
 [StructLayout(LayoutKind.Sequential)] private struct MONITORINFO {public int size;public RECT monitor,work;public uint flags;}
 public static bool IsFullscreen(IntPtr h) {
    // A normal/maximized captioned window is never Electron's F11 fullscreen.
    // DWM bounds can briefly retain the old monitor rectangle during restore.
    if((GetWindowLong(h,-16)&0x00c00000)!=0) return false;
    IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
    try {
    RECT bounds; MONITORINFO info=new MONITORINFO();info.size=Marshal.SizeOf(info);
    if(IsIconic(h) || DwmGetWindowAttribute(h,9,out bounds,Marshal.SizeOf(typeof(RECT)))!=0 || !GetMonitorInfo(MonitorFromWindow(h,2),ref info)) return false;
    return Math.Abs(bounds.left-info.monitor.left)<=2 && Math.Abs(bounds.top-info.monitor.top)<=2 && Math.Abs(bounds.right-info.monitor.right)<=2 && Math.Abs(bounds.bottom-info.monitor.bottom)<=2;
    } finally {if(previous!=IntPtr.Zero) SetThreadDpiAwarenessContext(previous);}
 }
 public static bool ExitNativeFullscreen(IntPtr h) {
    if(!IsFullscreen(h) || GetForegroundWindow()!=h) return false;
    keybd_event(0x7a,0x57,0,UIntPtr.Zero);keybd_event(0x7a,0x57,2,UIntPtr.Zero);
    return true;
 }
}
