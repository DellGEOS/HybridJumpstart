### 2. Prepare AzSHCI Nodes ###

# Log in to Azure from Management Server
if (-not (Get-AzContext)) {
    Connect-AzAccount -UseDeviceAuthentication
}

# Choose correct Azure Subscription
$subscriptions = Get-AzSubscription
if (($subscriptions).count -gt 1) {
    $SubscriptionID = ($Subscriptions | Out-GridView -OutputMode Single -Title "Please Select Subscription").ID
    $Subscriptions | Where-Object ID -eq $SubscriptionID | Select-AzSubscription
}
else {
    $SubscriptionID = $subscriptions.id
}

# Configure AzSHCI Node Configuration Parameters
$Servers = "AzSHCI1", "AzSHCI2"
$ResourceGroupName = "AzSClus1-RG"
$TenantID = (Get-AzContext).Tenant.ID
$SubscriptionID = (Get-AzContext).Subscription.ID
$Location = "eastus"
$Cloud = "AzureCloud"
$UserName = "Administrator"
$Password = "LS1setup!"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)

# Configure Trusted Hosts to be able to communicate with servers (not secure)
$TrustedHosts = @()
$TrustedHosts += $Servers
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $($TrustedHosts -join ',') -Force

# Change Local Admin password to be at least 12 chars
Invoke-Command -ComputerName $servers -ScriptBlock {
    Set-LocalUser -Name Administrator -AccountNeverExpires -Password (ConvertTo-SecureString "LS1setup!LS1setup!" -AsPlainText -Force)
} -Credential $Credentials

# Update password
$password = "LS1setup!LS1setup!"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $SecuredPassword)

# Remotely install AzSHCI Node Features and Latest Updates
Invoke-Command -ComputerName $servers -ScriptBlock {
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -NoRestart
    Install-WindowsFeature -Name Failover-Clustering
} -Credential $Credentials

# Update Servers
Invoke-Command -ComputerName $servers -ScriptBlock {
    New-PSSessionConfigurationFile -RunAsVirtualAccount -Path $env:TEMP\VirtualAccount.pssc
    Register-PSSessionConfiguration -Name 'VirtualAccount' -Path $env:TEMP\VirtualAccount.pssc -Force
} -ErrorAction Ignore -Credential $Credentials

# Inject Sleep Pause
Start-Sleep 2

# Run Windows Update via ComObject.
Invoke-Command -ComputerName $servers -ConfigurationName 'VirtualAccount' -ScriptBlock {
    $Searcher = New-Object -ComObject Microsoft.Update.Searcher
    $SearchCriteriaAllUpdates = "IsInstalled=0 and DeploymentAction='Installation' or
                                IsInstalled=0 and DeploymentAction='OptionalInstallation' or
                                IsPresent=1 and DeploymentAction='Uninstallation' or
                                IsInstalled=1 and DeploymentAction='Installation' and RebootRequired=1 or
                                IsInstalled=0 and DeploymentAction='Uninstallation' and RebootRequired=1"
    $SearchResult = $Searcher.Search($SearchCriteriaAllUpdates).Updates
    if ($SearchResult.Count -gt 0) {
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $SearchResult
        $Downloader.Download()
        $Installer = New-Object -ComObject Microsoft.Update.Installer
        $Installer.Updates = $SearchResult
        $Result = $Installer.Install()
        $Result
    }
} -Credential $Credentials

# Clean Up Temp PSsession
Invoke-Command -ComputerName $servers -ScriptBlock {
    Unregister-PSSessionConfiguration -Name 'VirtualAccount'
    Remove-Item -Path $env:TEMP\VirtualAccount.pssc
}  -Credential $Credentials

# Reboot Nodes
Restart-Computer -ComputerName $Servers -Credential $Credentials -WsmanAuthentication Negotiate -Wait -For PowerShell

# Inject a pause to allow for full reboot
Start-Sleep 20 

# Check for AzSHCI nodes fully restarted
Foreach ($Server in $Servers) {
    do { $Test = Test-NetConnection -ComputerName $Server -CommonTCPPort WINRM }while ($test.TcpTestSucceeded -eq $False)
}

# Install Nuget
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
} -Credential $Credentials

# Install AzsHCI.ArcInstaller module on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name AzsHCI.ArcInstaller -Force
} -Credential $Credentials

# Install Az.Accounts module  on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name Az.Accounts -Force
} -Credential $Credentials

# Install Az.Resources module on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module Az.Resources -Force
} -Credential $Credentials

# Ensure nodes only have a single NIC with a Default Gateway
Invoke-Command -ComputerName $servers -ScriptBlock {
    Get-NetIPConfiguration | Where-Object IPV4defaultGateway | Get-NetAdapter | Sort-Object Name `
    | Select-Object -Skip 1 | Set-NetIPInterface -Dhcp Disabled
    ipconfig /registerdns
} -Credential $Credentials

# Deploy the Arc Agent and Configuration on all nodes
$ARMtoken = (Get-AzAccessToken).Token
$id = (Get-AzContext).Account.Id
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Invoke-AzStackHciArcInitialization -SubscriptionID $using:SubscriptionID `
        -ResourceGroup $using:ResourceGroupName -TenantID $using:TenantID -Cloud $using:Cloud `
        -Region $Using:Location -ArmAccessToken $using:ARMtoken -AccountID $using:id
} -Credential $Credentials