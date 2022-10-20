configuration HybridJumpstart
{
    param 
    (
        [System.Management.Automation.PSCredential]$Admincreds,
        [Parameter(Mandatory)]
        [ValidateSet("1", "2", "3", "4")]
        [Int]$azureStackHCINodes,
        [Parameter(Mandatory)]
        [ValidateSet("4", "8", "12", "16", "24", "32", "48")]
        [Int]$azureStackHCINodeMemory,
        [Parameter(Mandatory)]
        [ValidateSet("Full", "Basic", "None")]
        [String]$telemetryLevel,
        [ValidateSet("Yes", "No")]
        [String]$updateImages = "No",
        [String]$customRdpPort,
        [String]$jumpstartPath,
        [String]$WindowsServerIsoPath,
        [String]$AzureStackHCIIsoPath

    )
    
    Import-DscResource -ModuleName 'ComputerManagementDsc' -ModuleVersion 8.5.0
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'hyperVDsc' -ModuleVersion 4.0.0
    Import-DscResource -ModuleName 'StorageDSC' -ModuleVersion 5.0.1
    Import-DscResource -ModuleName 'NetworkingDSC' -ModuleVersion 9.0.0
    Import-DscResource -ModuleName 'MSCatalog' -ModuleVersion 0.28.0
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
        [String]$azsHCIIsoUri = "https://aka.ms/2CNBagfhSZ8BM7jyEV8I"
        [String]$labConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/LabConfig.ps1"
        [String]$rdpConfigUri = "https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/RDP.rdp"

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if (!$customRdpPort) {
            $customRdpPort = 3389
        }

        $dateStamp = Get-Date -Format "MMddyyyy"
        $vmPrefix = "HybridJumpstart-$dateStamp"

        $msLabUsername = "dell\labadmin"
        $msLabPassword = 'LS1setup!'
        $secMsLabPassword = New-Object -TypeName System.Security.SecureString
        $msLabPassword.ToCharArray() | ForEach-Object {$secMsLabPassword.AppendChar($_)}
        $msLabCreds = New-Object -typename System.Management.Automation.PSCredential -argumentlist $msLabUsername, $secMsLabPassword

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

        # Define parameters
        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {
            # If this in Azure, lock things in specifically
            $targetDrive = "V"
            $jumpstartPath = "$targetDrive" + ":\HybridJumpstart"
        }
        else {
            $jumpstartPath = "$jumpstartPath" + "\HybridJumpstart"
        }

        $mslabLocalPath = "$jumpstartPath\mslab.zip"
        $labConfigPath = "$jumpstartPath\LabConfig.ps1"
        $parentDiskPath = "$jumpstartPath\ParentDisks"
        $updatePath = "$parentDiskPath\Updates"
        $cuPath = "$updatePath\CU"
        $ssuPath = "$updatePath\SSU"
        $isoPath = "$jumpstartPath\ISO"
        $flagsPath = "$jumpstartPath\Flags"
        $azsHciVhdPath = "$parentDiskPath\AzSHCI22H2_G2.vhdx"

        if (!((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77")) {
            # If this is on-prem, user should have supplied a folder/path they wish to install into
            # Users can also supply a pre-downloaded ISO for both WS and AzSHCI
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
        }
        else {
            $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
            $azsHCIISOLocalPath = "$azsHciIsoPath\AzSHCI.iso"
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
                        $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel HybridJumpstart -AllocationUnitSize 64KB -FileSystem NTFS
                    }
                    elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
                        $vDisk | Get-Disk | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel HybridJumpstart -AllocationUnitSize 64KB -FileSystem NTFS
                    }
                }
                TestScript = { 
                (Get-Volume -ErrorAction SilentlyContinue -FileSystemLabel HybridJumpstart).FileSystem -eq 'NTFS'
                }
                GetScript  = {
                    @{Ensure = if ((Get-Volume -FileSystemLabel HybridJumpstart).FileSystem -eq 'NTFS') { 'Present' } Else { 'Absent' } }
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

        File "azsHciISOpath" {
            DestinationPath = $azsHciIsoPath
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
                Invoke-WebRequest -Uri "$Using:mslabUri" -OutFile "$Using:mslabLocalPath" -UseBasicParsing
                #Start-BitsTransfer -Source "$Using:mslabUri" -Destination "$Using:mslabLocalPath" -RetryInterval 60
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
                Invoke-WebRequest -Uri "$Using:labConfigUri" -OutFile "$Using:labConfigPath" -UseBasicParsing
                #Start-BitsTransfer -Source "$Using:labConfigUri" -Destination "$Using:labConfigPath" -RetryInterval 60
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
                $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodes>>", $Using:azureStackHCINodes)
                $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodeMemory>>", $Using:azureStackHCINodeMemory)
                $labConfigFile = $labConfigFile.Replace("<<WSServerIsoFolder>>", $Using:wsIsoPath)
                $labConfigFile = $labConfigFile.Replace("<<MsuFolder>>", $Using:updatePath)
                $labConfigFile = $labConfigFile.Replace("<<VmPrefix>>", $Using:vmPrefix)
                $labConfigFile = $labConfigFile.Replace("<<TelemetryLevel>>", $Using:telemetryLevel)
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

        Script "Download AzureStack HCI ISO" {
            GetScript  = {
                $result = Test-Path -Path $Using:azsHCIISOLocalPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Start-BitsTransfer -Source $Using:azsHCIIsoUri -Destination $Using:azsHCIISOLocalPath            
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]azsHciISOpath"
        }

        Script "Download CU" {
            GetScript  = {
                if ($updateImages -eq "Yes") {
                    $result = ((Test-Path -Path "$Using:cuPath\*" -Include "*.msu") -or (Test-Path -Path "$Using:cuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$Using:cuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($updateImages -eq "Yes") {
                    $cuSearchString = "Cumulative Update for Microsoft server operating system*version 22H2 for x64-based Systems"
                    $cuID = "Microsoft Server operating system-22H2"
                    $cuUpdate = Get-MSCatalogUpdate -Search $cuSearchString | Where-Object Products -eq $cuID | Where-Object Title -like "*$($cuSearchString)*" | Select-Object -First 1
                    if ($cuUpdate) {
                        $cuUpdate | Save-MSCatalogUpdate -Destination $Using:cuPath -AcceptMultiFileUpdates
                    }
                    else {
                        $NoCuFlag = "$Using:cuPath\NoUpdateDownloaded.txt"
                        New-Item $NoCuFlag -ItemType file -Force
                    }
                }
                else {
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
                if ($updateImages -eq "Yes") {
                    $result = ((Test-Path -Path "$Using:ssuPath\*" -Include "*.msu") -or (Test-Path -Path "$Using:ssuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$Using:ssuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($updateImages -eq "Yes") {
                    $ssuSearchString = "Servicing Stack Update for Microsoft server operating system*version 22H2 for x64-based Systems"
                    $ssuID = "Microsoft Server operating system-22H2"
                    $ssuUpdate = Get-MSCatalogUpdate -Search $ssuSearchString | Where-Object Products -eq $ssuID | Select-Object -First 1
                    if ($ssuUpdate) {
                        $ssuUpdate | Save-MSCatalogUpdate -Destination $Using:ssuPath
                    }
                    else {
                        $NoSsuFlag = "$Using:ssuPath\NoUpdateDownloaded.txt"
                        New-Item $NoSsuFlag -ItemType file -Force
                    }
                }
                else {
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

            <#
            Script "EnableHyperVWinClient" {
                GetScript  = {
                    $result = ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).state -eq "Enabled")
                    return @{ 'Result' = $result }
                }
    
                SetScript  = {
                    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
                }
    
                TestScript = {
                    # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                    $state = [scriptblock]::Create($GetScript).Invoke()
                    return $state.Result
                }
            } #>
        }

        #### Start AzSHCI VHDx Creation ####

        Script "CreateAzSHCIDisk" {
            GetScript  = {
                $result = Test-Path -Path $Using:azsHciVhdPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                # Create Azure Stack HCI Host Image from ISO
                
                $scratchPath = "$Using:jumpstartPath\Scratch"
                New-Item -ItemType Directory -Path "$scratchPath" -Force | Out-Null
                
                # Determine if any SSUs are available
                $ssu = Test-Path -Path "$Using:ssuPath\*" -Include "*.msu"

                if ($ssu) {
                    Convert-WindowsImage -SourcePath $Using:azsHCIISOLocalPath -SizeBytes 60GB -VHDPath $Using:azsHciVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -Package $Using:ssuPath -TempDirectory $Using:scratchPath -Verbose
                }
                else {
                    Convert-WindowsImage -SourcePath $Using:azsHCIISOLocalPath -SizeBytes 60GB -VHDPath $Using:azsHciVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -TempDirectory $Using:scratchPath -Verbose
                }

                Start-Sleep -Seconds 10

                Mount-VHD -Path $Using:azsHciVhdPath -Passthru -ErrorAction Stop -Verbose
                Start-Sleep -Seconds 2

                $disks = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object Caption -eq "Microsoft Virtual Disk"            
                foreach ($disk in $disks) {            
                    $vols = Get-CimAssociatedInstance -CimInstance $disk -ResultClassName Win32_DiskPartition             
                    foreach ($vol in $vols) {            
                        $updatedrive = Get-CimAssociatedInstance -CimInstance $vol -ResultClassName Win32_LogicalDisk |            
                        Where-Object VolumeName -ne 'System Reserved'
                    }            
                }
                $updatepath = $updatedrive.DeviceID + "\"

                $updates = get-childitem -path $Using:cuPath -Recurse | Where-Object { ($_.extension -eq ".msu") -or ($_.extension -eq ".cab") } | Select-Object fullname
                foreach ($update in $updates) {
                    write-debug $update.fullname
                    $command = "dism /image:" + $updatepath + " /add-package /packagepath:'" + $update.fullname + "'"
                    write-debug $command
                    Invoke-Expression $command
                }
            
                $command = "dism /image:" + $updatepath + " /Cleanup-Image /spsuperseded"
                Invoke-Expression $command

                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                if ($osInfo.ProductType -eq 1) {
                    $command = "dism /image:" + $updatepath + " /enable-Feature:Microsoft-Hyper-V"
                    Invoke-Expression $command
                }

                Dismount-VHD -path $Using:azsHciVhdPath -confirm:$false

                Start-Sleep -Seconds 5

                # Enable Hyper-V role on the Azure Stack HCI Host Image
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
                if ($osInfo.ProductType -eq 3) {
                    Install-WindowsFeature -Vhd $Using:azsHciVhdPath -Name Hyper-V
                }

                # Remove the scratch folder
                Remove-Item -Path "$scratchPath" -Recurse -Force | Out-Null
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[file]ParentDisks", "[Script]Download AzureStack HCI ISO", "[Script]Download SSU", "[Script]Download CU"
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
            DependsOn  = "[Script]Replace LabConfig", "[Script]CreateAzSHCIDisk"
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
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab CreateParentDisks"
        }

        if ((Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {
            $azureUsername = $($Using:Admincreds.UserName)
            $desktopPath = "C:\Users\$azureUsername\Desktop"
        }
        else {
            $desktopPath = [Environment]::GetFolderPath("Desktop")
        }

        Script "Create DC Shortcut" {
            GetScript  = {
                $result = (Test-Path -Path "$Using:desktopPath\$Using:vmPrefix-DC.lnk")
                return @{ 'Result' = $result }
            }
            SetScript  = {
                $VMname = "$Using:vmPrefix-DC"
                $WshShell2 = New-Object -comObject WScript.Shell
                $Shortcut = $WshShell2.CreateShortcut("$Using:desktopPath\$VMname.lnk")
                $Shortcut.TargetPath = "C:\Windows\System32\vmconnect.exe"
                $Shortcut.Arguments = "localhost $VMname"
                $Shortcut.WorkingDirectory = "C:\WINDOWS\system32"
                $Shortcut.IconLocation = "vmconnect.exe, 0";
                $Shortcut.Save()
                $bytes = [System.IO.File]::ReadAllBytes("$Using:desktopPath\$VMname.lnk")
                $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
                [System.IO.File]::WriteAllBytes("$Using:desktopPath\$VMname.lnk", $bytes)
            }
            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab DeployEnvironment"
        }

        $rdpConfigPath = "$desktopPath\$vmPrefix-DC.rdp"

        Script "Download RDP File" {
            GetScript  = {
                $result = Test-Path -Path "$Using:rdpConfigPath"
                return @{ 'Result' = $result }
            }

            SetScript  = {
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
                Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $Using:msLabCreds -ScriptBlock {
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
                $result = Invoke-Command -VMName "$Using:vmPrefix-WACGW" -Credential $Using:msLabCreds -ScriptBlock {
                    [bool] (Get-WmiObject -class win32_product  | Where-Object { $_.Name -eq "Windows Admin Center" })
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-Command -VMName "$Using:vmPrefix-WACGW" -Credential $Using:msLabCreds -ScriptBlock {
                    if (-not (Test-Path -Path "C:\WindowsAdminCenter.msi")) {
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

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab DeployEnvironment"
        }

        Script "Update DC" {
            GetScript  = {
                $result = Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $Using:msLabCreds -ScriptBlock {
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
                Invoke-Command -VMName "$Using:vmPrefix-DC" -Credential $Using:msLabCreds -ScriptBlock {
                    $GatewayServerName = "WACGW"
                    Start-Sleep 10
                    $cert = Invoke-Command -ComputerName $GatewayServerName `
                        -ScriptBlock { Get-ChildItem Cert:\LocalMachine\My\ | Where-Object subject -eq "CN=Windows Admin Center" }
                    $cert | Export-Certificate -FilePath $env:TEMP\WACCert.cer
                    Import-Certificate -FilePath $env:TEMP\WACCert.cer -CertStoreLocation Cert:\LocalMachine\Root\
                    $gatewayObject = Get-ADComputer -Identity $GatewayServerName
                    $computers = (Get-ADComputer -Filter { OperatingSystem -eq "Azure Stack HCI" }).Name
                    foreach ($computer in $computers) {
                        $computerObject = Get-ADComputer -Identity $computer
                        Set-ADComputer -Identity $computerObject -PrincipalsAllowedToDelegateToAccount $gatewayObject
                    }
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Deploy WAC"
        }

        Script "Update WAC Extensions" {
            GetScript  = {
                $result = Invoke-Command -VMName "$Using:vmPrefix-WACGW" -Credential $Using:msLabCreds -ScriptBlock {
                    [bool] (Test-Path -Path "C:\WACExtensionsUpdated.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-Command -VMName "$Using:vmPrefix-WACGW" -Credential $Using:msLabCreds -ScriptBlock {
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

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]Update DC"
        }
    }
}