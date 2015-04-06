[CmdletBinding()]
Param(

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$url,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$filePath

)

"Downloading $url"
$uri = New-Object "System.Uri" "$url"
$request = [System.Net.HttpWebRequest]::Create($uri)
## 15 second timeout ##
$request.set_Timeout(15000)
$response = $request.GetResponse()
$totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
$responseStream = $response.GetResponseStream()
$targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $filePath, Create
$buffer = New-Object byte[] 10KB
$count = $responseStream.Read($buffer,0,$buffer.length)
$downloadedBytes = $count
$iterations = 0
while ($count -gt 0) {
    [System.Console]::CursorLeft = 0
    $targetStream.Write($buffer, 0, $count)
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $downloadedBytes + $count
    $iterations += 1
    if (($iterations % 130 -eq 0) -or ([System.Math]::Floor($downloadedBytes/1024) -eq $totalLength)) {
        [System.Console]::Write("Downloaded {0}K of {1}K`n", [System.Math]::Floor($downloadedBytes/1024), $totalLength)
    }
}
Write-Host "Finished Download"
$targetStream.Flush()
$targetStream.Close()
$targetStream.Dispose()
$responseStream.Dispose()