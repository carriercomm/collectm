[CmdletBinding()]
Param(

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
	[string]$installerPath,

    [Parameter(Mandatory=$false)]
    [switch]$SetupConfigFile=$true,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$username,

	[Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
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
Write-Host "Starting Installation"
Start-Process $installerPath -ArgumentList "/S" -Wait
Write-Host "Installed CollectM agent"
if ($SetupConfigFile -eq $true) {
    $installationDir = "C:\Program Files\CollectM"
    if ((Test-Path $installDir) -eq $false) {
        $installDir = "C:\Program Files (x86)\CollectM"
        if ((Test-Path $installDir) -eq $false) {
            Write-Host "could not locate installation directory of CollectM"
            Exit
        }
    }
    .\collectm.config.ps1 -filePath "$installDir\config\default.json" -restartService -svcPath "$installDir\bin\nssm.exe" -username $username -password $password -hostNameCase $hostNameCase -interval $interval -timeUntilRestart $timeUntilRestart -logDeletionDays $logDeletionDays -httpAdmin $httpAdmin -httpPassword $httpPassword -listenPort $listenPort -servers @("localhost:25826")
}