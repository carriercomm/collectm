[CmdletBinding()]
Param(

    [Parameter(Mandatory=$false)]
    [ValidateSet( "", "CLONE", "BUILD", "INSTALL")]
	[string[]]$tasks="",

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
    [switch]$SetupConfigFile=$false,
	
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

    
if ($SETUP_DEV_ENV -eq $false -and $BUILD_FROM_REPO -eq $true) {
    $SETUP_DEV_ENV = $true
}

$workingDirectory = (Get-Item -Path ".\" -Verbose).FullName

$installerDir = $workingDirectory
$repoDir = "\collectm"


if ($task -contains "CLONE" -or $task -contains "CLONE_BUILD" -or $task -contains "CLONE_BUILD_INSTALL") {
    
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
    Set-Location ".."
}

if ($task -contains "CLONE_BUILD" -or $task -contains "CLONE_BUILD_INSTALL") {
    Set-Location $workingDirectory + "\collectm"
    ## build the installer ##
    grunt cleanDirs distexe
    $installerDir = $workingDirectory + "\collectm"
    Set-Location ".."
}

if ($task -contains "DOWNLOAD_INSTALL") {
    ## Just download Collect Release and install ##
	$filePath = $workingDirectory + "\collectM-installer.exe"
	downloadFileWithProgress -url "$collectMRepo/blob/$gitBranch/releases/CollectM-1.5.0.install.exe?raw=true" -filePath $filePath
	
}

if ($task -contains "CLONE_BUILD_INSTALL" -or $task -contains "DOWNLOAD_INSTALL") {
    Start-Process $filePath -ArgumentList "/S" -Wait
    Write-Host "Installed CollectM agent"
    $installationDir = "C:\Program Files\CollectM\config"
    if ((Test-Path $installDir) -eq $false) {
        $installDir = "C:\Program Files (x86)\CollectM\config"
        if ((Test-Path $installDir) -eq $false) {
            Write-Host "could not locate installation directory of CollectM"
            Exit
        }
    }
}







if ($SETUP_DEV_ENV -eq $false) {
	
    ## update the config file ##
    createConfigFile -filePath "$installDir\default.json"
    Write-Host "Created config file in $installDir\default.json"
    ## restart the CollectM service ##
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
	
}
Set-Location $workingDirectory
Write-Host "Done"
