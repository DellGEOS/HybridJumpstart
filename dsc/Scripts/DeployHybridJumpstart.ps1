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

# Ensure WinRM is configured to allow DSC to run
Write-Host "Enabling WinRM to allow PowerShell DSC to run..."
winrm quickconfig -quiet

# Firstly, validate if Hyper-V is installed and prompt to enable and reboot if not
Write-Host "Checking if required Hyper-V role/features are installed"
$hypervState = ((Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V*) | Where-Object { $_.State -eq "Disabled" })
if ($hypervState) {
    Write-Host "The following Hyper-V role/features are missing:"
    foreach ($feature in $hypervState) {
        "$($feature.DisplayName)"
    }
    Write-Host "Do you wish to enable them now and restart?"
    if ((Read-Host "(Type Y or N)") -eq "Y") {
        Write-Host "You chose to install the required Hyper-V role/features. Your machine will reboot once completed. Rerun this script when back online..."
        Start-Sleep -Seconds 10
        $reboot = $false
        foreach ($feature in $hypervState) {
            $rebootCheck = Enable-WindowsOptionalFeature -Online -FeatureName $($feature.FeatureName) -ErrorAction Stop -NoRestart
            if ($($rebootCheck.RestartNeeded) -eq $true) {
                $reboot = $true
            }
        }
        if ($reboot -eq $true) {
            Write-Host "Install completed. A reboot is required to finish installation - reboot now? If not, you will need to reboot before deploying the Hybrid Jumpstart..."
            if ((Read-Host "(Type Y or N)") -eq "Y") {
                Restart-Computer -Force
            }
            else {
                Write-Host 'You did not enter "Y" to confirm rebooting your host. Exiting... '
                Break
            }
        }
        else {
            Write-Host "Install completed. No reboot is required at this time. Continuing process..."
        }
    }
    else {
        Write-Host 'You did not enter "Y" to confirm installing the required Hyper-V role/features. Exiting... '
        Break
    }
}

# Download the Hybrid Jumpstart DSC files, and unzip them to C:\HybridJumpstartHost, then copy the PS modules to the main PS modules folder
Write-Host "Downloading the HybridJumpstart Lab Files to C:\hybridjumpstart.zip..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/hybridjumpstart.zip' `
-OutFile 'C:\hybridjumpstart.zip' -UseBasicParsing -ErrorAction Stop

# Expand the archive and copy modules to Program Files
Write-Host "Unzipping HybridJumpstart Lab Files to C:\HybridJumpstartSource..."
Expand-Archive -Path C:\hybridjumpstart.zip -DestinationPath C:\HybridJumpstartSource -ErrorAction Stop
Write-Host "Moving PowerShell DSC modules to default Program Files location..."
Get-ChildItem -Path C:\HybridJumpstartSource -Directory | Copy-Item -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force -ErrorAction Stop

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