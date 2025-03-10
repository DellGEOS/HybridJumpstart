# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; ServerISOFolder = '<<WSServerIsoPath>>'; `
                ServerMSUsFolder = '<<MsuFolder>>'; DomainNetbiosName = 'Dell'; DefaultOUName = "HybridJumpstart"; DomainName = "dell.hybrid"; `
                Internet = $true ; TelemetryLevel = '<<TelemetryLevel>>'; AutoStartAfterDeploy = $true; VMs = @(); AutoClosePSWindows = $true; `
                AutoCleanUp = $true; SwitchName = "vSwitch"; Prefix = "<<VmPrefix>>-"; AllowedVLANs="1-10,711-719"; `
                CustomDnsForwarders=@("<<customDNSForwarders>>"); AdditionalNetworksConfig=@()
}

# Deploy domain-joined Azure Local machines
1..<<azureLocalMachines>> | ForEach-Object { 
        $VMNames = "AzL" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
                        ParentVHD = 'AzL_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
                        MemoryStartupBytes = <<azureLocalMachineMemory>>GB; MGMTNICs = 2 ; vTPM=$true ; NestedVirt = $true ; VMProcessorCount = "Max"; Unattend="NoDjoin"
        } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs = 1 }

#Management machine
#$LabConfig.VMs += @{ VMName = 'MGMT' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }