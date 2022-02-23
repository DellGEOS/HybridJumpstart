configuration HybridHost
{
    param 
    ( 
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
        [Parameter(Mandatory)]
        [string]$customRdpPort,
        [string]$vSwitchNameHost = "InternalNAT",
        [String]$targetDrive = "V"
    )
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'xHyper-v'
    Import-DscResource -ModuleName 'cHyper-v'
    Import-DscResource -ModuleName 'StorageDSC'
    Import-DscResource -ModuleName 'NetworkingDSC'
    Import-DscResource -ModuleName 'cChoco'
    Import-DscResource -ModuleName 'DSCR_Shortcut'

    $ipConfig = (Get-NetAdapter -Physical | Where-Object Status -EQ Up | Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
    $netAdapters = Get-NetAdapter -Name ($ipConfig.InterfaceAlias) | Select-Object -First 1
    $InterfaceAlias = $($netAdapters.Name)

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
        }

        #### CREATE STORAGE SPACES V: & VM FOLDER ####

        Script StoragePool {
            SetScript  = {
                New-StoragePool -FriendlyName HybridHostPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
            }
            TestScript = {
                (Get-StoragePool -ErrorAction SilentlyContinue -FriendlyName HybridHostPool).OperationalStatus -eq 'OK'
            }
            GetScript  = {
                @{Ensure = if ((Get-StoragePool -FriendlyName HybridHostPool).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
            }
        }
        Script VirtualDisk {
            SetScript  = {
                $disks = Get-StoragePool -FriendlyName HybridHostPool -IsPrimordial $False | Get-PhysicalDisk
                $diskNum = $disks.Count
                New-VirtualDisk -StoragePoolFriendlyName HybridHostPool -FriendlyName HybridHostDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
            }
            TestScript = {
                (Get-VirtualDisk -ErrorAction SilentlyContinue -FriendlyName HybridHostDisk).OperationalStatus -eq 'OK'
            }
            GetScript  = {
                @{Ensure = if ((Get-VirtualDisk -FriendlyName HybridHostDisk).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
            }
            DependsOn  = "[Script]StoragePool"
        }
        Script FormatDisk {
            SetScript  = {
                $vDisk = Get-VirtualDisk -FriendlyName HybridHostDisk
                if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
                    $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel HybridHostData -AllocationUnitSize 64KB -FileSystem NTFS
                }
                elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
                    $vDisk | Get-Disk | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel HybridHostData -AllocationUnitSize 64KB -FileSystem NTFS
                }
            }
            TestScript = { 
                (Get-Volume -ErrorAction SilentlyContinue -FileSystemLabel HybridHostData).FileSystem -eq 'NTFS'
            }
            GetScript  = {
                @{Ensure = if ((Get-Volume -FileSystemLabel HybridHostData).FileSystem -eq 'NTFS') { 'Present' } Else { 'Absent' } }
            }
            DependsOn  = "[Script]VirtualDisk"
        }

        File "VMfolder" {
            Type            = 'Directory'
            DestinationPath = $targetVMPath
            DependsOn       = "[Script]FormatDisk"
        }

        #### SET WINDOWS DEFENDER EXCLUSION FOR VM STORAGE ####

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
            DependsOn  = "[Script]FormatDisk"
        }

        #### REGISTRY & SCHEDULED TASK TWEAKS ####

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

        ScheduledTask "Disable Server Manager at Startup" {
            TaskName = 'ServerManager'
            Enable   = $false
            TaskPath = '\Microsoft\Windows\Server Manager'
        }

        #### CUSTOM FIREWALL BASED ON ARM TEMPLATE ####

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

        #### ENABLE ROLES & FEATURES ####

        WindowsFeature "Enable Deduplication" { 
            Ensure = "Present" 
            Name   = "FS-Data-Deduplication"		
        }

        WindowsFeature "RSAT-Clustering" {
            Name   = "RSAT-Clustering"
            Ensure = "Present"
        }

        WindowsFeature "Hyper-V" {
            Name   = "Hyper-V"
            Ensure = "Present"
        }

        WindowsFeature "RSAT-Hyper-V-Tools" {
            Name      = "RSAT-Hyper-V-Tools"
            Ensure    = "Present"
            DependsOn = "[WindowsFeature]Hyper-V" 
        }

        #### HYPER-V vSWITCH CONFIG ####

        xVMHost "hpvHost"
        {
            IsSingleInstance          = 'yes'
            EnableEnhancedSessionMode = $true
            VirtualHardDiskPath       = $targetVMPath
            VirtualMachinePath        = $targetVMPath
            DependsOn                 = "[WindowsFeature]Hyper-V"
        }

        xVMSwitch "$vSwitchNameHost"
        {
            Name      = $vSwitchNameHost
            Type      = "Internal"
            DependsOn = "[WindowsFeature]Hyper-V"
        }

        IPAddress "New IP for vEthernet $vSwitchNameHost"
        {
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            AddressFamily  = 'IPv4'
            IPAddress      = '192.168.0.1/24'
            DependsOn      = "[xVMSwitch]$vSwitchNameHost"
        }

        NetIPInterface "Enable IP forwarding on vEthernet $vSwitchNameHost"
        {   
            AddressFamily  = 'IPv4'
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            Forwarding     = 'Enabled'
            DependsOn      = "[IPAddress]New IP for vEthernet $vSwitchNameHost"
        }

        NetAdapterRdma "EnableRDMAonvEthernet"
        {
            Name      = "vEthernet `($vSwitchNameHost`)"
            Enabled   = $true
            DependsOn = "[NetIPInterface]Enable IP forwarding on vEthernet $vSwitchNameHost"
        }

        NetConnectionProfile SetProfile
        {
            InterfaceAlias  = "$InterfaceAlias"
            NetworkCategory = 'Private'
        }

        #### PRIMARY NIC CONFIG ####

        NetAdapterBinding DisableIPv6Host
        {
            InterfaceAlias = "$InterfaceAlias"
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
        }

        #### CONFIGURE InternaNAT NIC

        script NAT {
            GetScript  = {
                $nat = "InternalNat"
                $result = if (Get-NetNat -Name $nat -ErrorAction SilentlyContinue) { $true } else { $false }
                return @{ 'Result' = $result }
            }
        
            SetScript  = {
                $nat = "InternalNat"
                New-NetNat -Name $nat -InternalIPInterfaceAddressPrefix "192.168.0.0/24"          
            }
        
            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = "[IPAddress]New IP for vEthernet $vSwitchNameHost"
        }

        NetAdapterBinding DisableIPv6NAT
        {
            InterfaceAlias = "vEthernet `($vSwitchNameHost`)"
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
            DependsOn      = "[Script]NAT"
        }

        #### INSTALL CHOCO, DEPLOY EDGE and Shortcuts

        cChocoInstaller InstallChoco {
            InstallDir = "c:\choco"
        }
            
        cChocoFeature allowGlobalConfirmation {
            FeatureName = "allowGlobalConfirmation"
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]installChoco'
        }
        
        cChocoFeature useRememberedArgumentsForUpgrades {
            FeatureName = "useRememberedArgumentsForUpgrades"
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]installChoco'
        }
        
        cChocoPackageInstaller "Install Chromium Edge" {
            Name        = 'microsoft-edge'
            Ensure      = 'Present'
            AutoUpgrade = $true
            DependsOn   = '[cChocoInstaller]installChoco'
        }

        script "SetRunFlag" {
            GetScript  = {
                $result = Test-Path -Path "C:\HybridHostAzureEval.txt"
                return @{ 'Result' = $result }
            }

            SetScript  = {
                #This is a simple flag to monitor number of runs
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                try { Invoke-WebRequest "http://bit.ly/HybridHostAzureEval" -UseBasicParsing -DisableKeepAlive | Out-Null } catch { $_.Exception.Response.StatusCode.Value__ }
                New-item -Path C:\ -Name "HybridHostAzureEval.txt" -ItemType File -Force
            }

            TestScript = {
                # Create and invoke a scriptblock using the $GetScript automatic variable, which contains a string representation of the GetScript.
                $state = [scriptblock]::Create($GetScript).Invoke()
                return $state.Result
            }
            DependsOn  = '[cChocoInstaller]installChoco'
        }
    }
}