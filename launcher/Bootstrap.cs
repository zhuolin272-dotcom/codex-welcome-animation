using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

internal static class CodexWelcomeBootstrap {
    [STAThread]
    private static int Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string logs = Path.Combine(root, "logs");
        string log = Path.Combine(logs, "bootstrap.log");
        bool test = Array.IndexOf(args, "--test") >= 0;
        bool validate = Array.IndexOf(args, "--validate") >= 0;
        bool settings = Array.IndexOf(args, "--settings") >= 0;
        try {
            Directory.CreateDirectory(logs);
            string mode = args.Length > 0 && args[0] == "full" ? "full" : "fast";
            File.AppendAllText(log, DateTime.Now.ToString("o") + " ENTRY mode=" + mode + "\r\n");
            string script = Path.Combine(root, settings ? "launcher\\Settings.ps1" : "launcher\\Launch.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("Launcher is missing. Run Install.cmd again.", script);
            ProcessStartInfo start = new ProcessStartInfo();
            start.FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe");
            start.Arguments = "-NoLogo -NoProfile -STA -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\"";
            if (!settings) start.Arguments += " -Variant " + mode;
            if (test) start.Arguments += " -TestMode";
            if (validate) start.Arguments += " -ValidateOnly";
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
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
                File.AppendAllText(log, output.ToString() + DateTime.Now.ToString("o") + " EXIT code=" + child.ExitCode + "\r\n");
                if (child.ExitCode != 0) throw new InvalidOperationException("Launcher failed (exit " + child.ExitCode + ").\r\n" + output.ToString());
            }
            return 0;
        } catch(Exception error) {
            try { File.AppendAllText(log, DateTime.Now.ToString("o") + " ERROR " + error + "\r\n"); } catch {}
            if (!test && !validate) MessageBox.Show(error.Message + "\r\n\r\nLog: " + log, "Codex Welcome", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
