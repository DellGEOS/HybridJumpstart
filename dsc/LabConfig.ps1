# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; ServerISOFolder='D:\ISOs\WS'; ServerMSUsFolder='D:\ISOs\WS'; `
        DomainNetbiosName = 'Dell'; DomainName = "Dell.hybrid"; Internet = $true ; TelemetryLevel='Full'; AutoStartAfterDeploy=$true; VMs = @(); `
	  AutoClosePSWindows=$true; AutoCleanUp=$true;
}

# Deploy domain-joined Azure Stack HCI Nodes
1..2 | ForEach-Object { 
    $VMNames = "AzSHCI" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
            ParentVHD = 'AzSHCI21H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
            MemoryStartupBytes = 24GB; MGMTNICs = 4 ; NestedVirt = $true ; VMProcessorCount = "Max"
    } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }