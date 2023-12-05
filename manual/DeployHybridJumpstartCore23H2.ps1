param 
(
    [Parameter(Mandatory)]
    [ValidateSet("1", "2", "3", "4", "5", "6")]
    [Int]$azureStackHCINodes,
    [Parameter(Mandatory)]
    [ValidateSet("4", "8", "12", "16", "24", "32", "48")]
    [Int]$azureStackHCINodeMemory,
    [Parameter(Mandatory)]
    [ValidateSet("Full", "Basic", "None")]
    [String]$telemetryLevel,
    [Parameter(Mandatory)]
    [ValidateSet("Yes", "No")]
    [String]$updateImages,
    [String]$customRdpPort,
    [Parameter(Mandatory)]
    [String]$jumpstartPath,
    [String]$WindowsServerIsoPath,
    [String]$AzureStackHCIIsoPath,
    [String]$dnsForwarders
)

$Global:VerbosePreference = "Continue"
$Global:ErrorActionPreference = 'Stop'
$Global:ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try { Stop-Transcript | Out-Null } catch { }

try {
    if (!$dnsForwarders) {
        $customDNSForwarders = '8.8.8.8","1.1.1.1'
    }
    elseif ($dnsForwarders -like "Default") {
        $customDNSForwarders = '8.8.8.8","1.1.1.1'
    }
    else {
        $dnsForwarders = $dnsForwarders -replace '\s', ''
        $dnsForwarders.Split(',') | ForEach-Object { if ($_ -notmatch $pattern) {
                throw "You have provided an invalid external DNS forwarder IPv4 address: $_.`nPlease check the guidance, validate your entries and rerun the script."
                return
            }
        }
        $customDNSForwarders = $dnsForwarders.Replace(',', '","')
    }
}
catch {
    Write-Host "$_" -ForegroundColor Red
    return
}

