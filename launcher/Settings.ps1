[CmdletBinding()]
param([string]$WelcomeName,[ValidateSet('system','light','dark')][string]$Theme,[switch]$TestUI,[string]$ConfigPath)
$ErrorActionPreference='Stop'
# Script automatic variables are initialized after parameter binding in Windows PowerShell.
# Resolve the default here, never in param(), and never relative to the caller's directory.
if(-not $PSBoundParameters.ContainsKey('ConfigPath')) {
    $ConfigPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'
} elseif([string]::IsNullOrWhiteSpace($ConfigPath)) {
    throw 'ConfigPath must not be empty.'
}
$ConfigPath=[IO.Path]::GetFullPath($ConfigPath)
function ConvertTo-WelcomeName([string]$Value) {
    $name=$Value.Normalize([Text.NormalizationForm]::FormC).Trim()
    $count=0
    for($i=0;$i -lt $name.Length;$i++) { $count++; if([char]::IsHighSurrogate($name[$i]) -and $i+1 -lt $name.Length -and [char]::IsLowSurrogate($name[$i+1])){$i++} }
    if($count -lt 1 -or $count -gt 20 -or $name -match '[\x00-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]') { throw '请输入 1–20 个字符，不含换行或控制字符。' }
    return $name
}
function Save-WelcomeName([string]$Value,[string]$ThemeChoice) {
    $name=ConvertTo-WelcomeName $Value
    # Read at save time to preserve CodexPath and any settings changed elsewhere.
    $config=if(Test-Path -LiteralPath $ConfigPath){Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json}else{[pscustomobject]@{}}
    if($null -eq $config){$config=[pscustomobject]@{}}
    $config | Add-Member -NotePropertyName WelcomeName -NotePropertyValue $name -Force
    if($ThemeChoice){$config | Add-Member -NotePropertyName Theme -NotePropertyValue $ThemeChoice -Force}
    $parent=Split-Path ([IO.Path]::GetFullPath($ConfigPath)) -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporary=Join-Path $parent ('welcome-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    try {
        [IO.File]::WriteAllText($temporary,($config | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temporary -Destination $ConfigPath -Force
    } finally { if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary} }
    return $name
}
if($TestUI -and -not $PSBoundParameters.ContainsKey('ConfigPath')) { throw 'UI tests require an explicit temporary ConfigPath.' }
if($PSBoundParameters.ContainsKey('WelcomeName') -or $PSBoundParameters.ContainsKey('Theme')) {
    if(-not $WelcomeName){$WelcomeName='JimmSun';if(Test-Path -LiteralPath $ConfigPath){$prior=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json;if($prior.WelcomeName){$WelcomeName=$prior.WelcomeName}}}
    Save-WelcomeName $WelcomeName $Theme; exit 0
}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Codex · 动画设置';$form.ClientSize=New-Object Drawing.Size(480,318)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$heading=New-Object Windows.Forms.Label
$heading.Text='你希望欢迎动画如何称呼你？';$heading.Location=New-Object Drawing.Point(24,22);$heading.AutoSize=$true
$nameInput=New-Object Windows.Forms.TextBox
$nameInput.Location=New-Object Drawing.Point(26,62);$nameInput.Size=New-Object Drawing.Size(426,32);$nameInput.MaxLength=40
$nameInput.Text='JimmSun'
if(Test-Path -LiteralPath $ConfigPath){$existing=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json;if($existing.WelcomeName){$nameInput.Text=$existing.WelcomeName}}
$hint=New-Object Windows.Forms.Label
$hint.Text="1–20 个字符。英文字母连笔书写，中文平滑显字。`r`n保存后，5.1s 和 8.1s 两版同时生效。"
$hint.Location=New-Object Drawing.Point(24,110);$hint.Size=New-Object Drawing.Size(432,52)
$themeLabel=New-Object Windows.Forms.Label
$themeLabel.Text='动画外观';$themeLabel.Location=New-Object Drawing.Point(24,170);$themeLabel.AutoSize=$true
$themeInput=New-Object Windows.Forms.ComboBox
$themeInput.Location=New-Object Drawing.Point(26,202);$themeInput.Size=New-Object Drawing.Size(426,32);$themeInput.DropDownStyle='DropDownList'
[void]$themeInput.Items.AddRange(@('跟随系统（自动识别深色 / 浅色）','浅色','深色'))
$themeChoices=@('system','light','dark');$themeInput.SelectedIndex=0
if($existing -and $existing.Theme -in $themeChoices){$themeInput.SelectedIndex=[Array]::IndexOf($themeChoices,$existing.Theme)}
$save=New-Object Windows.Forms.Button
$save.Text='保存';$save.Location=New-Object Drawing.Point(252,264);$save.Size=New-Object Drawing.Size(96,32)
$cancel=New-Object Windows.Forms.Button
$cancel.Text='取消';$cancel.Location=New-Object Drawing.Point(358,264);$cancel.Size=New-Object Drawing.Size(96,32);$cancel.DialogResult='Cancel'
$save.Add_Click({try{[void](Save-WelcomeName $nameInput.Text $themeChoices[$themeInput.SelectedIndex]);$form.DialogResult='OK';$form.Close()}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'设置未保存')}})
$form.Controls.AddRange(@($heading,$nameInput,$hint,$themeLabel,$themeInput,$save,$cancel));$form.AcceptButton=$save;$form.CancelButton=$cancel
$form.Add_Shown({$nameInput.SelectAll();$nameInput.Focus()})
if($TestUI){$nameInput.Text='Alex+Sun';$form.Add_Shown({$save.PerformClick()})}
[void]$form.ShowDialog();$form.Dispose()
