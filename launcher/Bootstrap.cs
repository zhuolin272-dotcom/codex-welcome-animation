using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading;
using CodexWelcome;

internal static class CodexWelcomeBootstrap {
    [STAThread]
    private static int Main(string[] args) {
        AppDomain.CurrentDomain.AssemblyResolve+=delegate(object sender,ResolveEventArgs request) {
            if(new AssemblyName(request.Name).Name!="WelcomeNative")return null;
            return Assembly.LoadFrom(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"launcher\\WelcomeNative.dll"));
        };
        return Run(args);
    }
    [MethodImpl(MethodImplOptions.NoInlining)]
    private static int Run(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string logs = Path.Combine(root, "logs");
        string log = Path.Combine(logs, "bootstrap.log");
        bool test = Array.IndexOf(args, "--test") >= 0;
        bool validate = Array.IndexOf(args, "--validate") >= 0;
        bool settings = Array.IndexOf(args, "--settings") >= 0;
        bool windowTest = Array.IndexOf(args, "--window-test") >= 0;
        StartupCover opening=null;StartupCoverServer bridge=null;Mutex gate=null;bool ownsGate=false;
        try {
            Directory.CreateDirectory(logs);
            string mode = args.Length > 0 && args[0] == "full" ? "full" : "fast";
            File.AppendAllText(log, DateTime.Now.ToString("o") + " ENTRY mode=" + mode + "\r\n");
            string pipeName=null;
            if(!test && !validate && !settings) {
                bool created;
                gate=new Mutex(true,windowTest?"Local\\CodexWelcomeBootstrapTest":"Local\\CodexWelcomeBootstrap",out created);
                if(!created)return 0;ownsGate=true;
                opening=new StartupCover(Path.Combine(root,"assets\\orb-motion.png"),mode=="full"?1.15:2.0);
                pipeName="CodexWelcome-"+Guid.NewGuid().ToString("N");
                bridge=new StartupCoverServer(opening,pipeName);
            }
            string script = Path.Combine(root, settings ? "launcher\\Settings.ps1" : "launcher\\Launch.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("Launcher is missing. Run Install.cmd again.", script);
            ProcessStartInfo start = new ProcessStartInfo();
            start.FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe");
            start.Arguments = "-NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\"";
            if (!settings) start.Arguments += " -Variant " + mode;
            if (test) start.Arguments += " -TestMode";
            if (validate) start.Arguments += " -ValidateOnly";
            if (windowTest) start.Arguments += " -WindowTestMode";
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            if(pipeName!=null)start.EnvironmentVariables["CODEX_WELCOME_OPENING_PIPE"]=pipeName;
            StringBuilder output = new StringBuilder();
            using (Process child = new Process()) {
                child.StartInfo = start;
                DataReceivedEventHandler collect = delegate(object sender, DataReceivedEventArgs e) {
                    if (e.Data != null) lock(output) { output.AppendLine(e.Data); }
                };
                child.OutputDataReceived += collect;
                child.ErrorDataReceived += collect;
                if (!child.Start()) throw new InvalidOperationException("PowerShell could not be started.");
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                child.WaitForExit();
                if(opening!=null)File.AppendAllText(log,DateTime.Now.ToString("o")+" RAIN firstVisibleMs="+opening.FirstFrameMilliseconds.ToString("F1",System.Globalization.CultureInfo.InvariantCulture)+"\r\n");
                File.AppendAllText(log, output.ToString() + DateTime.Now.ToString("o") + " EXIT code=" + child.ExitCode + "\r\n");
                if (child.ExitCode != 0) throw new InvalidOperationException("Launcher failed (exit " + child.ExitCode + ").\r\n" + output.ToString());
            }
            return 0;
        } catch(Exception error) {
            try { File.AppendAllText(log, DateTime.Now.ToString("o") + " ERROR " + error + "\r\n"); } catch {}
            if (!test && !validate && !windowTest) MessageBox.Show(error.Message + "\r\n\r\nLog: " + log, "Codex Welcome", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        } finally {
            if(bridge!=null)bridge.Dispose();
            if(opening!=null)opening.Dispose();
            if(gate!=null){if(ownsGate)gate.ReleaseMutex();gate.Dispose();}
        }
    }
}
