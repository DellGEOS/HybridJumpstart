# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; ServerISOFolder='<<WSServerIsoFolder>>'; ServerMSUsFolder='<<MsuFolder>>'; `
        DomainNetbiosName = 'Dell'; DefaultOUName="HybridJumpstart"; DomainName = "dell.hybrid"; Internet = $true ; TelemetryLevel='<<TelemetryLevel>>'; `
	AutoStartAfterDeploy=$true; VMs = @(); AutoClosePSWindows=$true; AutoCleanUp=$true; SwitchName = "HybridJumpstartSwitch"; Prefix = "<<VmPrefix>>-";
}

# Deploy domain-joined Azure Stack HCI Nodes
1..<<azsHostCount>> | ForEach-Object { 
    $VMNames = "AzSHCI" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
            ParentVHD = 'AzSHCI21H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
            MemoryStartupBytes = <azsHostMemory>>GB; MGMTNICs = 4 ; NestedVirt = $true ; VMProcessorCount = "Max"
    } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }
