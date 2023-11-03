# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; ServerISOFolder = '<<WSServerIsoPath>>'; `
                ServerMSUsFolder = '<<MsuFolder>>'; DomainNetbiosName = 'SnoValleyCoffee'; DefaultOUName = "SnoValleyCoffee"; DomainName = "snovalleycoffee.com"; `
                Internet = $true ; TelemetryLevel = '<<TelemetryLevel>>'; AutoStartAfterDeploy = $true; VMs = @(); AutoClosePSWindows = $true; `
                AutoCleanUp = $true; SwitchName = "vSwitch"; Prefix = "<<VmPrefix>>-"; AllowedVLANs="1-10,711-719"; `
                CustomDnsForwarders=@("<<customDNSForwarders>>"); AdditionalNetworksConfig=@()
}

# Deploy domain-joined Azure Stack HCI Nodes
1..<<azureStackHCINodes>> | ForEach-Object { 
        $VMNames = "Duvall-N" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
                        ParentVHD = 'AzSHCI22H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
                        MemoryStartupBytes = <<azureStackHCINodeMemory>>GB; MGMTNICs = 4 ; vTPM=$true ; NestedVirt = $true ; VMProcessorCount = "Max"; Unattend="NoDjoin"
        } 
}

1..<<azureStackHCINodes>> | ForEach-Object { 
        $VMNames = "Carnation-N" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
                        ParentVHD = 'AzSHCI22H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
                        MemoryStartupBytes = <<azureStackHCINodeMemory>>GB; MGMTNICs = 4 ; vTPM=$true ; NestedVirt = $true ; VMProcessorCount = "Max"; Unattend="NoDjoin"
        } 
}

1..<<azureStackHCINodes>> | ForEach-Object { 
        $VMNames = "Snoqualmie-N" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
                        ParentVHD = 'AzSHCI22H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
                        MemoryStartupBytes = <<azureStackHCINodeMemory>>GB; MGMTNICs = 4 ; vTPM=$true ; NestedVirt = $true ; VMProcessorCount = "Max"; Unattend="NoDjoin"
        } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs = 1 }

#Management machine
$LabConfig.VMs += @{ VMName = 'Management' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }