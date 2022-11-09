param 
(
    [String]$azureStackHCINodes,
    [String]$azureStackHCINodeMemory,
    [String]$telemetryLevel,
    [String]$updateImages,
    [String]$jumpstartPath,
    [String]$AzureStackHCIIsoPath,
    [Switch]$skipWSisoDownload,
    [Switch]$skipAzSHCIisoDownload
)

$Global:VerbosePreference = "SilentlyContinue"
$Global:ProgressPreference = 'SilentlyContinue'
try { Stop-Transcript | Out-Null } catch { }

try {

    # Verify Running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    If (-not $isAdmin) {
        Write-Host "-- Restarting as Administrator" -ForegroundColor Yellow ; Start-Sleep -Seconds 1

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

    # Firstly, validate if Hyper-V is installed and prompt to enable and reboot if not
    Write-Host "Checking if required Hyper-V role/features are installed..."
    $hypervState = ((Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V*) | Where-Object { $_.State -eq "Disabled" })
    if ($hypervState) {
        Write-Host "`nThe following Hyper-V role/features are missing:`n"
        foreach ($feature in $hypervState) {
            "$($feature.DisplayName)"
        }
        Write-Host "`nDo you wish to enable them now?" -ForegroundColor Green
        if ((Read-Host "(Type Y or N)") -eq "Y") {
            Write-Host "`nYou chose to install the required Hyper-V role/features.`nYour machine will reboot once completed.`nRerun this script when back online..."
            Start-Sleep -Seconds 10
            $reboot = $false
            foreach ($feature in $hypervState) {
                $rebootCheck = Enable-WindowsOptionalFeature -Online -FeatureName $($feature.FeatureName) -ErrorAction Stop -NoRestart -WarningAction SilentlyContinue
                if ($($rebootCheck.RestartNeeded) -eq $true) {
                    $reboot = $true
                }
            }
            if ($reboot -eq $true) {
                Write-Host "`nInstall completed. A reboot is required to finish installation - reboot now?`nIf not, you will need to reboot before deploying the Hybrid Jumpstart..." -ForegroundColor Green
                if ((Read-Host "(Type Y or N)") -eq "Y") {
                    Start-Sleep -Seconds 5
                    Restart-Computer -Force
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
        Write-Host "`nAll required Hyper-V role/features are present. Continuing process..." -ForegroundColor Green
    }

    if (!($azureStackHCINodes)) {
        $AskForNodeCount = {
            $azureStackHCINodes = Read-Host "`nSelect the number of Azure Stack HCI nodes you'd like to deploy - Enter 1, 2, 3 or 4 (or Q to exit)..."
            switch ($azureStackHCINodes) {
                '1' { Write-Host "`nYou have chosen to deploy $azureStackHCINodes Azure Stack HCI nodes..." -ForegroundColor Green }
                '2' { Write-Host "`nYou have chosen to deploy $azureStackHCINodes Azure Stack HCI nodes..." -ForegroundColor Green }
                '3' { Write-Host "`nYou have chosen to deploy $azureStackHCINodes Azure Stack HCI nodes..." -ForegroundColor Green }
                '4' { Write-Host "`nYou have chosen to deploy $azureStackHCINodes Azure Stack HCI nodes..." -ForegroundColor Green }
                'Q' {
                    Write-Host 'Exiting...' -ForegroundColor Red
                    Start-Sleep -seconds 5
                    break 
                }
                default {
                    Write-Host "Invalid node count entered. Try again." -ForegroundColor Yellow
                    .$AskForNodeCount
                }
            }
        }
        .$AskForNodeCount
        if ($azureStackHCINodes -ne 'Q') {
            $azureStackHCINodes = [convert]::ToInt32($azureStackHCINodes)
        }
        else {
            break
        }
    }
    elseif ($azureStackHCINodes -notin ("1", "2", "3", "4")) {
        Write-Host "Incorrect number of Azure Stack HCI nodes specified.`nPlease re-run the script using with either 1, 2, 3 or 4 Azure Stack HCI nodes" -ForegroundColor Red
        break
    }
    elseif ($azureStackHCINodes -in ("1", "2", "3", "4")) {
        $azureStackHCINodes = [convert]::ToInt32($azureStackHCINodes)
    }

    if (!($azureStackHCINodeMemory)) {
        $AskForNodeMemory = {
            $azureStackHCINodeMemory = Read-Host "`nSelect the memory for each of your Azure Stack HCI nodes - Enter 4, 8, 12, 16, 24, 32, or 48 (or Q to exit)..."
            switch ($azureStackHCINodeMemory) {
                '4' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '8' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '12' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '16' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '24' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '32' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                '48' { Write-Host "`nYou have chosen $($azureStackHCINodeMemory)GB memory for each of your Azure Stack HCI nodes..." -ForegroundColor Green }
                'Q' {
                    Write-Host 'Exiting...' -ForegroundColor Red
                    Start-Sleep -seconds 5
                    break 
                }
                default {
                    Write-Host "Invalid memory amount entered. Try again." -ForegroundColor Yellow
                    .$AskForNodeMemory
                }
            }
        }
        .$AskForNodeMemory
        if ($azureStackHCINodeMemory -ne 'Q') {
            $azureStackHCINodeMemory = [convert]::ToInt32($azureStackHCINodeMemory)
        }
        else {
            break
        }
    }
    elseif ($azureStackHCINodeMemory -notin ("4", "8", "12", "16", "24", "32", "48")) {
        Write-Host "Incorrect amount of memory for your Azure Stack HCI nodes specified.`nPlease re-run the script using with either 4, 8, 12, 16, 24, 32, or 48" -ForegroundColor Red
        break
    }
    elseif ($azureStackHCINodeMemory -in ("4", "8", "12", "16", "24", "32", "48")) {
        $azureStackHCINodeMemory = [convert]::ToInt32($azureStackHCINodeMemory)
    }

    if (!($telemetryLevel)) {
        $AskForTelemetry = {
            $telemetryLevel = Read-Host "`nSelect the telemetry level for the deployment. This helps to improve the deployment experience.`nEnter Full, Basic or None (or Q to exit)..."
            switch ($telemetryLevel) {
                'Full' { Write-Host "`nYou have chosen a telemetry level of $telemetryLevel for the deployment..." -ForegroundColor Green }
                'Basic' { Write-Host "`nYou have chosen a telemetry level of $telemetryLevel for the deployment..." -ForegroundColor Green }
                'None' { Write-Host "`nYou have chosen a telemetry level of $telemetryLevel for the deployment..." -ForegroundColor Green }
                'Q' {
                    Write-Host 'Exiting...' -ForegroundColor Red
                    Start-Sleep -seconds 5
                    break 
                }
                default {
                    Write-Host "Invalid telemetry level entered. Try again." -ForegroundColor Yellow
                    .$AskForTelemetry
                }
            }
        }
        .$AskForTelemetry
    }
    elseif ($telemetryLevel -notin ("Full", "Basic", "None")) {
        Write-Host "Invalid -telemetryLevel entered.`nPlease re-run the script with either Full, Basic or None." -ForegroundColor Red
        break
    }
    elseif ($telemetryLevel -in ("Full", "Basic", "None")) {
        Write-Host "`nYou have chosen a telemetry level of $telemetryLevel for the deployment..." -ForegroundColor Green
    }

    if (!($updateImages)) {
        while ($updateInput -notin ("Y", "N", "Q")) {
            $updateInput = Read-Host "`nDo you wish to update your Azure Stack HCI and Windows Server images automatically?`nThis will increase deployment time. Enter Y or N (or Q to exit)..."
            if ($updateInput -eq "Y") {
                Write-Host "`nYou have chosen to update your images that are created during this process.`nThis will add additional time, but your images will have the latest patches." -ForegroundColor Green
                $updateImages = "Yes"
            }
            elseif ($updateInput -eq "N") {
                Write-Host "`nYou have chosen not to update your images - you can patch VMs once they've been deployed." -ForegroundColor Yellow
                $updateImages = "No"
            }
            elseif ($updateInput -eq "Q") {
                Write-Host 'Exiting...' -ForegroundColor Red
                Start-Sleep -Seconds 5
                break 
            }
            else {
                Write-Host "Invalid entry. Try again." -ForegroundColor Yellow
            }
        }
    }
    elseif ($updateImages -notin ("Y", "N")) {
        Write-Host "Invalid entry for -updateImages.`nPlease re-run the script with either Yes or No." -ForegroundColor Red
        break
    }
    elseif ($updateImages -eq "Yes") {
        Write-Host "`nYou have chosen to update your images that are created during this process.`nThis will add additional time, but your images will have the latest patches." -ForegroundColor Green
    }
    elseif ($updateImages -eq "No") {
        Write-Host "`nYou have chosen not to update your images - you can patch VMs once they've been deployed." -ForegroundColor Yellow
    }

    if (!($jumpstartPath)) {
        Write-Host "`nPlease select folder for deployment of the Hybrid Jumpstart lab infrastructure..."
        Start-Sleep -Seconds 5
        Add-Type -AssemblyName System.Windows.Forms
        $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
            RootFolder  = "MyComputer"
            Description = "Please select folder for deployment of the Hybrid Jumpstart lab infrastructure"
        }
        if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $jumpstartPath = $FolderBrowser.SelectedPath
            Write-Host "`nFolder selected is $jumpstartPath" -ForegroundColor Green
        }
        else {
            Write-Host "No valid path was selected. Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
    }

    if (!($skipWSisoDownload)) {
        if (!($WindowsServerIsoPath)) {
            Write-Host "`nHave you downloaded a Windows Server 2022 ISO? If not, one will be downloaded automatically for you"
            $wsIsoAvailable = Read-Host "Enter Y or N"
            if ($wsIsoAvailable -eq "Y") {
                Write-Host "`nPlease select a Windows Server 2022 ISO..."
                Start-Sleep -Seconds 3
                Add-Type -AssemblyName System.Windows.Forms
                #[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
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
                    Start-Sleep -Seconds 5
                    break
                }
            }
            else {
                Write-Host "`nNo Windows Server 2022 ISO has been provided. One will be downloaded for you during deployment." -ForegroundColor Green
            }
        }
    }

    if (!($skipAzSHCIisoDownload)) {
        if (!($AzureStackHCIIsoPath)) {
            Write-Host "`nHave you downloaded an Azure Stack HCI ISO? If not, one will be downloaded automatically for you"
            $AzSIsoAvailable = Read-Host "Enter Y or N"
            if ($AzSIsoAvailable -eq "Y") {
                Write-Host "`nPlease select latest Azure Stack HCI ISO..."
                Start-Sleep -Seconds 3
                Add-Type -AssemblyName System.Windows.Forms
                #[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
                $openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                    Title = "Please select latest Azure Stack HCI ISO..."
                }
                $openFile.Filter = "iso files (*.iso)|*.iso|All files (*.*)|*.*" 
                if ($openFile.ShowDialog() -eq "OK") {
                    Write-Host "File $($openfile.FileName) selected" -ForegroundColor Green
                    $AzureStackHCIIsoPath = $($openfile.FileName)
                } 
                if (!$openFile.FileName) {
                    Write-Host "`nNo valid ISO file was selected... Exiting" -ForegroundColor Red
                    Start-Sleep -Seconds 5
                    break
                }
            }
            else {
                Write-Host "`nNo Azure Stack HCI ISO has been provided. One will be downloaded for you during deployment." -ForegroundColor Green
            }
        }
    }

    # Download the Hybrid Jumpstart DSC files, and unzip them to C:\HybridJumpstartHost, then copy the PS modules to the main PS modules folder
    Write-Host "`nStarting Hybrid Jumpstart Deployment - please do not close this PowerShell window"
    Start-Sleep -Seconds 3
    Write-Host "`nDownloading the Hybrid Jumpstart lab files to C:\hybridjumpstart.zip..."
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

    Write-Host "`nStarting Hybrid Jumpstart deployment....Remote Desktop and VMConnect icons on your desktop will indicate completion..." -ForegroundColor Green

    ### START LOGGING ###
    $runTime = $(Get-Date).ToString("MMddyy-HHmmss")
    $fullLogPath = "$PSScriptRoot\JumpstartLog_$runTime.txt"
    Write-Host -Message "Log folder full path is $fullLogPath"
    Start-Transcript -Path "$fullLogPath" -Append
    $startTime = Get-Date -Format g
    $sw = [Diagnostics.Stopwatch]::StartNew()

    Set-DscLocalConfigurationManager  -Path . -Force
    Start-DscConfiguration -Path . -Wait -Force -Verbose
    Write-Host "`nDeployment complete....use the Remote Desktop or VMConnect icons to connect to your Domain Controller..." -ForegroundColor Green

    $endTime = Get-Date -Format g
    $sw.Stop()
    $Hrs = $sw.Elapsed.Hours
    $Mins = $sw.Elapsed.Minutes
    $Secs = $sw.Elapsed.Seconds
    $difference = '{0:00}h:{1:00}m:{2:00}s' -f $Hrs, $Mins, $Secs

    Write-Host "Hybrid Jumpstart deployment completed successfully, taking $difference." -ErrorAction SilentlyContinue
    Write-Host "You started the Hybrid Jumpstart deployment at $startTime." -ErrorAction SilentlyContinue
    Write-Host "Hybrid Jumpstart deployment completed at $endTime." -ErrorAction SilentlyContinue
}
catch {
    Set-Location $PSScriptRoot
    throw $_.Exception.Message
    Write-Host "Deployment failed - follow the troubleshooting steps online, and then retry"
    Read-Host | Out-Null
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}