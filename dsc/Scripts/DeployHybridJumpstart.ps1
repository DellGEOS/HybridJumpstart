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
    [Parameter(Mandatory)]
    [String]$jumpstartPath,
    [String]$WindowsServerIsoPath,
    [String]$AzureStackHCIIsoPath
)

# Download the Hybrid Jumpstart DSC files, and unzip them to C:\HybridJumpstartHost, then copy the PS modules to the main PS modules folder
Write-Host "Downloading the HybridJumpstart Lab Files to C:\hybridjumpstart.zip..."
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/hybridhumpstart.zip' `
-OutFile 'C:\hybridjumpstart.zip' `-UseBasicParsing

# Expand the archive and copy modules to Program Files
Write-Host "Unzipping HybridJumpstart Lab Files to C:\HybridJumpstartSource..."
Expand-Archive -Path C:\hybridjumpstart.zip -DestinationPath C:\HybridJumpstartSource
Write-Host "Moving PowerShell DSC modules to default Program Files location..."
Get-ChildItem -Path C:\HybridJumpstartSource -Directory | Copy-Item -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force

# Change your location
Set-Location 'C:\HybridJumpstartSource'

Write-Host "Loading the HybridJumpstart script and generating MOF files..."
# Load the PowerShell file into memory
.\HybridJumpstart.ps1
# Lock in the DSC and generate the MOF files
HybridJumpstart -jumpstartPath $jumpstartPath -azureStackHCINodes $azureStackHCINodes -azureStackHCINodeMemory $azureStackHCINodeMemory -telemetryLevel $telemetryLevel -updateImages $updateImages

# Change location to where the MOFs are located, then execute the DSC configuration
Set-Location .\HybridJumpstart\

Write-Host "Starting Hybrid Jumpstart deployment - this will trigger a reboot if the Hyper-V role isn't already enabled..."
Set-DscLocalConfigurationManager  -Path . -Force
Start-DscConfiguration -Path . -Wait -Force -Verbose