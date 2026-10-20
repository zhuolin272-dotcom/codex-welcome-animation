Option Explicit
Dim fso, shell, script, modeName, command
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
modeName = "fast"
If WScript.Arguments.Count > 0 Then
  If LCase(WScript.Arguments(0)) = "full" Then modeName = "full"
End If
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Launch.ps1")
command = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """ -Variant " & modeName
shell.Run command, 0, False
