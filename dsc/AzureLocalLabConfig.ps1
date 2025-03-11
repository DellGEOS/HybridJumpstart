# Define core lab characteristics
$LabConfig = @{ DomainAdminName = '<<DomainAdminName>>'; AdminPassword = '<<AdminPassword>>'; DCEdition = '4'; ServerISOFolder = '<<WSServerIsoPath>>'; `
                ServerMSUsFolder = '<<MsuFolder>>'; DomainNetbiosName = '<<DomainNetBios>>'; DefaultOUName = "HybridJumpstart"; DomainName = '<<DomainName>>'; `
                Internet = $true ; TelemetryLevel = '<<TelemetryLevel>>'; AutoStartAfterDeploy = $true; VMs = @(); AutoClosePSWindows = $true; `
                AutoCleanUp = $true; SwitchName = "<<vSwitchName>>"; Prefix = "<<VmPrefix>>-"; AllowedVLANs="<<allowedVlans>>"; `
                CustomDnsForwarders=@("<<customDNSForwarders>>"); AdditionalNetworksConfig=@()
}

# Deploy Azure Local machines
1..<<azureLocalMachines>> | ForEach-Object { 
        $VMNames = "AzL" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
                        ParentVHD = 'AzL_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
                        MemoryStartupBytes = <<azureLocalMachineMemory>>GB; MGMTNICs = 2 ; vTPM=$true ; NestedVirt = $true ; VMProcessorCount = "Max"; Unattend="NoDjoin"
        } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WAC' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs = 1 }

#Management machine
#$LabConfig.VMs += @{ VMName = 'MGMT' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }