configuration AzLWorkshop
{
    param 
    (
        [System.Management.Automation.PSCredential]$Admincreds,
        [Parameter(Mandatory)]
        [ValidateSet("Single Machine", "2-Machine Non-Converged", "2-Machine Fully-Converged", "2-Machine Switchless Dual-Link", "3-Machine Non-Converged", "3-Machine Fully-Converged",
            "3-Machine Switchless Single-Link", "3-Machine Switchless Dual-Link", "4-Machine Non-Converged", "4-Machine Fully-Converged", "4-Machine Switchless Dual-Link")]
        [String]$azureLocalArchitecture,
        [Parameter(Mandatory)]
        [ValidateSet("16", "24", "32", "48")]
        [Int]$azureLocalMachineMemory,
        [Parameter(Mandatory)]
        [ValidateSet("Full", "Basic", "None")]
        [String]$telemetryLevel,
        [ValidateSet("Yes", "No")]
        [String]$updateImages,
        [Parameter(Mandatory)]
        [String]$domainName,
        [String]$customRdpPort,
        [String]$jumpstartPath,
        [String]$WindowsServerIsoPath,
        [String]$AzureLocalIsoPath,
        [String]$customDNSForwarders
    )
    
    Import-DscResource -ModuleName 'ComputerManagementDsc' -ModuleVersion 10.0.0
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'hyperVDsc' -ModuleVersion 4.0.0
    Import-DscResource -ModuleName 'StorageDSC' -ModuleVersion 6.0.1
    Import-DscResource -ModuleName 'NetworkingDSC' -ModuleVersion 9.0.0
    Import-DscResource -ModuleName 'MSCatalogLTS' -ModuleVersion 1.0.5
    Import-DscResource -ModuleName 'Hyper-ConvertImage' -ModuleVersion 10.2

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
        }

        [String]$mslabUri = "https://aka.ms/mslab/download"
        [String]$wsIsoUri = "https://go.microsoft.com/fwlink/p/?LinkID=2195280"
        [String]$azureLocalIsoUri = "https://aka.ms/HCIReleaseImage"
        [String]$labConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/AzureLocalLabConfig.ps1"
        [String]$rdpConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/RDP.rdp"

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if (!$customRdpPort) {
            $customRdpPort = 3389
        }

        $dateStamp = Get-Date -UFormat %d%b%y
        $vmPrefix = "AzLWorkshop-$dateStamp"

        # Calculate the number of Azure Local machines that are required, before calculating memory sizing
        if ($azureLocalArchitecture -eq "Single Machine") {
            $azureLocalMachines = 1
        }
        else {
            # Take the first character of the architecture string to determine the number of machines
            $azureLocalMachines = [INT]$azureLocalArchitecture.Substring(0, 1)
        }

        # Calculate Host Memory Sizing to account for oversizing
        [INT]$totalFreePhysicalMemory = Get-CimInstance Win32_OperatingSystem -Verbose:$false | ForEach-Object { [math]::round($_.FreePhysicalMemory / 1MB) }
        [INT]$totalInfraMemoryRequired = "4"
        [INT]$memoryAvailable = [INT]$totalFreePhysicalMemory - [INT]$totalInfraMemoryRequired
        [INT]$azureLocalMachineMemoryRequired = ([Int]$azureLocalMachineMemory * [Int]$azureLocalMachines)
        if ($azureLocalMachineMemoryRequired -ge $memoryAvailable) {
            $memoryOptions = 48, 32, 24, 16
            $x = 0
            while ($azureLocalMachineMemoryRequired -ge $memoryAvailable) {
                $azureLocalMachineMemory = $memoryOptions[$x]
                $azureLocalMachineMemoryRequired = ([Int]$azureLocalMachineMemory * [Int]$azureLocalMachines)
                $x++
            }
        }

        # Define parameters
        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {
            # If this in Azure, lock things in specifically
            $targetDrive = "V"
            $jumpstartPath = "$targetDrive" + ":\AzLWorkshop"
        }
        else {
            $jumpstartPath = "$jumpstartPath" + "\AzLWorkshop"
        }

        $mslabLocalPath = "$jumpstartPath\mslab.zip"
        $labConfigPath = "$jumpstartPath\LabConfig.ps1"
        $parentDiskPath = "$jumpstartPath\ParentDisks"
        $updatePath = "$parentDiskPath\Updates"
        $cuPath = "$updatePath\CU"
        $ssuPath = "$updatePath\SSU"
        $isoPath = "$jumpstartPath\ISO"
        $flagsPath = "$jumpstartPath\Flags"
        $azLocalVhdPath = "$parentDiskPath\AzL_G2.vhdx"

        $domainNetBios = $domainName.Split('.')[0]
        $msLabUsername = "$domainNetBios\$($Admincreds.UserName)"
        $msLabPassword = $Admincreds.GetNetworkCredential().Password
        $secMsLabPassword = New-Object -TypeName System.Security.SecureString
        $msLabPassword.ToCharArray() | ForEach-Object { $secMsLabPassword.AppendChar($_) }
        $msLabCreds = New-Object -typename System.Management.Automation.PSCredential -argumentlist $msLabUsername, $secMsLabPassword

        if (!((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77")) {
            # If this is on-prem, user should have supplied a folder/path they wish to install into
            # Users can also supply a pre-downloaded ISO for both WS and Azure Local
            if (!$AzureLocalIsoPath) {
                $azLocalIsoPath = "$isoPath\AzureLocal"
                $azLocalISOLocalPath = "$azLocalIsoPath\AzureLocal.iso"
            }
            else {
                $azLocalISOLocalPath = $AzureLocalIsoPath
                $azLocalIsoPath = (Get-Item $azLocalISOLocalPath).DirectoryName
            }
            if (!$WindowsServerIsoPath) {
                $wsIsoPath = "$isoPath\WS"
                $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
            }
            else {
                $wsISOLocalPath = $WindowsServerIsoPath
                $wsIsoPath = (Get-Item $wsISOLocalPath).DirectoryName
            }
        }
        else {
            $wsIsoPath = "$isoPath\WS"
            $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
            $azLocalIsoPath = "$isoPath\AzureLocal"
            $azLocalISOLocalPath = "$azLocalIsoPath\AzureLocal.iso"
        }

        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {

            #### CREATE STORAGE SPACES V: & VM FOLDER ####

            Script StoragePool {
                SetScript  = {
                    New-StoragePool -FriendlyName JumpstartPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
                }
                TestScript = {
                (Get-StoragePool -ErrorAction SilentlyContinue -FriendlyName JumpstartPool).OperationalStatus -eq 'OK'
                }
                GetScript  = {
                    @{Ensure = if ((Get-StoragePool -FriendlyName JumpstartPool).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
                }
            }
            Script VirtualDisk {
                SetScript  = {
                    $disks = Get-StoragePool -FriendlyName JumpstartPool -IsPrimordial $False | Get-PhysicalDisk
                    $diskNum = $disks.Count
                    New-VirtualDisk -StoragePoolFriendlyName JumpstartPool -FriendlyName JumpstartDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
                }
                TestScript = {
                (Get-VirtualDisk -ErrorAction SilentlyContinue -FriendlyName JumpstartDisk).OperationalStatus -eq 'OK'
                }
                GetScript  = {
                    @{Ensure = if ((Get-VirtualDisk -FriendlyName JumpstartDisk).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
                }
                DependsOn  = "[Script]StoragePool"
            }
            Script FormatDisk {
                SetScript  = {
                    $vDisk = Get-VirtualDisk -FriendlyName JumpstartDisk
                    if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
                        $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AzLWorkshop -AllocationUnitSize 64KB -FileSystem NTFS
                    }
                    elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
                        $vDisk | Get-Disk | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AzLWorkshop -AllocationUnitSize 64KB -FileSystem NTFS
                    }
                }
                TestScript = { 
                (Get-Volume -ErrorAction SilentlyContinue -FileSystemLabel AzLWorkshop).FileSystem -eq 'NTFS'
                }
                GetScript  = {
                    @{Ensure = if ((Get-Volume -FileSystemLabel AzLWorkshop).FileSystem -eq 'NTFS') { 'Present' } Else { 'Absent' } }
                }
                DependsOn  = "[Script]VirtualDisk"
            }

            File "JumpstartFolder" {
                Type            = 'Directory'
                DestinationPath = $jumpstartPath
                DependsOn       = "[Script]FormatDisk"
            }
        }
        else {
            # Running on-prem, outside of Azure
            File "JumpstartFolder" {
                Type            = 'Directory'
                DestinationPath = $jumpstartPath
            }
        }

        File "ISOpath" {
            DestinationPath = $isoPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]JumpstartFolder"
        }

        File "flagsPath" {
            DestinationPath = $flagsPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]JumpstartFolder"
        }

        File "WSISOpath" {
            DestinationPath = $wsIsoPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]ISOpath"
        }

        File "azLocalIsoPath" {
            DestinationPath = $azLocalIsoPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]ISOpath"
        }

        File "ParentDisks" {
            DestinationPath = $parentDiskPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]JumpstartFolder"
        }

        File "Updates" {
            DestinationPath = $updatePath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]ParentDisks"
        }

        File "CU" {
            DestinationPath = $cuPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]Updates"
        }

        File "SSU" {
            DestinationPath = $ssuPath
            Type            = 'Directory'
            Force           = $true
            DependsOn       = "[File]Updates"
        }

        Script "Download MSLab" {
            GetScript  = {
                $result = Test-Path -Path "$Using:mslabLocalPath"
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "$Using:mslabUri" -OutFile "$Using:mslabLocalPath" -UseBasicParsing
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]JumpstartFolder"
        }

        Script "Extract MSLab" {
            GetScript  = {
                $result = !(Test-Path -Path "$Using:mslabLocalPath")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Expand-Archive -Path "$Using:mslabLocalPath" -DestinationPath "$Using:jumpstartPath" -Force
                #$extractedFlag = "$Using:flagsPath\MSLabExtracted.txt"
                #New-Item $extractedFlag -ItemType file -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Download MSLab"
        }

        Script "Replace LabConfig" {
            GetScript  = {
                $result = ((Get-Item $Using:labConfigPath).LastWriteTime -ge (Get-Date))
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "$Using:labConfigUri" -OutFile "$Using:labConfigPath" -UseBasicParsing
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Extract MSLab"
        }

        Script "Edit LabConfig" {
            GetScript  = {
                $result = !(Test-Path -Path "$Using:labConfigPath")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $labConfigFile = Get-Content -Path "$Using:labConfigPath"
                $labConfigFile = $labConfigFile.Replace("<<DomainAdminName>>", $Using:msLabUsername)
                $labConfigFile = $labConfigFile.Replace("<<AdminPassword>>", $Using:msLabPassword)
                $labConfigFile = $labConfigFile.Replace("<<DomainNetBios>>", $Using:domainNetBios)
                $labConfigFile = $labConfigFile.Replace("<<DomainName>>", $Using:domainName)
                $labConfigFile = $labConfigFile.Replace("<<azureLocalMachineMemory>>", $Using:azureLocalMachineMemory)
                $labConfigFile = $labConfigFile.Replace("<<WSServerIsoPath>>", $Using:wsISOLocalPath)
                $labConfigFile = $labConfigFile.Replace("<<MsuFolder>>", $Using:updatePath)
                $labConfigFile = $labConfigFile.Replace("<<VmPrefix>>", $Using:vmPrefix)
                $labConfigFile = $labConfigFile.Replace("<<TelemetryLevel>>", $Using:telemetryLevel)
                $labConfigFile = $labConfigFile.Replace("<<customDNSForwarders>>", $Using:customDNSForwarders)
                $labConfigFile = $labConfigFile.Replace("<<vSwitchName>>", $Using:vSwitchName)
                $labConfigFile = $labConfigFile.Replace("<<allowedVlans>>", $Using:allowedVlans)
                Out-File -FilePath "$Using:labConfigPath" -InputObject $labConfigFile -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Replace LabConfig"
        }

        Script "Download Windows Server ISO" {
            GetScript  = {
                $result = Test-Path -Path $Using:wsISOLocalPath
                return @{ 'Result' = $result }
            }
    
            SetScript  = {
                Start-BitsTransfer -Source $Using:wsIsoUri -Destination $Using:wsISOLocalPath   
            }
            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]WSISOpath"
        }

        Script "Download Azure Local ISO" {
            GetScript  = {
                $result = Test-Path -Path $Using:azLocalISOLocalPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Start-BitsTransfer -Source $Using:azureLocalIsoUri -Destination $Using:azLocalISOLocalPath            
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]azLocalIsoPath"
        }

        Script "Download CU" {
            GetScript  = {
                if ($Using:updateImages -eq "Yes") {
                    $result = ((Test-Path -Path "$Using:cuPath\*" -Include "*.msu") -or (Test-Path -Path "$Using:cuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$Using:cuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($Using:updateImages -eq "Yes") {
                    $cuSearchString = "Cumulative Update for Microsoft server operating system*version 23H2 for x64-based Systems"
                    $cuID = "Microsoft Server operating system-23H2"
                    Write-Host "Looking for updates that match: $cuSearchString and $cuID"
                    $cuUpdate = Get-MSCatalogUpdate -Search $cuSearchString -ErrorAction Stop | Where-Object Products -eq $cuID | Where-Object Title -like "*$($cuSearchString)*" | Select-Object -First 1
                    if ($cuUpdate) {
                        Write-Host "Found the latest update: $($cuUpdate.Title)"
                        Write-Host "Downloading..."
                        $cuUpdate | Save-MSCatalogUpdate -Destination $Using:cuPath -AcceptMultiFileUpdates
                    }
                    else {
                        Write-Host "No updates found, moving on..."
                        $NoCuFlag = "$Using:cuPath\NoUpdateDownloaded.txt"
                        New-Item $NoCuFlag -ItemType file -Force
                    }
                }
                else {
                    Write-Host "User selected to not update images with latest updates."
                    $NoCuFlag = "$Using:cuPath\NoUpdateDownloaded.txt"
                    New-Item $NoCuFlag -ItemType file -Force
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]CU"
        }

        Script "Download SSU" {
            GetScript  = {
                if ($Using:updateImages -eq "Yes") {
                    $result = ((Test-Path -Path "$Using:ssuPath\*" -Include "*.msu") -or (Test-Path -Path "$Using:ssuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$Using:ssuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($Using:updateImages -eq "Yes") {
                    $ssuSearchString = "Servicing Stack Update for Microsoft server operating system*version 23H2 for x64-based Systems"
                    $ssuID = "Microsoft Server operating system-23H2"
                    Write-Host "Looking for updates that match: $ssuSearchString and $ssuID"
                    $ssuUpdate = Get-MSCatalogUpdate -Search $ssuSearchString -ErrorAction Stop | Where-Object Products -eq $ssuID | Select-Object -First 1
                    if ($ssuUpdate) {
                        Write-Host "Found the latest update: $($ssuUpdate.Title)"
                        Write-Host "Downloading..."
                        $ssuUpdate | Save-MSCatalogUpdate -Destination $Using:ssuPath
                    }
                    else {
                        Write-Host "No updates found"
                        $NoSsuFlag = "$Using:ssuPath\NoUpdateDownloaded.txt"
                        New-Item $NoSsuFlag -ItemType file -Force
                    }
                }
                else {
                    Write-Host "User selected to not update images with latest updates."
                    $NoSsuFlag = "$Using:ssuPath\NoUpdateDownloaded.txt"
                    New-Item $NoSsuFlag -ItemType file -Force
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]SSU"
        }

        #### SET WINDOWS DEFENDER EXCLUSION FOR VM STORAGE ####

        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {

            Script defenderExclusions {
                SetScript  = {
                    $exclusionPath = "$Using:targetDrive" + ":\"
                    Add-MpPreference -ExclusionPath "$exclusionPath"               
                }
                TestScript = {
                    $exclusionPath = "$Using:targetDrive" + ":\"
                (Get-MpPreference).ExclusionPath -contains "$exclusionPath"
                }
                GetScript  = {
                    $exclusionPath = "$Using:targetDrive" + ":\"
                    @{Ensure = if ((Get-MpPreference).ExclusionPath -contains "$exclusionPath") { 'Present' } Else { 'Absent' } }
                }
                DependsOn  = "[File]JumpstartFolder"
            }

            #### REGISTRY & FIREWALL TWEAKS FOR AZURE VM ####

            Registry "Disable Internet Explorer ESC for Admin" {
                Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
                Ensure    = 'Present'
                ValueName = "IsInstalled"
                ValueData = "0"
                ValueType = "Dword"
            }
    
            Registry "Disable Internet Explorer ESC for User" {
                Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
                Ensure    = 'Present'
                ValueName = "IsInstalled"
                ValueData = "0"
                ValueType = "Dword"
            }
            
            Registry "Disable Server Manager WAC Prompt" {
                Key       = "HKLM:\SOFTWARE\Microsoft\ServerManager"
                Ensure    = 'Present'
                ValueName = "DoNotPopWACConsoleAtSMLaunch"
                ValueData = "1"
                ValueType = "Dword"
            }
    
            Registry "Disable Network Profile Prompt" {
                Key       = 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff'
                Ensure    = 'Present'
                ValueName = ''
            }

            if ($customRdpPort -ne "3389") {

                Registry "Set Custom RDP Port" {
                    Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
                    ValueName = "PortNumber"
                    ValueData = "$customRdpPort"
                    ValueType = 'Dword'
                }
            
                Firewall AddFirewallRule {
                    Name        = 'CustomRdpRule'
                    DisplayName = 'Custom Rule for RDP'
                    Ensure      = 'Present'
                    Enabled     = 'True'
                    Profile     = 'Any'
                    Direction   = 'Inbound'
                    LocalPort   = "$customRdpPort"
                    Protocol    = 'TCP'
                    Description = 'Firewall Rule for Custom RDP Port'
                }
            }
        }

        #### ENABLE & CONFIG HYPER-V ####

        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        if ($osInfo.ProductType -eq 3) {
            WindowsFeature "Hyper-V" {
                Name   = "Hyper-V"
                Ensure = "Present"
            }
    
            WindowsFeature "RSAT-Hyper-V-Tools" {
                Name      = "RSAT-Hyper-V-Tools"
                Ensure    = "Present"
                DependsOn = "[WindowsFeature]Hyper-V" 
            }
    
            VMHost "ConfigureHyper-V" {
                IsSingleInstance          = 'yes'
                EnableEnhancedSessionMode = $true
                DependsOn                 = "[WindowsFeature]Hyper-V"
            }
        }
        else {
            WindowsOptionalFeature "Hyper-V" {
                Name   = "Microsoft-Hyper-V-All"
                Ensure = "Enable"
            }
        }

        #### Start Azure Local VHDx Creation ####

        Script "CreateAzLocalDisk" {
            GetScript  = {
                $result = Test-Path -Path $Using:azLocalVhdPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                # Create Azure Local Host Image from ISO
                
                $scratchPath = "$Using:jumpstartPath\Scratch"
                New-Item -ItemType Directory -Path "$scratchPath" -Force | Out-Null
                
                # Determine if any SSUs are available
                $ssu = Test-Path -Path "$Using:ssuPath\*" -Include "*.msu"

                if ($ssu) {
                    Convert-WindowsImage -SourcePath $Using:azLocalISOLocalPath -SizeBytes 127GB -VHDPath $Using:azLocalVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -Package $Using:ssuPath -TempDirectory $Using:scratchPath -Verbose
                }
                else {
                    Convert-WindowsImage -SourcePath $Using:azLocalISOLocalPath -SizeBytes 127GB -VHDPath $Using:azLocalVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -TempDirectory $Using:scratchPath -Verbose
                }

                Start-Sleep -Seconds 10

                $mount = Mount-VHD -Path $Using:azLocalVhdPath -Passthru -ErrorAction Stop -Verbose
                Start-Sleep -Seconds 2

                $driveLetter = (Get-Disk -Number $mount.Number | Get-Partition | Where-Object Driveletter).DriveLetter
                $updatepath = "$($driveLetter):\"
                $updates = Get-ChildItem -path $Using:cuPath -Recurse | Where-Object { ($_.extension -eq ".msu") -or ($_.extension -eq ".cab") } | Select-Object fullname
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
                Dismount-VHD -path $Using:azLocalVhdPath -confirm:$false

                Start-Sleep -Seconds 5

                # Enable Hyper-V role on the Azure Local Host Image
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                if ($osInfo.ProductType -eq 3) {
                    Write-Host "Enabling the Hyper-V role..."
                    Install-WindowsFeature -Vhd $Using:azLocalVhdPath -Name Hyper-V
                }

                # Remove the scratch folder
                Remove-Item -Path "$scratchPath" -Recurse -Force | Out-Null
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[file]ParentDisks", "[Script]Download Azure Local ISO", "[Script]Download SSU", "[Script]Download CU"
        }

        # Start MSLab Deployment
        Script "MSLab Prereqs" {
            GetScript  = {
                $result = (Test-Path -Path "$Using:flagsPath\PreReqComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$Using:jumpstartPath"
                .\1_Prereq.ps1
                $preReqFlag = "$Using:flagsPath\PreReqComplete.txt"
                New-Item $preReqFlag -ItemType file -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Replace LabConfig", "[Script]CreateAzLocalDisk"
        }

        Script "MSLab CreateParentDisks" {
            GetScript  = {
                $result = (Test-Path -Path "$Using:flagsPath\CreateDisksComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$Using:jumpstartPath"
                .\2_CreateParentDisks.ps1
                $parentDiskFlag = "$Using:flagsPath\CreateDisksComplete.txt"
                New-Item $parentDiskFlag -ItemType file -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab Prereqs"
        }

        Script "MSLab DeployEnvironment" {
            GetScript  = {
                $result = (Test-Path -Path "$Using:flagsPath\DeployComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$Using:jumpstartPath"
                .\Deploy.ps1
                $deployFlag = "$Using:flagsPath\DeployComplete.txt"
                New-Item $deployFlag -ItemType file -Force
                Write-Host "Sleeping for 2 minutes to allow for VMs to join domain and reboot as required"
                Start-Sleep -Seconds 120
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab CreateParentDisks"
        }

        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {
            $azureUsername = $($Admincreds.UserName)
            $desktopPath = "C:\Users\$azureUsername\Desktop"
            $rdpConfigPath = "$jumpstartPath\$vmPrefix-DC.rdp"
        }
        else {
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $rdpConfigPath = "$desktopPath\$vmPrefix-DC.rdp"
        }

        Script "Download RDP File" {
            GetScript  = {
                $result = Test-Path -Path "$Using:rdpConfigPath"
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "$Using:rdpConfigUri" -OutFile "$Using:rdpConfigPath" -UseBasicParsing
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab DeployEnvironment"
        }

        Script "Edit RDP file" {
            GetScript  = {
                $result = ((Get-Item $Using:rdpConfigPath).LastWriteTime -ge (Get-Date))
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $vmIpAddress = (Get-VMNetworkAdapter -Name 'Internet' -VMName "$Using:vmPrefix-DC").IpAddresses | Where-Object { $_ -notmatch ':' }
                $rdpConfigFile = Get-Content -Path "$Using:rdpConfigPath"
                $rdpConfigFile = $rdpConfigFile.Replace("<<VM_IP_Address>>", $vmIpAddress)
                Out-File -FilePath "$Using:rdpConfigPath" -InputObject $rdpConfigFile -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Download RDP File"
        }

        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {

            Script "Create RDP RunOnce" {
                GetScript  = {
                    $result = [bool] (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name '!CopyRDPFile' -ErrorAction SilentlyContinue)
                    return @{ 'Result' = $result }
                }
    
                SetScript  = {
                    $command = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command `"Copy-Item -Path `'$Using:rdpConfigPath`' -Destination `'$Using:desktopPath`' -Force`""
                    Set-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name '!CopyRDPFile' `
                        -Value $command
                }

                TestScript = {
                    # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                    $state = [scriptblock]::Create($GetScript).Invoke()
                    return $state.Result
                }
                DependsOn  = "[Script]Edit RDP File"
            }
        }

        Script "Enable RDP on DC" {
            GetScript  = {
                $vmIpAddress = (Get-VMNetworkAdapter -Name 'Internet' -VMName "$Using:vmPrefix-DC").IpAddresses | Where-Object { $_ -notmatch ':' }
                if ((Test-NetConnection $vmIpAddress -CommonTCPPort rdp).TcpTestSucceeded -eq "True") {
                    $result = $true
                }
                else {
                    $result = $false
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
                    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
                    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
                    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Edit RDP File"
        }
        
        Script "Deploy WAC" {
            GetScript  = {
                Start-Sleep -Seconds 10
                $result = Invoke-Command -VMName "$Using:vmPrefix-WAC" -Credential $msLabCreds -ScriptBlock {
                    [bool] (Get-WmiObject -class win32_product  | Where-Object { $_.Name -eq "Windows Admin Center" })
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-Command -VMName "$Using:vmPrefix-WAC" -Credential $msLabCreds -ScriptBlock {
                    if (-not (Test-Path -Path "C:\WindowsAdminCenter.exe")) {
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri 'https://aka.ms/WACDownload' -OutFile "C:\WindowsAdminCenter.exe" -UseBasicParsing
                    }
                    # Download PSexec
                    if (-not (Test-Path -Path "C:\PStools.zip")) {
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/PSTools.zip' -OutFile "C:\PStools.zip" -UseBasicParsing
                        Expand-Archive -Path "C:\PStools.zip" -DestinationPath "C:\PStools" -Force
                    }

                    # Install WAC using PSexec
                    if (-not (Get-WmiObject -class win32_product  | Where-Object { $_.Name -eq "Windows Admin Center" })) {
                        Start-Process "C:\PStools\PsExec.exe" -ArgumentList "-accepteula -s -i -d C:\WindowsAdminCenter.exe /log=C:\WindowsAdminCenter.log /verysilent" -Wait
                    }

                    do {
                        # Check if WindowsAdminCenter service is present and if not, wait for 10 seconds and check again
                        while (-not (Get-Service WindowsAdminCenter -ErrorAction SilentlyContinue)) {
                            Write-Output "Windows Admin Center not yet installed. Checking again in 10 seconds."
                            Start-Sleep -Seconds 10
                        }
                        
                        if ((Get-Service WindowsAdminCenter -ErrorAction SilentlyContinue).status -ne "Running") {
                            Write-Output "Attempting to start Windows Admin Center (WindowsAdminCenter) Service - this may take a few minutes if the service has just been installed."
                            Start-Service WindowsAdminCenter -ErrorAction SilentlyContinue
                        }
                        Start-sleep -Seconds 5
                    } until ((Test-NetConnection -ErrorAction SilentlyContinue -ComputerName "localhost" -port 443).TcpTestSucceeded)
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Enable RDP on DC"
        }

        Script "Update DC" {
            GetScript  = {
                Start-Sleep -Seconds 10
                $result = Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
                    if (Get-ChildItem Cert:\LocalMachine\Root\ | Where-Object subject -like "CN=Windows Admin Center") {
                        return $true
                    }
                    else {
                        return $false
                    }
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $msLabCreds -ScriptBlock {
                    $GatewayServerName = "WAC"
                    Start-Sleep 10
                    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/media/hybridjumpstart.png' -OutFile "C:\Windows\Web\Wallpaper\Windows\hybridjumpstart.png" -UseBasicParsing
                    Set-GPPrefRegistryValue -Name "Default Domain Policy" -Context User -Action Replace -Key "HKCU\Control Panel\Desktop" -ValueName Wallpaper -Value "C:\Windows\Web\Wallpaper\Windows\hybridjumpstart.png" -Type String
                    $cert = Invoke-Command -ComputerName $GatewayServerName `
                        -ScriptBlock { Get-ChildItem Cert:\LocalMachine\My\ | Where-Object subject -eq "CN=WindowsAdminCenterSelfSigned" }
                    $cert | Export-Certificate -FilePath $env:TEMP\WACCert.cer
                    Import-Certificate -FilePath $env:TEMP\WACCert.cer -CertStoreLocation Cert:\LocalMachine\Root\
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Deploy WAC"
        }
    }
}