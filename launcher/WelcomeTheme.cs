using System;
using System.IO;
using System.Text.RegularExpressions;
using Microsoft.Win32;
namespace CodexWelcome {
    public static class WelcomeTheme {
        public static string Resolve(string configPath) {
            string choice="system";
            if(File.Exists(configPath)) {
                Match m=Regex.Match(File.ReadAllText(configPath),"\"Theme\"\\s*:\\s*\"(system|light|dark)\"");
                if(m.Success)choice=m.Groups[1].Value;
            }
            if(choice!="system")return choice;
            using(RegistryKey key=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
                return key!=null && Convert.ToInt32(key.GetValue("AppsUseLightTheme",1))==0?"dark":"light";
            }
        }
    }
}
