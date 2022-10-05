configuration HybridJumpstart
{
    param 
    (
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
    
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'hyperVDsc'
    Import-DscResource -ModuleName 'StorageDSC'
    Import-DscResource -ModuleName 'NetworkingDSC' -ModuleVersion 9.0.0
    Import-DscResource -ModuleName 'MSCatalog'
    Import-DscResource -ModuleName 'Hyper-ConvertImage'

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

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if (!$customRdpPort) {
            $customRdpPort = 3389
        }

        $dateStamp = Get-Date -Format "MMddyyyy"
        $vmPrefix = "HybridJumpstart-$dateStamp"

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
            $jumpstartPath = "$jumpstartPath" + ":\HybridJumpstart"
        }

        $mslabLocalPath = "$jumpstartPath\mslab.zip"
        $labConfigPath = "$jumpstartPath\LabConfig.ps1"
        $parentDiskPath = "$jumpstartPath\ParentDisks"
        $updatePath = "$parentDiskPath\Updates"
        $cuPath = "$updatePath\CU"
        $ssuPath = "$updatePath\SSU"
        $isoPath = "$jumpstartPath\ISO"
        $flagsPath = "$jumpstartPath\Flags"
        $azsHciVhdPath = "$parentDiskPath\AzSHCI21H2_G2.vhdx"
        $wsIsoPath = "$isoPath\WS"
        $azsHciIsoPath = "$isoPath\AzSHCI"

        if (!(Get-CimInstance win32_systemenclosure).SMBIOSAssetTag -eq "7783-7084-3265-9085-8269-3286-77") {
            # If this is on-prem, user should have supplied a folder/path they wish to install into
            # Users can also supply a pre-downloaded ISO for both WS and AzSHCI
            if ($null -eq $AzureStackHCIIsoPath) {
                $azsHCIISOLocalPath = "$azsHciIsoPath\AzSHCI.iso"
            }
            else {
                $azsHCIISOLocalPath = $AzureStackHCIIsoPath
            }
            if ($null -eq $WindowsServerIsoPath) {
                $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
            }
            else {
                $wsISOLocalPath = $WindowsServerIsoPath
            }
        }
        else {
            $azsHCIISOLocalPath = "$azsHciIsoPath\AzSHCI.iso"
            $wsISOLocalPath = "$wsIsoPath\WS2022.iso"
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
                $result = Test-Path -Path "$using:mslabLocalPath"
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-WebRequest -Uri "$using:mslabUri" -OutFile "$using:mslabLocalPath" -UseBasicParsing
                #Start-BitsTransfer -Source "$using:mslabUri" -Destination "$using:mslabLocalPath" -RetryInterval 60
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
                $result = !(Test-Path -Path "$using:mslabLocalPath")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Expand-Archive -Path "$using:mslabLocalPath" -DestinationPath "$using:jumpstartPath" -Force
                #$extractedFlag = "$using:flagsPath\MSLabExtracted.txt"
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
                $result = ((Get-Item $using:labConfigPath).LastWriteTime.Millisecond -ge (Get-Date).Millisecond)
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Invoke-WebRequest -Uri "$using:labConfigUri" -OutFile "$using:labConfigPath" -UseBasicParsing
                #Start-BitsTransfer -Source "$using:labConfigUri" -Destination "$using:labConfigPath" -RetryInterval 60
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
                $result = !(Test-Path -Path "$using:labConfigPath")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $labConfigFile = Get-Content -Path "$using:labConfigPath"
                $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodes>>", $using:azureStackHCINodes)
                $labConfigFile = $labConfigFile.Replace("<<azureStackHCINodeMemory>>", $using:azureStackHCINodeMemory)
                $labConfigFile = $labConfigFile.Replace("<<WSServerIsoFolder>>", $using:wsIsoPath)
                $labConfigFile = $labConfigFile.Replace("<<MsuFolder>>", $using:updatePath)
                $labConfigFile = $labConfigFile.Replace("<<VmPrefix>>", $using:vmPrefix)
                $labConfigFile = $labConfigFile.Replace("<<TelemetryLevel>>", $using:telemetryLevel)
                Out-File -FilePath "$using:labConfigPath" -InputObject $labConfigFile -Force
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
                $result = Test-Path -Path $using:wsISOLocalPath
                return @{ 'Result' = $result }
            }
    
            SetScript  = {
                Start-BitsTransfer -Source $using:wsIsoUri -Destination $using:wsISOLocalPath   
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
                $result = Test-Path -Path $using:azsHCIISOLocalPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Start-BitsTransfer -Source $using:azsHCIIsoUri -Destination $using:azsHCIISOLocalPath            
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
                    $result = ((Test-Path -Path "$using:cuPath\*" -Include "*.msu") -or (Test-Path -Path "$using:cuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$using:cuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($updateImages -eq "Yes") {
                    $cuSearchString = "Cumulative Update for Microsoft server operating system version 21H2 for x64-based Systems"
                    $cuID = "Microsoft Server operating system-21H2"
                    $cuUpdate = Get-MSCatalogUpdate -Search $cuSearchString | Where-Object Products -eq $cuID | Where-Object Title -like "*$($cuSearchString)*" | Select-Object -First 1
                    if ($cuUpdate) {
                        $cuUpdate | Save-MSCatalogUpdate -Destination $using:cuPath -AcceptMultiFileUpdates
                    }
                    else {
                        $NoCuFlag = "$using:cuPath\NoUpdateDownloaded.txt"
                        New-Item $NoCuFlag -ItemType file -Force
                    }
                }
                else {
                    $NoCuFlag = "$using:cuPath\NoUpdateDownloaded.txt"
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
                    $result = ((Test-Path -Path "$using:ssuPath\*" -Include "*.msu") -or (Test-Path -Path "$using:ssuPath\*" -Include "NoUpdateDownloaded.txt"))
                }
                else {
                    $result = (Test-Path -Path "$using:ssuPath\*" -Include "NoUpdateDownloaded.txt")
                }
                return @{ 'Result' = $result }
            }

            SetScript  = {
                if ($updateImages -eq "Yes") {
                    $ssuSearchString = "Servicing Stack Update for Microsoft server operating system version 21H2 for x64-based Systems"
                    $ssuID = "Microsoft Server operating system-21H2"
                    $ssuUpdate = Get-MSCatalogUpdate -Search $ssuSearchString | Where-Object Products -eq $ssuID | Select-Object -First 1
                    if ($ssuUpdate) {
                        $ssuUpdate | Save-MSCatalogUpdate -Destination $using:ssuPath
                    }
                    else {
                        $NoSsuFlag = "$using:ssuPath\NoUpdateDownloaded.txt"
                        New-Item $NoSsuFlag -ItemType file -Force
                    }
                }
                else {
                    $NoSsuFlag = "$using:ssuPath\NoUpdateDownloaded.txt"
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

        <#Script "Download SSU" {
            GetScript  = {
                $result = ((Test-Path -Path "$using:ssuPath\*" -Include "*.msu") -or (Test-Path -Path "$using:ssuPath\*" -Include "NoSSUAvailable.txt"))
                return @{ 'Result' = $result }
            }

            SetScript  = {
                $ssuSearchString = "Servicing Stack Update for Microsoft server operating system version 21H2 for x64-based Systems"
                $ssuID = "Microsoft Server operating system-21H2"
                $ssuUpdate = Get-MSCatalogUpdate -Search $ssuSearchString | Where-Object Products -eq $ssuID | Select-Object -First 1
                if ($ssuUpdate) {
                    $ssuUpdate | Save-MSCatalogUpdate -Destination $using:ssuPath
                }
                else {
                    $NoSSUFlag = "$using:ssuPath\NoSSUAvailable.txt"
                    New-Item $NoSSUFlag -ItemType file -Force
                }
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[File]SSU"
        } #>

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
                Ensure = "Present"
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
                $result = Test-Path -Path $using:azsHciVhdPath
                return @{ 'Result' = $result }
            }

            SetScript  = {
                # Create Azure Stack HCI Host Image from ISO
                
                $scratchPath = "$using:jumpstartPath\Scratch"
                New-Item -ItemType Directory -Path "$scratchPath" -Force | Out-Null
                
                # Determine if any SSUs are available
                $ssu = Test-Path -Path "$using:ssuPath\*" -Include "*.msu"

                if ($ssu) {
                    Convert-WindowsImage -SourcePath $using:azsHCIISOLocalPath -SizeBytes 60GB -VHDPath $using:azsHciVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -Package $using:ssuPath -TempDirectory $using:scratchPath -Verbose
                }
                else {
                    Convert-WindowsImage -SourcePath $using:azsHCIISOLocalPath -SizeBytes 60GB -VHDPath $using:azsHciVhdPath `
                        -VHDFormat VHDX -VHDType Dynamic -VHDPartitionStyle GPT -TempDirectory $using:scratchPath -Verbose
                }

                # Need to wait for disk to fully unmount
                While ((Get-Disk).Count -gt 2) {
                    Start-Sleep -Seconds 5
                }

                Start-Sleep -Seconds 5

                Mount-VHD -Path $using:azsHciVhdPath -Passthru -ErrorAction Stop -Verbose
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

                $updates = get-childitem -path $using:cuPath -Recurse | Where-Object { ($_.extension -eq ".msu") -or ($_.extension -eq ".cab") } | Select-Object fullname
                foreach ($update in $updates) {
                    write-debug $update.fullname
                    $command = "dism /image:" + $updatepath + " /add-package /packagepath:'" + $update.fullname + "'"
                    write-debug $command
                    Invoke-Expression $command
                }
            
                $command = "dism /image:" + $updatepath + " /Cleanup-Image /spsuperseded"
                Invoke-Expression $command

                Dismount-VHD -path $using:azsHciVhdPath -confirm:$false

                Start-Sleep -Seconds 5

                # Enable Hyper-V role on the Azure Stack HCI Host Image
                Install-WindowsFeature -Vhd $using:azsHciVhdPath -Name Hyper-V

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
                $result = (Test-Path -Path "$using:flagsPath\PreReqComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$using:jumpstartPath"
                .\1_Prereq.ps1
                $preReqFlag = "$using:flagsPath\PreReqComplete.txt"
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
                $result = (Test-Path -Path "$using:flagsPath\CreateDisksComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$using:jumpstartPath"
                .\2_CreateParentDisks.ps1
                $parentDiskFlag = "$using:flagsPath\CreateDisksComplete.txt"
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
                $result = (Test-Path -Path "$using:flagsPath\DeployComplete.txt")
                return @{ 'Result' = $result }
            }

            SetScript  = {
                Set-Location "$using:jumpstartPath"
                .\Deploy.ps1
                $deployFlag = "$using:flagsPath\DeployComplete.txt"
                New-Item $deployFlag -ItemType file -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[Script]MSLab CreateParentDisks"
        }
    }
}