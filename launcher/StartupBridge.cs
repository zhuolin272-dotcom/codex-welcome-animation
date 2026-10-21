using System;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading;

namespace CodexWelcome {
    // The EXE starts the rain before PowerShell. A small, user-only pipe lets the
    // backend control that same window, without showing a second opening window.
    public sealed class StartupCoverServer : IDisposable {
        private readonly StartupCover opening;
        private readonly NamedPipeServerStream pipe;
        public StartupCoverServer(StartupCover cover,string name) {
            opening=cover;
            PipeSecurity security=new PipeSecurity();security.SetAccessRuleProtection(true,false);
            security.AddAccessRule(new PipeAccessRule(WindowsIdentity.GetCurrent().User,PipeAccessRights.FullControl,AccessControlType.Allow));
            pipe=new NamedPipeServerStream(name,PipeDirection.InOut,1,PipeTransmissionMode.Byte,PipeOptions.None,4096,4096,security);
            Thread thread=new Thread(Serve);thread.IsBackground=true;thread.Start();
        }
        private void Serve() {
            try {
                pipe.WaitForConnection();
                using(StreamReader reader=new StreamReader(pipe,new UTF8Encoding(false),false,4096,true))
                using(StreamWriter writer=new StreamWriter(pipe,new UTF8Encoding(false),4096,true)) {
                    writer.AutoFlush=true;string request;
                    while((request=reader.ReadLine())!=null) {
                        try {writer.WriteLine("OK "+Convert.ToBase64String(Encoding.UTF8.GetBytes(Execute(request))));}
                        catch(Exception error){writer.WriteLine("ERR "+Convert.ToBase64String(Encoding.UTF8.GetBytes(error.GetBaseException().Message)));}
                    }
                }
            } catch(IOException){}catch(ObjectDisposedException){}
        }
        private string Execute(string request) {
            string[] parts=request.Split(' ');
            switch(parts[0]) {
                case "READY":return opening.IsReady?"1":"0";
                case "COMPLETE":return opening.IsComplete?"1":"0";
                case "FAILURE":return opening.Failure??"";
                case "COLLAPSED":return opening.IsCollapsed?"1":"0";
                case "FRAMES":return opening.MotionFrames.ToString();
                case "PREPARATION":return opening.BrowserPreparation??"";
                case "PREPARE":return opening.PrepareBrowserOffscreen(new IntPtr(long.Parse(parts[1])))?"1":"0";
                case "PLACE":return opening.PlaceBrowserBehind(new IntPtr(long.Parse(parts[1])))?"1":"0";
                case "BEGIN":opening.BeginHandoff();return "";
                case "DISMISS":opening.Dismiss();return "";
                case "DISPOSE":opening.Dispose();return "";
                default:throw new InvalidOperationException("Unknown opening command.");
            }
        }
        public void Dispose(){pipe.Dispose();}
    }
    public sealed class StartupCoverProxy : IDisposable {
        private readonly NamedPipeClientStream pipe;
        private readonly StreamReader reader;
        private readonly StreamWriter writer;
        private bool disposed;
        public StartupCoverProxy(string name) {
            pipe=new NamedPipeClientStream(".",name,PipeDirection.InOut);pipe.Connect(3000);
            reader=new StreamReader(pipe,new UTF8Encoding(false),false,4096,true);
            writer=new StreamWriter(pipe,new UTF8Encoding(false),4096,true);writer.AutoFlush=true;
        }
        private string Query(string command) {
            writer.WriteLine(command);string response=reader.ReadLine();
            if(response==null)throw new IOException("The opening window disconnected.");
            int offset=response.IndexOf(' ');string value=Encoding.UTF8.GetString(Convert.FromBase64String(response.Substring(offset+1)));
            if(!response.StartsWith("OK "))throw new InvalidOperationException(value);return value;
        }
        public bool IsReady { get{return Query("READY")=="1";} }
        public bool IsComplete { get{return Query("COMPLETE")=="1";} }
        public bool IsCollapsed { get{return Query("COLLAPSED")=="1";} }
        public string Failure { get{return Query("FAILURE");} }
        public int MotionFrames { get{return int.Parse(Query("FRAMES"));} }
        public string BrowserPreparation { get{return Query("PREPARATION");} }
        public bool PrepareBrowserOffscreen(IntPtr handle){return Query("PREPARE "+handle.ToInt64())=="1";}
        public bool PlaceBrowserBehind(IntPtr handle){return Query("PLACE "+handle.ToInt64())=="1";}
        public void BeginHandoff(){Query("BEGIN");}
        public void Dismiss(){Query("DISMISS");}
        public void Dispose(){if(disposed)return;disposed=true;try{Query("DISPOSE");}finally{reader.Dispose();writer.Dispose();pipe.Dispose();}}
    }
}