try {

    # Verify Running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    If (-not $isAdmin) {
        Write-Host "-- Restarting as Administrator" -ForegroundColor Yellow ; Start-Sleep -Seconds 1
    
        if ($PSVersionTable.PSEdition -eq "Core") {
            Start-Process pwsh.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        }
        else {
            Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
        }
        exit
    }

    Write-Host "Checking for NuGet and installing if not present..."
    if ($null -eq (Get-PackageProvider -Name NuGet)) {   
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force
    }

    # Firstly, validate if Hyper-V is installed and prompt to enable and reboot if not
    Write-Host "Checking if required Hyper-V role/features are installed..."
    $hypervState = ((Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V*) | Where-Object { $_.State -eq "Disabled" })
    if ($hypervState) {
        Write-Host "`nThe following Hyper-V role/features are missing:`n"
        foreach ($feature in $hypervState) {
            "$($feature.DisplayName)"
        }
        Write-Host "`nDo you wish to enable them now?" -ForegroundColor Green
        if ((Read-Host "(Type Y or N)") -eq "Y") {
            Write-Host "`nYou chose to install the required Hyper-V role/features.`nYou will be prompted to reboot your machine once completed.`nRerun this script when back online..."
            Start-Sleep -Seconds 10
            $reboot = $false
            foreach ($feature in $hypervState) {
                $rebootCheck = Enable-WindowsOptionalFeature -Online -FeatureName $($feature.FeatureName) -ErrorAction Stop -NoRestart -Verbose -WarningAction SilentlyContinue
                if ($($rebootCheck.RestartNeeded) -eq $true) {
                    $reboot = $true
                }
            }
            if ($reboot -eq $true) {
                Write-Host "`nInstall completed. A reboot is required to finish installation - reboot now?`nIf not, you will need to reboot before deploying the Hybrid Jumpstart..." -ForegroundColor Green
                if ((Read-Host "(Type Y or N)") -eq "Y") {
                    Start-Sleep -Seconds 5
                    Restart-Computer -Force
                }
                else {
                    Write-Host 'You did not enter "Y" to confirm rebooting your host. Exiting... ' -ForegroundColor Red
                    exit
                }
            }
            else {
                Write-Host "Install completed. No reboot is required at this time. Continuing process..." -ForegroundColor Green
            }
        }
        else {
            Write-Host 'You did not enter "Y" to confirm installing the required Hyper-V role/features. Exiting... ' -ForegroundColor Red
            exit
        }
    }
    else {
        Write-Host "`nAll required Hyper-V role/features are present. Continuing process..." -ForegroundColor Green
    }
    
    Write-Host "Starting deployment of the Hybrid Jumpstart environment..."
    ### START LOGGING ###
    $runTime = $(Get-Date).ToString("MMddyy-HHmmss")
    $fullLogPath = "$PSScriptRoot\JumpstartLog_$runTime.txt"
    Write-Host "`nLog folder full path is $fullLogPath"
    Start-Transcript -Path "$fullLogPath" -Append
    $startTime = Get-Date -Format g
    $sw = [Diagnostics.Stopwatch]::StartNew()
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Define Variables
    $msLabUsername = "dell\labadmin"
    $msLabPassword = 'LS1setup!'
    $secMsLabPassword = New-Object -TypeName System.Security.SecureString
    $msLabPassword.ToCharArray() | ForEach-Object { $secMsLabPassword.AppendChar($_) }
    $msLabCreds = New-Object -typename System.Management.Automation.PSCredential -argumentlist $msLabUsername, $secMsLabPassword
    $mslabUri = "https://aka.ms/mslab/download"
    $wsIsoUri = "https://go.microsoft.com/fwlink/p/?LinkID=2195280"
    $azsHCIIsoUri = "https://aka.ms/PVenEREWEEW"
    $labConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/LabConfig23H2.ps1"
    $rdpConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/RDP.rdp"
    $psModulesUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/manual/PSmodules.zip"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $dateStamp = Get-Date -UFormat %d%b%y
    $vmPrefix = "HybridJumpstart-$dateStamp"
    $rdpConfigPath = "$desktopPath\$vmPrefix-DC.rdp"
    $jumpstartPath = "$jumpstartPath" + "\HybridJumpstart"
    $mslabLocalPath = "$jumpstartPath\mslab.zip"
    $labConfigPath = "$jumpstartPath\LabConfig.ps1"
    $parentDiskPath = "$jumpstartPath\ParentDisks"
    $updatePath = "$parentDiskPath\Updates"
    $cuPath = "$updatePath\CU"
    $ssuPath = "$updatePath\SSU"
    $isoPath = "$jumpstartPath\ISO"
    $flagsPath = "$jumpstartPath\Flags"
    $azsHciVhdPath = "$parentDiskPath\AzSHCI23H2_G2.vhdx"

    if (!$AzureStackHCIIsoPath) {
        $azsHciIsoPath = "$isoPath\AzSHCI"
        $azsHCIISOLocalPath = "$azsHciIsoPath\AzSHCI.iso"
    }
    else {
        $azsHCIISOLocalPath = $AzureStackHCIIsoPath
        $azsHciIsoPath = (Get-Item $azsHCIISOLocalPath).DirectoryName
    }
    if (!$WindowsServerIsoPath) {
        $wsIsoPath = "$isoPath\WS"
        $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
    }
    else {
        $wsISOLocalPath = $WindowsServerIsoPath
        $wsIsoPath = (Get-Item $wsISOLocalPath).DirectoryName
    }

    if (!$customRdpPort) {
        $customRdpPort = 3389
    }

    if (Get-VM | Where-Object { $_.Name -like "*$vmPrefix*" }) {
        Write-Host "There appears to be existing VMs on this system with the prefix: $vmPrefix..."
        Start-Sleep -Seconds 5
        $vmPrefix = Read-Host "Please enter a new prefix for your hybrid jumpstart VMs..."
        Write-Host "New virtual machines will be created with the prefix: $vmPrefix"
    }

    # Calculate Host Memory Sizing to account for oversizing
    [INT]$totalFreePhysicalMemory = Get-CimInstance Win32_OperatingSystem -Verbose:$false | ForEach-Object { [math]::round($_.FreePhysicalMemory / 1MB) }
    [INT]$totalInfraMemoryRequired = "4"
    [INT]$memoryAvailable = [INT]$totalFreePhysicalMemory - [INT]$totalInfraMemoryRequired
    [INT]$azsHciNodeMemoryRequired = ([Int]$azureStackHCINodeMemory * [Int]$azureStackHCINodes)
    if ($azsHciNodeMemoryRequired -ge $memoryAvailable) {
        $memoryOptions = 48, 32, 24, 16, 12, 8, 4
        $x = 0
        while ($azsHciNodeMemoryRequired -ge $memoryAvailable) {
            $azureStackHCINodeMemory = $memoryOptions[$x]
            $azsHciNodeMemoryRequired = ([Int]$azureStackHCINodeMemory * [Int]$azureStackHCINodes)
            $x++
        }
    }

    # Create folders
    Write-Host "`nCreating Hybrid Jumpstart folders within $jumpstartPath directory..."
    $requiredFolders = $jumpstartPath, $parentDiskPath, $updatePath, $cuPath, $ssuPath, $isoPath, $flagsPath, $azsHciIsoPath, $wsIsoPath
    foreach ($folder in $requiredFolders) {
        if (![System.IO.Directory]::Exists($folder)) {
            mkdir $folder -Force -Verbose | Out-Null
        }
    }

    # Download PowerShell Modules
    Write-Host "`nDownloading required PowerShell modules...`n"
    if (!(Test-Path -Path "$jumpstartPath\PSmodules.zip")) {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $psModulesUri -OutFile "$jumpstartPath\PSmodules.zip" -Verbose -UseBasicParsing
    }

    # Extract PowerShell modules
    Write-Host "`nExtracting PowerShell modules to C:\Program Files\WindowsPowerShell\Modules`n"
    Expand-Archive -Path "$jumpstartPath\PSmodules.zip" -DestinationPath "C:\Program Files\WindowsPowerShell\Modules" -Verbose -Force

    # Download MSLab
    if (!(Test-Path -Path $mslabLocalPath)) {
        Write-Host "`nDownloading MSLab for deployment of the environment...`n"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $mslabUri -OutFile $mslabLocalPath -Verbose -UseBasicParsing
    }

    # Extract MSLab
    if (Test-Path -Path $mslabLocalPath) {
        Write-Host "`nDownload complete. Extracting MSLab...`n"
        Expand-Archive -Path $mslabLocalPath -DestinationPath $jumpstartPath -Verbose -Force
    }

    # Replace LabConfig
    if (!((Get-Item $labConfigPath).LastWriteTime -ge (Get-Date))) {
        Write-Host "`nDownloading custom LabConfig.ps1 file from GitHub...`n"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "$labConfigUri" -OutFile "$labConfigPath" -UseBasicParsing
    }

    # Edit LabConfig
    if (Test-Path -Path $labConfigPath) {
        Write-Host "`nEditing LabConfig file with user preferences...`n"
        $labConfigFile = Get-Content -Path $labConfigPath
        $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodes>>", $azureStackHCINodes)
        $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodeMemory>>", $azureStackHCINodeMemory)
        $labConfigFile = $labConfigFile.Replace("<<WSServerIsoPath>>", $wsISOLocalPath)
        $labConfigFile = $labConfigFile.Replace("<<MsuFolder>>", $updatePath)
        $labConfigFile = $labConfigFile.Replace("<<VmPrefix>>", $vmPrefix)
        $labConfigFile = $labConfigFile.Replace("<<TelemetryLevel>>", $telemetryLevel)
        $labConfigFile = $labConfigFile.Replace("<<customDNSForwarders>>", $customDNSForwarders)
        Out-File -FilePath "$labConfigPath" -InputObject $labConfigFile -Force
    }

    # Download Windows Server ISO
    if (!$WindowsServerIsoPath) {
        Write-Host "`nNo Windows Server 2022 ISO was provided..."
        if (!(Test-Path -Path $wsISOLocalPath)) {
            Write-Host "Cannot locate a previously downloaded ISO. Starting download..."
            Start-BitsTransfer -Source $wsIsoUri -Destination $wsISOLocalPath -Verbose
        }
        else {
            Write-Host "Windows Server 2022 ISO located at $wsIsoLocalPath..."
        }
    }

    # Download Azure Stack HCI 23H2 ISO

    if (!$AzureStackHCIIsoPath) {
        Write-Host "`nNo Azure Stack HCI 23H2 ISO was provided..."
        if (!(Test-Path -Path $azsHCIISOLocalPath)) {
            Write-Host "Cannot locate a previously downloaded ISO. Starting download..."
            Start-BitsTransfer -Source $azsHCIIsoUri -Destination $azsHCIISOLocalPath 
        }
        else {
            Write-Host "Azure Stack HCI 23H2 ISO located at $azsHCIISOLocalPath..."
        }
    }

    # Download Updates
    if ($updateImages -eq "Yes") {
        Write-Host "`nYou have chosen to update your images with the latest updates. This will take some time..."
        if (!((Test-Path -Path "$cuPath\*" -Include "*.msu") -or (Test-Path -Path "$cuPath\*" -Include "NoUpdateDownloaded.txt"))) {
            $cuSearchString = "Cumulative Update for Microsoft server operating system*version 23H2 for x64-based Systems"
            $cuID = "Microsoft Server operating system-23H2"
            Write-Host "Looking for updates that match: $cuSearchString and $cuID"
            $cuUpdate = Get-MSCatalogUpdate -Search $cuSearchString -ErrorAction Stop | Where-Object Products -eq $cuID | Where-Object Title -like "*$($cuSearchString)*" | Select-Object -First 1
            if ($cuUpdate) {
                Write-Host "Found the latest update: $($cuUpdate.Title)"
                Write-Host "Downloading..."
                $cuUpdate | Save-MSCatalogUpdate -Destination $cuPath -AcceptMultiFileUpdates
            }
            else {
                Write-Host "No updates found, moving on..."
                $NoCuFlag = "$cuPath\NoUpdateDownloaded.txt"
                New-Item $NoCuFlag -ItemType file -Force
            }
        }
        elseif ((Test-Path -Path "$cuPath\*" -Include "*.msu")) {
            Write-Host "MSU has ben previously downloaded. Continuing process..."
        }
        elseif (Test-Path -Path "$cuPath\*" -Include "NoUpdateDownloaded.txt") {
            Write-Host "User selected to not update images with latest updates."
        }
    }
    else {
        Write-Host "User selected to not update images with latest updates."
        $NoCuFlag = "$cuPath\NoUpdateDownloaded.txt"
        New-Item $NoCuFlag -ItemType file -Force
    }

    if ($updateImages -eq "Yes") {
        if (!((Test-Path -Path "$ssuPath\*" -Include "*.msu") -or (Test-Path -Path "$ssuPath\*" -Include "NoUpdateDownloaded.txt"))) {
            $ssuSearchString = "Servicing Stack Update for Microsoft server operating system*version 23H2 for x64-based Systems"
            $ssuID = "Microsoft Server operating system-23H2"
            Write-Host "Looking for Servicing Stack updates that match: $ssuSearchString and $ssuID"
            $ssuUpdate = Get-MSCatalogUpdate -Search $ssuSearchString -ErrorAction Stop | Where-Object Products -eq $ssuID | Select-Object -First 1
            if ($ssuUpdate) {
                Write-Host "Found the latest update: $($ssuUpdate.Title)"
                Write-Host "Downloading..."
                $ssuUpdate | Save-MSCatalogUpdate -Destination $ssuPath
            }
            else {
                Write-Host "No updates found"
                $NoSsuFlag = "$ssuPath\NoUpdateDownloaded.txt"
                New-Item $NoSsuFlag -ItemType file -Force
            }
        }
        elseif ((Test-Path -Path "$ssuPath\*" -Include "*.msu")) {
            Write-Host "MSU has ben previously downloaded. Continuing process..."
        }
        elseif (Test-Path -Path "$ssuPath\*" -Include "NoUpdateDownloaded.txt") {
            Write-Host "User selected to not update images with latest Servicing Stack updates..."
        }
    }
    else {
        Write-Host "User selected to not update images with latest Servicing Stack updates..."
        $NoSsuFlag = "$ssuPath\NoUpdateDownloaded.txt"
        New-Item $NoSsuFlag -ItemType file -Force
    }

    # Create AzSHCI Virtual Disk
    if (!(Test-Path -Path $azsHciVhdPath)) {
        # Create Azure Stack HCI Host Image from ISO
        Write-Host "`nCreating Azure Stack HCI images for nested nodes..."
        $scratchPath = "$jumpstartPath\Scratch"
        New-Item -ItemType Directory -Path "$scratchPath" -Force | Out-Null
        
        # Determine if any SSUs are available
        $ssu = Test-Path -Path "$ssuPath\*" -Include "*.msu"

        if ($ssu) {
            Convert-WindowsImage -SourcePath $azsHCIISOLocalPath -SizeBytes 127GB -VHDPath $azsHciVhdPath `
                -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -Package $ssuPath -TempDirectory $scratchPath -Verbose
        }
        else {
            Convert-WindowsImage -SourcePath $azsHCIISOLocalPath -SizeBytes 127GB -VHDPath $azsHciVhdPath `
                -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -TempDirectory $scratchPath -Verbose
        }

        Start-Sleep -Seconds 10

        Write-Host "Mounting VHD to inject updates and finalize image creation..."
        $mount = Mount-VHD -Path $azsHciVhdPath -Passthru -ErrorAction Stop -Verbose
        Start-Sleep -Seconds 2

        $driveLetter = (Get-Disk -Number $mount.Number | Get-Partition | Where-Object Driveletter).DriveLetter
        $updatepath = "$($driveLetter):\"
        $updates = Get-ChildItem -path $cuPath -Recurse | Where-Object { ($_.extension -eq ".msu") -or ($_.extension -eq ".cab") } | Select-Object fullname
        foreach ($update in $updates) {
            Write-Host "Found the following update file to inject: $($update.fullname)"
            $command = "dism /image:" + $updatepath + " /add-package /packagepath:'" + $update.fullname + "'"
            Write-Host "Executing the following command: $command"
            Invoke-Expression $command
        }

        Write-Host "Cleaning up the image..."
        $command = "dism /image:" + $updatepath + " /Cleanup-Image /spsuperseded"
        Invoke-Expression $command

        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        if ($osInfo.ProductType -eq 1) {
            Write-Host "Enabling the Hyper-V role..."
            $command = "dism /image:" + $updatepath + " /enable-Feature:Microsoft-Hyper-V"
            Invoke-Expression $command
        }

        Write-Host "Dismounting the Virtual Disk..."
        Dismount-VHD -path $azsHciVhdPath -confirm:$false

        Start-Sleep -Seconds 5

        # Enable Hyper-V role on the Azure Stack HCI Host Image
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        if ($osInfo.ProductType -eq 3) {
            Write-Host "Enabling the Hyper-V role..."
            Install-WindowsFeature -Vhd $azsHciVhdPath -Name Hyper-V
        }

        # Remove the scratch folder
        Remove-Item -Path "$scratchPath" -Recurse -Force | Out-Null
    }

    # Deploy MSLab Prereqs
    if (!(Test-Path -Path "$flagsPath\PreReqComplete.txt")) {
        Write-Host "`nStarting MSLab prerequisites..."
        Set-Location $jumpstartPath
        .\1_Prereq.ps1
        $preReqFlag = "$flagsPath\PreReqComplete.txt"
        New-Item $preReqFlag -ItemType file -Force
    }

    # Create Parent Disks with MSLab
    if (!(Test-Path -Path "$flagsPath\CreateDisksComplete.txt")) {
        Write-Host "`nCreating Windows Server images and Domain Controller..."
        Set-Location $jumpstartPath
        .\2_CreateParentDisks.ps1
        $parentDiskFlag = "$flagsPath\CreateDisksComplete.txt"
        New-Item $parentDiskFlag -ItemType file -Force
    }

    # Deploy environment with MSLab
    if (!(Test-Path -Path "$flagsPath\DeployComplete.txt")) {
        Write-Host "`nCreating Azure Stack HCI nodes and finalizing deployment..."
        Set-Location $jumpstartPath
        .\Deploy.ps1
        $deployFlag = "$flagsPath\DeployComplete.txt"
        New-Item $deployFlag -ItemType file -Force
        Write-Host "Sleeping for 2 minutes to allow for VMs to join domain and reboot as required"
        Start-Sleep -Seconds 120
    }

    # Download RDP file
    if (!(Test-Path -Path "$rdpConfigPath")) {
        Write-Host "`nDownloading RDP file from GitHub..."
        Invoke-WebRequest -Uri "$rdpConfigUri" -OutFile "$rdpConfigPath" -UseBasicParsing
        Write-Host "`nPreparing RDP file..."
        Start-Sleep -Seconds 10
    }

    # Edit RDP file
    if (!((Get-Item $rdpConfigPath).LastWriteTime -ge (Get-Date))) {
        Write-Host "`nEditing RDP file to customize for connection to $vmPrefix-DC..."
        $vmIpAddress = (Get-VMNetworkAdapter -Name 'Internet' -VMName "$vmPrefix-DC").IpAddresses | Where-Object { $_ -notmatch ':' }
        $rdpConfigFile = Get-Content -Path "$rdpConfigPath"
        $rdpConfigFile = $rdpConfigFile.Replace("<<VM_IP_Address>>", $vmIpAddress)
        Out-File -FilePath "$rdpConfigPath" -InputObject $rdpConfigFile -Force
    }

    # Enable RDP on DC
    $vmIpAddress = (Get-VMNetworkAdapter -Name 'Internet' -VMName "$vmPrefix-DC").IpAddresses | Where-Object { $_ -notmatch ':' }
    if (!((Test-NetConnection $vmIpAddress -CommonTCPPort rdp).TcpTestSucceeded -eq "True")) {
        Write-Host "`nEnabling RDP access into $vmPrefix-DC..."
        Invoke-Command -VMName "$vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
        }
    }

    # Deploy WAC
    $checkWac = Invoke-Command -VMName "$vmPrefix-WACGW" -Credential $msLabCreds -ScriptBlock {
        [bool] (Get-WmiObject -class win32_product  | Where-Object { $_.Name -eq "Windows Admin Center" })
    }
    if ($checkWac -eq $false) {
        Write-Host "`nDeploying Windows Admin Center into $vmPrefix-WACGW..."
        Invoke-Command -VMName "$vmPrefix-WACGW" -Credential $msLabCreds -ScriptBlock {
            if (-not (Test-Path -Path "C:\WindowsAdminCenter.msi")) {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri 'https://aka.ms/WACDownload' -OutFile "C:\WindowsAdminCenter.msi" -UseBasicParsing
            }
            Start-Process msiexec.exe -Wait -ArgumentList `
                "/i C:\WindowsAdminCenter.msi /qn /L*v log.txt REGISTRY_REDIRECT_PORT_80=1 SME_PORT=443 SSL_CERTIFICATE_OPTION=generate"
            do {
                if ((Get-Service ServerManagementGateway -ErrorAction SilentlyContinue).status -ne "Running") {
                    Write-Output "Starting Windows Admin Center (ServerManagementGateway) Service"
                    Start-Service ServerManagementGateway
                }
                Start-sleep -Seconds 5
            } until ((Test-NetConnection -ComputerName "localhost" -port 443).TcpTestSucceeded)
        }
    }

    # Update DC
    $updateDc = Invoke-Command -VMName "$vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
        if (Get-ChildItem Cert:\LocalMachine\Root\ | Where-Object subject -like "CN=Windows Admin Center") {
            return $true
        }
        else {
            return $false
        }
    }
    if ($updateDc -eq $false) {
        Write-Host "`nUpdating $vmPrefix-DC with final configuration..."
        Invoke-Command -VMName "$vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
            $GatewayServerName = "WACGW"
            Start-Sleep 10
            $gatewayObject = Get-ADComputer -Identity $GatewayServerName
            $computers = (Get-ADComputer -Filter { OperatingSystem -eq "Azure Stack HCI" }).Name
            foreach ($computer in $computers) {
                $computerObject = Get-ADComputer -Identity $computer
                Set-ADComputer -Identity $computerObject -PrincipalsAllowedToDelegateToAccount $gatewayObject
            }
            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/media/hybridjumpstart.png' -OutFile "C:\Windows\Web\Wallpaper\Windows\hybridjumpstart.png" -UseBasicParsing
            Set-GPPrefRegistryValue -Name "Default Domain Policy" -Context User -Action Replace -Key "HKCU\Control Panel\Desktop" -ValueName Wallpaper -Value "C:\Windows\Web\Wallpaper\Windows\hybridjumpstart.png" -Type String
            $cert = Invoke-Command -ComputerName $GatewayServerName `
                -ScriptBlock { Get-ChildItem Cert:\LocalMachine\My\ | Where-Object subject -eq "CN=Windows Admin Center" }
            $cert | Export-Certificate -FilePath $env:TEMP\WACCert.cer
            Import-Certificate -FilePath $env:TEMP\WACCert.cer -CertStoreLocation Cert:\LocalMachine\Root\
        }
    }

    # Update WAC Extensions
    $wacExtensions = Invoke-Command -VMName "$vmPrefix-WACGW" -Credential $msLabCreds -ScriptBlock {
        [bool] (Test-Path -Path "C:\WACExtensionsUpdated.txt")
    }
    if ($wacExtensions -eq $false) {
        Write-Host "`nUpdating Windows Admin Center extensions..."
        Invoke-Command -VMName "$vmPrefix-WACGW" -Credential $msLabCreds -ScriptBlock {
            $GatewayServerName = "WACGW"
            # Import Windows Admin Center PowerShell Modules
            $items = Get-ChildItem -Path "C:\Program Files\Windows Admin Center\PowerShell\Modules" -Recurse | `
                Where-Object Extension -eq ".psm1"
            foreach ($item in $items) {
                Import-Module $item.fullName
            }
            # Grab installed extensions that are not up to date.
            $InstalledExtensions = Get-Extension -GatewayEndpoint $GatewayServerName  | Where-Object status -eq Installed
            $ExtensionsToUpdate = $InstalledExtensions | Where-Object IsLatestVersion -eq $False
    
            # Update out-of-date extensions
            foreach ($Extension in $ExtensionsToUpdate) {
                Update-Extension -GatewayEndpoint https://$GatewayServerName -ExtensionId $Extension.ID
            }
            $extensionsFlag = "C:\WACExtensionsUpdated.txt"
            New-Item $extensionsFlag -ItemType file -Force
        }
    }

    Write-Host "`nDeployment complete....use the Remote Desktop icon to connect to your Domain Controller..." -ForegroundColor Green

    $endTime = Get-Date -Format g
    $sw.Stop()
    $Hrs = $sw.Elapsed.Hours
    $Mins = $sw.Elapsed.Minutes
    $Secs = $sw.Elapsed.Seconds
    $difference = '{0:00}h:{1:00}m:{2:00}s' -f $Hrs, $Mins, $Secs

    Write-Host "Hybrid Jumpstart deployment completed successfully, taking $difference." -ErrorAction SilentlyContinue
    Write-Host "You started the Hybrid Jumpstart deployment at $startTime." -ErrorAction SilentlyContinue
    Write-Host "Hybrid Jumpstart deployment completed at $endTime." -ErrorAction SilentlyContinue
}
catch {
    Set-Location $PSScriptRoot
    throw $_.Exception.Message
    Write-Host "Deployment failed - follow the troubleshooting steps online, and then retry"
    Read-Host | Out-Null
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}