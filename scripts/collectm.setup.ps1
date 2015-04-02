[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
	[string]$username,

	[Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
	[string]$password,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$collectMRepo="https://github.com/mistio/collectm",

    [Parameter(Mandatory=$false)]
    [ValidateSet("", "default", "lower", "upper")]
	[string]$hostNameCase="",
	
    [Parameter(Mandatory=$false)]
	[switch]$SETUP_DEV_ENV=$false,
    
	[Parameter(Mandatory=$false)]
	[switch]$BUILD_FROM_REPO=$false,
	
	[Parameter(Mandatory=$false)]
	[string]$gitBranch="master",

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

function createConfigFile($filePath) {
    if ((Test-Path $filePath) -eq $true) {
        Remove-Item $filePath
    }
    $configStr = "{`n  ""Hostname"": ""$username"",`n"
    $configStr += "  //""HostnameCase"": ""default"" or ""lower"" or ""upper""`n"
    if ($hostNameCase -ne "") {
        $configStr += "  ""HostnameCase"": ""$hostNameCase"",`n"
    }
    $configStr += "  ""Interval"": $interval,`n"
    $configStr += "  ""Crypto"": {`n    ""SecurityLevel"": 2,`n    ""Username"": ""$username"",`n    ""Password"": ""$password""`n  },`n"
    $configStr += "  //  ""CollectmTimeToLive"": 86400 Used to restart the service every # of seconds. Useful in case of memory leaks`n"
    if ($timeUntilRestart -ne -1) {
        $configStr += "  ""CollectmTimeToLive"": $timeUntilRestart,`n"
    }
    $configStr += "  //  Every day, remove old logs (based on modified time).`n  //  If unset, or if set to 0, no logs will be deleted.`n"
    $configStr += 
    $congigStr += "  ""LogDeletionDays"": $logDeletionDays,`n"
    $configStr += "  ""HttpConfig"": {`n    ""enable"": 1,`n    ""listenPort"": $listenPort,`n    ""login"": ""$httpAdmin"",`n    ""password"": ""$httpPassword""`n  },`n"
    $configStr += "  ""Network"": {`n    ""servers"":`n    [`n    ]`n"

    $counter = 0
    foreach ($elem in $servers){
        $elems = $elem.Split(":")
        if ($elems.Count -eq 2) {
            if ($($elems[1].Trim()) -match "^[-]?[0-9.]+$") {
                if (counter -ge 1) {
                    $configStr = ",`n      {`n        ""hostname"": ""$($elems[0])"",`n        ""port"": $($elems[1])`n      }"
                } else {
                    $configStr = "      {`n        ""hostname"": ""$($elems[0])"",`n        ""port"": $($elems[1])`n      }"
                }
                $counter++
            }
        }
    }

    $configStr += "`n  },`n"
    $configStr += "  ""Plugin"": {`n    ""collectdCompat"": {`n      ""enable"": 1`n    },`n    ""sysconfig"": {`n      ""enable"": 1`n    },`n"
    $configStr += "    ""perfmon"": {`n      ""enable"": 1,`n      ""counters"" : [`n"
    $configStr += "        // This is an example :`n        {`n          ""counter"": ""\\LogicalDisk(C:)\\% Free Space"",`n          ""enable"": 1,`n          ""plugin"": ""perfmon_LogicalDisk"",`n          ""plugin_instance"": ""C"",`n          ""type"": ""percent"",`n          ""type_instance"": ""Free Space""`n        }`n      ]`n    },`n"
    $configStr += "    ""process"": {`n      ""enable"": 1,`n      ""process"": {`n        // The key is not used in Collectm. It only helps for config overwrite in local.json`n        // The value is an array with ""plugin"", ""instance"" and ""commandline"".`n        // This is an example :`n        ""My Collectm"": {`n          ""plugin"": ""process"",`n          ""instance"": ""collectm"",`n          ""commandline"": "".*node.*collectm\\.js.*""`n        },`n"
    $configStr += "        ""My NSSM for Collectm"": {`n          ""plugin"": ""process"",`n          ""instance"": ""nssm"",`n          ""commandline"": "".*collectm.*nssm\\.exe.*""`n        }`n      }`n    }`n  }`n"
    $configStr += "}"

    ## Output String to File and make sure that the file is UTF 8 w/o BOM ##
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
    [System.IO.File]::WriteAllLines($filePath, $configStr, $Utf8NoBomEncoding)

}

function updatePath($newPath) {
	## Get the current search path from the environment keys in the registry. ##
	$OldPath=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment" -Name PATH).Path
	## See if a new folder has been supplied. ##
	if (!$newPath -or !$OldPath) { 
		Return "No Folder Supplied. $ENV:PATH Unchanged"
	}
	## See if the new folder exists on the file system. ##
	if (!(TEST-PATH $newPath)) { 
		Return "Folder Does not Exist"
	}
	## See if the new Folder is already in the path. ##
	if ($ENV:PATH | Select-String -SimpleMatch $newPath) {
		Return "Folder already within path"
	}
	## Set the New Path ##
	$NewPath = "$OldPath;$newPath"
	Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment" -Name PATH –Value $newPath
	Return $NewPath
}

function downloadFileWithProgress($url, $filePath) {
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

    
if ($SETUP_DEV_ENV -eq $false -and $BUILD_FROM_REPO -eq $true) {
    $SETUP_DEV_ENV = $true
}

$workingDirectory = (Get-Item -Path ".\" -Verbose).FullName

if ($SETUP_DEV_ENV -eq $false) {
	## Just download Collect Release and install ##
	$filePath = $workingDirectory + "\collectM-installer.exe"
	downloadFileWithProgress -url "$collectMRepo/blob/$gitBranch/releases/CollectM-1.5.0.install.exe?raw=true" -filePath $filePath
	Start-Process $filePath -ArgumentList "/S" -Wait
    Write-Host "Installed CollectM agent"
    $installDir = "C:\Program Files\CollectM\config"
    if ((Test-Path $installDir) -eq $false) {
        $installDir = "C:\Program Files (x86)\CollectM\config"
        if ((Test-Path $installDir) -eq $false) {
            Write-Host "could not locate installation directory of CollectM"
            Exit
        }
    }
    createConfigFile -filePath "$installDir\default.json"
    Write-Host "Created config file in $installDir\default.json"
    Start-Process "$installDir\..\bin\nssm.exe" -ArgumentList "restart $svcName"
    Write-Host "Restarted CollectM service to load new config file"
}
else {

    ## download and install nodejs ##
    $filePath = $workingDirectory + "\node-v0.12.2-x86.msi"
	#downloadFileWithProgress -url 'http://nodejs.org/dist/v0.12.2/node-v0.12.2-x86.msi' -filePath $filePath
	#Start-Process $filePath -ArgumentList '' -Wait
	$installDir = "'C:\Program Files\nodejs'"
	if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		$installDir = 'C:\Program Files (x86)\nodejs'
        if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		    Write-Host "$installDir does not exist"
		    Exit
	    }
	}

    ## download and install makensis ##
    $filePath = $workingDirectory + "\nsis-3.0b1-setup.exe"
	#downloadFileWithProgress -url 'http://downloads.sourceforge.net/project/nsis/NSIS%203%20Pre-release/3.0b1/nsis-3.0b1-setup.exe?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fnsis%2Ffiles%2FNSIS%25203%2520Pre-release%2F3.0b1%2Fnsis-3.0b1-setup.exe%2Fdownload%3Fuse_mirror%3Dnetcologne%26download%3D&ts=1427893749&use_mirror=softlayer-ams' -filePath $filePath
	#Start-Process $filePath -ArgumentList '' -Wait
	$installDir = "'C:\Program Files\nodejs'"
	if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		$installDir = 'C:\Program Files (x86)\nodejs'
        if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		    Write-Host "$installDir does not exist"
		    Exit
	    }
	}

	## download and install Git ##
	$filePath = $workingDirectory + "\Git-1.9.5-preview20150319.exe"
	#downloadFileWithProgress -url 'https://github.com/msysgit/msysgit/releases/download/Git-1.9.5-preview20150319/Git-1.9.5-preview20150319.exe' -filePath $filePath
	#Start-Process $filePath -ArgumentList '/SILENT /LOG /NORESTART /RESTARTAPPLICATIONS' -Wait
	$installDir = "'C:\Program Files\Git\bin\'"
	if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		$installDir = 'C:\Program Files (x86)\Git\bin\'
        if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		    Write-Host "$installDir does not exist"
		    Exit
	    }
	}
	$filePath = $workingDirectory + "\collectm"
	if ((Test-Path $filePath) -eq $true) {
        ## if there is a folder with name collectm already here delete it and all it's contents ##
		Remove-Item -Path $filePath -Force -Recurse
	}
    ## clone CollectM from git repo ##
	Write-Host "Cloning Repo"
	if (!$gitBranch -or ($gitBranch -Contains "master")) {
        git clone 'https://github.com/mistio/collectm.git' --verbose --progress 2>&1 | % { $_.ToString() } 
	} else {
        git clone 'https://github.com/mistio/collectm.git' --branch $gitBranch --verbose --progress 2>&1 | % { $_.ToString() } 
	}
    Set-Location $filePath
    ## let npm download dependencies
    npm install 2>&1 | % { $_.ToString() } 
    ## download grunt cli with npm
    npm install -g grunt 2>&1 | % { $_.ToString() } 
    $installDir = "C:\Users\" + "$env:USERNAME" + "\AppData\Roaming\npm\"
	if ((updatePath -newPath $installDir) -Contains "Folder Does not Exist") {
		Write-Host "$installDir does not exist"
		Exit
	}
    grunt cleanDirs distexe
}
Set-Location $workingDirectory
Write-Host "Done"
