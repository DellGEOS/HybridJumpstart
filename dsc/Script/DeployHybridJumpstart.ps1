# Download the Hybrid Jumpstart DSC files, and unzip them to C:\HybridJumpstartHost, then copy the PS modules to the main PS modules folder
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/hybridhumpstart.zip' -OutFile 'C:\hybridjumpstart.zip' -UseBasicParsing
Expand-Archive -Path C:\hybridjumpstart.zip -DestinationPath C:\HybridJumpstartSource
Get-ChildItem -Path C:\HybridJumpstartSource -Directory | Copy-Item -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force

# Change your location
Set-Location 'C:\HybridJumpstartSource'
. .\HybridJumpstart.ps1

# Lock in the DSC and generate the MOF files
HybridJumpstart -azsHostCount 2 -azsHostMemory 16 -telemetryLevel Full -updateImages "Yes"

# Change location to where the MOFs are located, then execute the DSC configuration
Set-Location .\HybridJumpstart\

Set-DscLocalConfigurationManager  -Path . -Force
Start-DscConfiguration -Path . -Wait -Force -Verbose

# You may need to manually reboot and then wait to allow the DSC to complete.  Once complete, check by running:
Get-DscConfigurationStatus