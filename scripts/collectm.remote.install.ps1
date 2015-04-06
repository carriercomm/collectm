[CmdletBinding()]
Param(

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$collectMRepo="https://github.com/mistio/collectm",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$gitBranch="master",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$installerName="CollectM-1.5.0.install.exe",

    [Parameter(Mandatory=$false)]
    [switch]$SetupConfigFile=$false,

    [Parameter(Mandatory=$false)]
	[string]$username,

	[Parameter(Mandatory=$false)]
	[string]$password,

    [Parameter(Mandatory=$false)]
    [ValidateSet("", "default", "lower", "upper")]
	[string]$hostNameCase="",

    [Parameter(Mandatory=$false)]
	[int32]$interval=5,

    [Parameter(Mandatory=$false)]
	[int32]$timeUntilRestart=-1,

    [Parameter(Mandatory=$false)]
	[int32]$logDeletionDays=30,

    [Parameter(Mandatory=$false)]
	[string]$httpAdmin="admin",

    [Parameter(Mandatory=$false)]
	[string]$httpPassword="admin",

    [Parameter(Mandatory=$false)]
	[int32]$listenPort=25826,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$svcName="CollectM",

    [Parameter(Mandatory=$false)]
    [string[]]$servers=@("localhost:25826")

)

function downloadFile($url, $filePath) {
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
}

if ($SetupConfigFile -eq $true -and (!$username -or !$password)) {
    Write-Host "You want the config file to be updated but you didn't give username or password"
    Exit
 }

$collectmDownloadUrl = $collectMRepo + "/" + $gitBranch + "/releases/" + $installerName

$collectmDeployScriptUrl = $collectMRepo + "/" + $gitBranch + "/scripts/collectm.deploy.ps1"

$collectmConfigScriptUrl = $collectMRepo + "/" + $gitBranch + "/scripts/collectm.config.ps1"

$installerPath = "collectm.installer.exe"

Write-Host "Downloading CollectM installer"

downloadFile -url $collectmDownloadUrl -filePath $installerPath

Write-Host "Downloading CollectM deploy script"

downloadFile -url $collectmDeployScriptUrl -filePath "collectm.deploy.ps1"

Write-Host "Downloading Collectm config script"

downloadFile -url $collectmConfigScriptUrl -filePath "collectm.config.ps1"

.\collectm.deploy.ps1 -installerPath $installerPath -SetupConfigFile $SetupConfigFile -username $username -password $password -hostNameCase $hostNameCase -interval $interval -timeUntilRestart $timeUntilRestart -logDeletionDays $logDeletionDays -httpAdmin $httpAdmin -httpPassword $httpPassword -listenPort $listenPort -svcName $svcName -servers $servers