# Control only this launcher's empty, dedicated Edge profile over loopback.
function Set-WelcomeContentOnly([string]$Profile,[string]$PageUrl) {
    $portFile=Join-Path $Profile 'DevToolsActivePort'
    if(-not (Test-Path -LiteralPath $portFile)){throw 'The animation window control endpoint is not ready.'}
    $port=[int](Get-Content -LiteralPath $portFile -TotalCount 1)
    if($port -lt 1 -or $port -gt 65535){throw 'Invalid animation window control port.'}
    $client=New-Object Net.WebClient
    try {$targets=$client.DownloadString("http://127.0.0.1:$port/json/list") | ConvertFrom-Json}finally{$client.Dispose()}
    $target=$targets | Where-Object {$_.type -eq 'page' -and $_.url -ceq $PageUrl} | Select-Object -First 1
    if(-not $target){throw 'The dedicated animation page was not found.'}
    $endpoint=[Uri]$target.webSocketDebuggerUrl
    if($endpoint.Scheme -ne 'ws' -or $endpoint.Host -ne '127.0.0.1' -or $endpoint.Port -ne $port){throw 'Unexpected animation window endpoint.'}
    $socket=New-Object Net.WebSockets.ClientWebSocket
    $cancel=New-Object Threading.CancellationTokenSource
    $cancel.CancelAfter(5000)
    $state=@{sequence=0}
    try {
        [void]$socket.ConnectAsync($endpoint,$cancel.Token).GetAwaiter().GetResult()
        function Invoke-WelcomeWindowCommand([string]$Method,[hashtable]$Parameters) {
            $id=++$state.sequence
            $data=[Text.Encoding]::UTF8.GetBytes((@{id=$id;method=$Method;params=$Parameters} | ConvertTo-Json -Compress -Depth 8))
            [void]$socket.SendAsync([ArraySegment[byte]]::new($data),[Net.WebSockets.WebSocketMessageType]::Text,$true,$cancel.Token).GetAwaiter().GetResult()
            while($true){
                $memory=New-Object IO.MemoryStream
                try {
                    do {
                        $buffer=New-Object byte[] 65536
                        $part=$socket.ReceiveAsync([ArraySegment[byte]]::new($buffer),$cancel.Token).GetAwaiter().GetResult()
                        if($part.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close){throw 'Animation window control closed unexpectedly.'}
                        $memory.Write($buffer,0,$part.Count)
                    }while(-not $part.EndOfMessage)
                    $message=[Text.Encoding]::UTF8.GetString($memory.ToArray()) | ConvertFrom-Json
                }finally{$memory.Dispose()}
                if($message.id -eq $id){
                    if($message.error){throw ('Animation window control: '+$message.error.message)}
                    return $message.result
                }
            }
        }
        $window=Invoke-WelcomeWindowCommand 'Browser.getWindowForTarget' @{}
        [void](Invoke-WelcomeWindowCommand 'Browser.setWindowBounds' @{windowId=$window.windowId;bounds=@{windowState='fullscreen'}})
        $watch=[Diagnostics.Stopwatch]::StartNew()
        do {
            $viewport=Invoke-WelcomeWindowCommand 'Runtime.evaluate' @{expression='JSON.stringify({width:innerWidth,height:innerHeight,outerWidth,outerHeight})';returnByValue=$true}
            $size=$viewport.result.value | ConvertFrom-Json
            if($size.width -gt 0 -and $size.height -gt 0 -and [Math]::Abs($size.width-$size.outerWidth) -le 1 -and [Math]::Abs($size.height-$size.outerHeight) -le 1){
                return ('contentOnly=True viewport={0}x{1} outer={2}x{3}' -f $size.width,$size.height,$size.outerWidth,$size.outerHeight)
            }
            Start-Sleep -Milliseconds 20
        }while($watch.Elapsed.TotalSeconds -lt 2)
        throw 'The animation title bar did not disappear before presentation.'
    }finally{$socket.Dispose();$cancel.Dispose()}
}
