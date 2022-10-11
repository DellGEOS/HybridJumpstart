param 
(
    [ValidateSet("1", "2", "3", "4")]
    [Int]$azureStackHCINodes,
    [ValidateSet("4", "8", "12", "16", "24", "32", "48")]
    [Int]$azureStackHCINodeMemory,
    [ValidateSet("Full", "Basic", "None")]
    [String]$telemetryLevel,
    [ValidateSet("Yes", "No")]
    [String]$updateImages,
    [String]$jumpstartPath,
    [String]$AzureStackHCIIsoPath,
    [Switch]$skipWSisoDownload,
    [Switch]$skipAzSHCIisoDownload
)

$Global:VerbosePreference = "SilentlyContinue"
$Global:ErrorActionPreference = 'Stop'
$Global:ProgressPreference = 'SilentlyContinue'

try {

    # Verify Running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    If (-not $isAdmin) {
        Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1

        if ($PSVersionTable.PSEdition -eq "Core") {
            Start-Process pwsh.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
        }
        else {
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
        }
        exit
    }

    if (Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq "Public" }) {
        Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq "Public" } | `
            Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
    }

           
    # Ensure WinRM is configured to allow DSC to run
    Write-Host "Checking PSRemoting to allow PowerShell DSC to run..."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "PSRemoting enabled..."
2
    # Firstly, validate if Hyper-V is installed and prompt to enable and reboot if not
    Write-Host "Checking if required Hyper-V role/features are installed..."
    $hypervState = ((Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V*) | Where-Object { $_.State -eq "Disabled" })
    if ($hypervState) {
        Write-Host "The following Hyper-V role/features are missing:"
        foreach ($feature in $hypervState) {
            "$($feature.DisplayName)"
        }
        Write-Host "Do you wish to enable them now?" -ForegroundColor Green
        if ((Read-Host "(Type Y or N)") -eq "Y") {
            Write-Host "You chose to install the required Hyper-V role/features.`nYour machine will reboot once completed.`nRerun this script when back online..."
            Start-Sleep -Seconds 10
            $reboot = $false
            foreach ($feature in $hypervState) {
                $rebootCheck = Enable-WindowsOptionalFeature -Online -FeatureName $($feature.FeatureName) -ErrorAction Stop -NoRestart -WarningAction SilentlyContinue
                if ($($rebootCheck.RestartNeeded) -eq $true) {
                    $reboot = $true
                }
            }
            if ($reboot -eq $true) {
                Write-Host "Install completed. A reboot is required to finish installation - reboot now?`nIf not, you will need to reboot before deploying the Hybrid Jumpstart..." -ForegroundColor Green
                if ((Read-Host "(Type Y or N)") -eq "Y") {
                    Restart-Computer -Force -Timeout 5
                }
                else {
                    Write-Host 'You did not enter "Y" to confirm rebooting your host. Exiting... ' -ForegroundColor Red
                    Break
                }
            }
            else {
                Write-Host "Install completed. No reboot is required at this time. Continuing process..." -ForegroundColor Green
            }
        }
        else {
            Write-Host 'You did not enter "Y" to confirm installing the required Hyper-V role/features. Exiting... ' -ForegroundColor Red
            Break
        }
    }
    else {
        Write-Host "All required Hyper-V role/features are present. Continuing process..." -ForegroundColor Green
    }

    if (!($azureStackHCINodes)) {
        while ($azureStackHCINodes -notin ("1", "2", "3", "4")) {
            $azureStackHCINodes = Read-Host "Select the number of Azure Stack HCI nodes you'd like to deploy - Enter 1, 2, 3 or 4"
        }
    }

    if (!($azureStackHCINodeMemory)) {
        while ($azureStackHCINodeMemory -notin ("4", "8", "12", "16", "24", "32", "48")) {
            $azureStackHCINodeMemory = Read-Host "Select the amount of memory in GB for each of your Azure Stack HCI nodes - Enter 4, 8, 12, 16, 24, 32, or 48"
        }
    }

    if (!($telemetryLevel)) {
        while ($telemetryLevel -notin ("Full", "Basic", "None")) {
            $telemetryLevel = Read-Host "Select the telemetry level for the deployment. This helps to improve the deployment experience - Enter Full, Basic or None"
        }
    }

    if (!($updateImages)) {
        while ($updateImages -notin ("Y", "N")) {
            $updateInput = Read-Host "Do you wish to update your Azure Stack HCI and Windows Server images automatically? This will increase deployment time. Enter Y or N"
            if ($updateInput -eq "Y") {
                $updateImages = "Yes"
            }
            else {
                $updateImages = "No"
            }
        }
    }

    if (!($jumpstartPath)) {
        Write-Host "Please select folder for deployment of the Hybrid Jumpstart lab infrastructure..."
        Add-Type -AssemblyName System.Windows.Forms
        $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
            RootFolder  = "MyComputer"
            Description = "Please select folder for deployment of the Hybrid Jumpstart lab infrastructure"
        }
        if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $jumpstartPath = $FolderBrowser.SelectedPath
            Write-Host "Folder selected is $jumpstartPath" -ForegroundColor Green
        }
        else {
            Write-Host "No valid path was selected. Exiting process..." -ForegroundColor Red
            exit
        }
    }

    if (!($skipWSisoDownload)) {
        if (!($WindowsServerIsoPath)) {
            Write-Host "Have you downloaded a Windows Server 2022 ISO? If not, one will be downloaded automatically for you"
            $wsIsoAvailable = Read-Host "Enter Y or N"
            if ($wsIsoAvailable -eq "Y") {
                Write-Host "Please select a Windows Server 2022 ISO..."
                [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
                $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                    Title = "Please select a Windows Server 2022 ISO..."
                }
                $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
                if ($openFile.ShowDialog() -eq "OK") {
                    Write-Host "File $($openfile.FileName) selected" -ForegroundColor Green
                    $WindowsServerIsoPath = $($openfile.FileName)
                } 
                if (!$openFile.FileName) {
                    Write-Host "No valid ISO file was selected... Exiting" -ForegroundColor Red
                    break
                }
            }
            else {
                Write-Host "No Windows Server 2022 ISO has been provided. One will be downloaded for you during deployment." -ForegroundColor Green
            }
        }
    }

    if (!($skipAzSHCIisoDownload)) {
        if (!($AzureStackHCIIsoPath)) {
            Write-Host "Have you downloaded an Azure Stack HCI ISO? If not, one will be downloaded automatically for you"
            $AzSIsoAvailable = Read-Host "Enter Y or N"
            if ($AzSIsoAvailable -eq "Y") {
                Write-Host "Please select latest Azure Stack HCI ISO..."
                [reflection.assembly]::loadwithpartialname("System.Windows.Forms")
                $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                    Title = "Please select latest Azure Stack HCI ISO..."
                }
                $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
                if ($openFile.ShowDialog() -eq "OK") {
                    Write-Host "File $($openfile.FileName) selected" -ForegroundColor Green
                    $AzureStackHCIIsoPath = $($openfile.FileName)
                } 
                if (!$openFile.FileName) {
                    Write-Host "No valid ISO file was selected... Exiting" -ForegroundColor Red
                    break
                }
            }
            else {
                Write-Host "No Azure Stack HCI ISO has been provided. One will be downloaded for you during deployment." -ForegroundColor Green
            }
        }
    }

    # Download the Hybrid Jumpstart DSC files, and unzip them to C:\HybridJumpstartHost, then copy the PS modules to the main PS modules folder
    Write-Host "Downloading the Hybrid Jumpstart lab files to C:\hybridjumpstart.zip..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://github.com/DellGEOS/HybridJumpstart/raw/main/dsc/HybridJumpstart.zip' `
        -OutFile 'C:\hybridjumpstart.zip' -UseBasicParsing -ErrorAction Stop

    # Expand the archive and copy modules to Program Files
    Write-Host "Unzipping Hybrid Jumpstart lab files to C:\HybridJumpstartSource..."
    Expand-Archive -Path C:\hybridjumpstart.zip -DestinationPath C:\HybridJumpstartSource -Force -ErrorAction Stop
    Write-Host "Moving PowerShell DSC modules to default Program Files location..."
    Get-ChildItem -Path C:\HybridJumpstartSource -Directory | Copy-Item -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force -ErrorAction Stop

    # Change your location
    Set-Location 'C:\HybridJumpstartSource'

    Write-Host "Loading the HybridJumpstart script and generating MOF files..."
    # Load the PowerShell file into memory
    . .\HybridJumpstart.ps1

    HybridJumpstart -jumpstartPath $jumpstartPath -azureStackHCINodes $azureStackHCINodes `
        -azureStackHCINodeMemory $azureStackHCINodeMemory -telemetryLevel $telemetryLevel -updateImages $updateImages `
        -WindowsServerIsoPath $WindowsServerIsoPath -AzureStackHCIIsoPath $AzureStackHCIIsoPath

    # Change location to where the MOFs are located, then execute the DSC configuration
    Set-Location .\HybridJumpstart\

    Write-Host "Starting Hybrid Jumpstart deployment....a VMconnect ICON on your desktop will indicate completion..." -ForegroundColor Green
    Set-DscLocalConfigurationManager  -Path . -Force
    Start-DscConfiguration -Path . -Wait -Force -Verbose
}
catch {
    Set-Location $PSScriptRoot
    throw $_.Exception.Message
    return
}