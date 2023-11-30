### 1. Prepare Active Directory ###

# Capture AD Configuration Parameters
$AsHCIOUName = "OU=AzSClus1,DC=dell,DC=hybrid"
$Servers = "AzSHCI1", "AzSHCI2"
$DomainFQDN = $env:USERDNSDOMAIN
$ClusterName = "AzSClus1"
$Prefix = "AzSClus1"
$UserName = "AzSClus1-DeployUser"
$Password = "LS1setup!LS1setup!"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)

# Install required PowerShell Modules on Management Server
Install-PackageProvider -Name NuGet -Force
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force
Install-Module -Name Az.Accounts -Force
Install-Module -Name Az.Resources -Force

# Install Features on Management Server
Install-WindowsFeature -Name "RSAT-AD-PowerShell", "RSAT-ADDS", "GPMC", "RSAT-Clustering"

# Create a Microsoft Key Distribution Service root key on the DC to generate group MSA passwords
if (-not (Get-KdsRootKey)) {
    Add-KdsRootKey -EffectiveTime ((Get-Date).addhours(-10))
}

# Configure Active Directory
New-HciAdObjectsPreCreation -Deploy -AzureStackLCMUserCredential $Credentials `
    -AsHciOUName $AsHCIOUName -AsHciPhysicalNodeList $Servers -DomainFQDN $DomainFQDN `
    -AsHciClusterName $ClusterName -AsHciDeploymentPrefix $Prefix