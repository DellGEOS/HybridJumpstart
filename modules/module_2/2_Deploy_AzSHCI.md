Module 2 | Scenario 2 - Azure Stack HCI Cluster Prerequisites
============

Overview <!-- omit in toc -->
-----------
In this scenario, you'll double-check all your walk through deployment of an Azure Stack HCI cluster, using either **Windows Admin Center** or **PowerShell**.

Scenario duration <!-- omit in toc -->
-------------
45 Minutes

Contents <!-- omit in toc -->
-----------
- [Before you begin](#before-you-begin)
- [Architecture](#architecture)
- [Step 1 - Lab infrastructure deployment](#step-1---lab-infrastructure-deployment)
- [Step 2 - Installing Windows Admin Center](#step-2---installing-windows-admin-center)
- [Step 3 - Update Windows Admin Center Extensions](#step-3---update-windows-admin-center-extensions)
- [Next steps](#next-steps)
- [Raising issues](#raising-issues)

Before you begin
-----------
Before we deploy our Azure Stack HCI infrastructure, it's important to double check the **Infrastructure prerequisites** and the **Azure prerequisites** to ensure you'll be able to proceed through the deployment process.

### Infrastructure prerequisites <!-- omit in toc -->
You should have completed the **initial hybrid jumpstart deployment** either on a [**physical system**](/modules/module_0/4_physical_deployment.md), or inside an [**Azure virtual machine**](/modules/module_0/3_azure_vm_deployment.md).

### Azure prerequisites <!-- omit in toc -->
For connecting and integrating the Azure Stack HCI environment with Azure, you'll need to review the list below.

* **Get an Azure subscription** - if you don't have one, read [more information here](/modules/module_0/2_azure_prerequisites.md#get-an-azure-subscription)
* **Azure subscription permissions** - Owner **or** User Access Administrator + Contributer **or** Custom ([Instructions here](https://docs.microsoft.com/en-us/azure-stack/hci/deploy/register-with-azure#assign-permissions-from-azure-portal))
* **Firewall / Proxy** - If you are running the environment inside your own lab, ensure that your lab deployment has access to all external resources listed below:
  * [Host requirements](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements)
  * [Arc-enabled Servers requirements](https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#networking-configuration)

Architecture
-----------
As shown on the architecture graphic below, in this step, you'll deploy a set of Azure Stack HCI nodes, a Domain Controller and management server, and from there, you'll be **clustering the nodes into an Azure Stack HCI cluster**. You'll be focused on **creating a cluster in a single site**.

![Architecture diagram for Azure Stack HCI nested](/modules/module_0/media/nested_virt_physical.png "Architecture diagram for Azure Stack HCI nested")

Step 1 - Lab infrastructure deployment
--------
With the parent virtual hard disks previously created, you're now ready to begin deployment of the virtual machines that will host the jumpstart environment. As we saw earlier when looking at the [Lab Config](/modules/module_0/4_mslab.md/#exploring-the-labconfig-file), as part of this deployment, MSLab will deploy the following:

* 1 Windows Server 2022 Active Directory Domain Controller
* 4 Azure Stack HCI nodes each with 4GB Memory, and 12 x 4TB HDDs (these are dynamic, so won't consume 48TB :) )
* 1 Windows Server 2022 Management Server that will host Windows Admin Center 

All servers above will be automatically domain-joined, and the credentials specified in the LabConfig file will be used.

_______________________

**NOTE** - If you have a larger Hyper-V host, that has more memory available, you may wish to increase the memory allocated to each Azure Stack HCI node from 4GB. To do so, in your **HybridJumpstart** folder, open the **LabConfig** file, and adjust the **MemoryStartupBytes= 4GB;** to a larger value.
_______________________

1. In your **HybridJumpstart folder**, right-click **Deploy** and click **Run with PowerShell** to start the creation of your Azure Stack HCI nodes, and management server, along with the deployment of the pre-created domain controller. In the case of the domain controller, it will be imported, and a snapshot taken to preserve it's original state if you wish to clean up the environment later.
2. Upon running the **Deploy** script, you may be prompted to **change the execution policy** - enter **A** for **Yes to All** and **press enter**.
3. Choose your telemetry level for the lab and **press enter**. Deployment will begin.

![Jumpstart machines deployed](/modules/module_0/media/mslab_deploy_complete.png "Jumpstart machines deployed")

4. Once completed, you'll be promted to **start the lab virtual machines** - press **A** and **press enter**.
5. Once started, **press enter** to continue.
6. With the virtual machines deployed, on your Hyper-V host, open **Hyper-V Manager**.
7. Once open, you'll see your virtual machines up and running, ready to proceed on to the next step.

![Jumpstart machines running](/modules/module_0/media/mslab_vms_running.png "Jumpstart machines running")

8. Still in **Hyper-V Manager**, right-click on **HybridJumpstart-DC** and click **Connect**

![Connect to HybridJumpstart-DC](/modules/module_0/media/mslab_connect_dc.png "Connect to HybridJumpstart-DC")

9. In the **Connect to HybridJumpstart-DC** popup, use the **slider** to select your resolution and click **Connect**
10. When prompted, enter your **credentials** you provided in the **LabConfig** file. If you kept the default credentials, they will be:

    * **Username**: LabAdmin
    * **Password**: LS1setup!

11. Once logged into the Domain Controller VM, open **Server Manager**.
12. Once opened, right-click on **All Servers** and select **Add Servers**

![Add Servers in Server Manager](/modules/module_0/media/server_manager_add_servers.png "Add Servers in Server Manager")

13. In the **Add Servers** window, click **Find Now**, and you'll see all the domain-joined machines in the current jumpstart deployment. Select all the servers in the list, then click the **right arrow** to add them to the management view on this Domain Controller machine, then click **OK**.
14. In **Server Manager**, under **All Servers**, you should now see all the servers in the domain listed, and available for management from this interface.

Step 2 - Installing Windows Admin Center
--------
With the infrastructure deployed, the final step of this section is to install **Windows Admin Center**. If you're not familiar, Windows Admin Center is a locally-deployed, browser-based management toolset that lets you manage your Windows Servers with no Azure or cloud dependency. Windows Admin Center gives you full control over all aspects of your server infrastructure and is particularly useful for managing servers on private networks that are not connected to the Internet. It's also extremely useful in deploying and configuring Azure Stack HCI, and a number of other hybrid technologies, which you'll explore in this jumpstart.

In this section, you'll be installing Windows Admin Center onto the **HybridJumpstart-WACGW** virtual machine. If you recall, this virtual machine was deployed with the headless **Server Core** deployment of Windows Server 2022, and as a result, you'll install Windows Admin Center remotely onto the machine, from the Domain Controller.

1. If you're not already logged in, log into the **HybridJumpstart-DC** virtual machine, in the same way you did [earlier](#step-1---lab-infrastructure-deployment).
2. Once logged in, from the **Start Menu**, right-click **PowerShell**, select **More**, and then **Run as Administrator**

![Run PowerShell as Admin](/modules/module_0/media/powershell_as_admin.png "Run PowerShell as Admin")

3. To simplify deployment of Windows Admin Center remotely onto the **HybridJumpstart-WACGW** machine, copy and paste the following PowerShell code, into your elevated PowerShell console. This process should only take a few moments.

```powershell
# Define the target machine name to install Windows Admin Center
$GatewayServerName = "WACGW"

# Download Windows Admin Center if not present
if (-not (Test-Path -Path "$env:USERPROFILE\Downloads\WindowsAdminCenter.msi")) {
    Start-BitsTransfer -Source https://aka.ms/WACDownload -Destination "$env:USERPROFILE\Downloads\WindowsAdminCenter.msi"
}

# Create PS Session to WACGW and copy install files to remote server
Invoke-Command -ComputerName $GatewayServerName -ScriptBlock { Set-Item -Path WSMan:\localhost\MaxEnvelopeSizekb -Value 4096 }
$Session = New-PSSession -ComputerName $GatewayServerName
Copy-Item -Path "$env:USERPROFILE\Downloads\WindowsAdminCenter.msi" -Destination `
    "$env:USERPROFILE\Downloads\WindowsAdminCenter.msi" -ToSession $Session

#Install Windows Admin Center
Invoke-Command -Session $session -ScriptBlock {
    Start-Process msiexec.exe -Wait -ArgumentList `
        "/i $env:USERPROFILE\Downloads\WindowsAdminCenter.msi /qn /L*v log.txt REGISTRY_REDIRECT_PORT_80=1 SME_PORT=443 SSL_CERTIFICATE_OPTION=generate"
} -ErrorAction Ignore

$Session | Remove-PSSession

# Add Windows Admin Center Certificate to trusted root certs on Domain Controller
Start-Sleep 10
$cert = Invoke-Command -ComputerName $GatewayServerName `
    -ScriptBlock { Get-ChildItem Cert:\LocalMachine\My\ | Where-Object subject -eq "CN=Windows Admin Center" }
$cert | Export-Certificate -FilePath $env:TEMP\WACCert.cer
Import-Certificate -FilePath $env:TEMP\WACCert.cer -CertStoreLocation Cert:\LocalMachine\Root\
```

4. Once complete, you can **close** the PowerShell window.

![Windows Admin Center installation complete](/modules/module_0/media/wac_install_complete.png "Windows Admin Center installation complete")

5. You can validate the deployment by opening the **Edge browser** and navigating to https://wacgw. When asked for credentials, log in with your usual credentials, which by default, are:

    * **Username**: LabAdmin
    * **Password**: LS1setup!

![Logged into Windows Admin Center](/modules/module_0/media/wac_deployed.png "Logged into Windows Admin Center")

6. Finally, when Windows Admin Center is deployed in Gateway mode as we have done, it is very useful to configure Kerberos Constrained Delegation to reduce the need to supply credentials when connecting to remote servers - in this case, the Azure Stack HCI nodes. From the **Start Menu**, right-click **PowerShell**, select **More**, and then **Run as Administrator**
7. Copy and paste the following PowerShell code, into your elevated PowerShell console

```powershell
# Define the target machine name where Windows Admin Center is installed
$GatewayServerName = "WACGW"

# Configure Resource-based constrained delegation
$gatewayObject = Get-ADComputer -Identity $GatewayServerName
$computers = (Get-ADComputer -Filter { OperatingSystem -eq "Azure Stack HCI" }).Name

foreach ($computer in $computers) {
    $computerObject = Get-ADComputer -Identity $computer
    Set-ADComputer -Identity $computerObject -PrincipalsAllowedToDelegateToAccount $gatewayObject
}
```

8. Once complete, leave your PowerShell window open and move on to the next step.

Step 3 - Update Windows Admin Center Extensions
--------
When you install a fresh instance of Windows Admin Center, *typically*, all of the different extensions that Windows Admin Center uses to manage different elements of the infrastructure, are already up to date, and *should* update automatically, but that said, sometimes that doesn't happen, so running the script below can quickly and easily ensure that all of your installed extensions are up to date.

1. If you haven't already, open the **Edge browser** and navigate to https://wacgw. When asked for credentials, log in with your usual credentials, which by default, are:

    * **Username**: LabAdmin
    * **Password**: LS1setup!

2. In the top-right corner of the screen, click on the **Settings** icon (Gear).
3. On the left-hand side navigation, scroll down and click on **Extensions**
4. In the central pane, click on **Installed extensions** to view a list of all of the currently installed extensions.

![Windows Admin Center installed extensions](/modules/module_2/media/wac_extensions_updates.png "Windows Admin Center installed extensions")

5. You can either update each of the out-of-date extensions **manually** by clicking on an extension, then clicking **Update**, or you can use the PowerShell commands below to automate the updating of all extensions.

```powershell
# Define the target machine name where Windows Admin Center is installed
$GatewayServerName = "WACGW"

# Create new PSSession
$Session = New-PSSession -ComputerName $GatewayServerName

# Copy Windows Admin Center PowerShell Modules from WACGW Machine
Copy-Item -Path "C:\Program Files\Windows Admin Center\PowerShell\" `
    -Destination "C:\Program Files\Windows Admin Center\PowerShell\" `
    -Recurse -FromSession $Session

# Clean up PSSession
$Session | Remove-PSSession

# Import Windows Admin Center PowerShell Modules
$items = Get-ChildItem -Path "C:\Program Files\Windows Admin Center\PowerShell\Modules" -Recurse | `
    Where-Object Extension -eq ".psm1"
foreach ($item in $items) {
    Import-Module $item.fullName
}

# List all commands in the Windows Admin Center PowerShell Modules
Get-Command -Module ExtensionTools

# Grab installed extensions that are not up to date.
$InstalledExtensions = Get-Extension -GatewayEndpoint $GatewayServerName  | Where-Object status -eq Installed
$ExtensionsToUpdate = $InstalledExtensions | Where-Object IsLatestVersion -eq $False

# Update out-of-date extensions
foreach ($Extension in $ExtensionsToUpdate) {
    Update-Extension -GatewayEndpoint https://$GatewayServerName -ExtensionId $Extension.ID
}
```

6. Once complete, you can close the PowerShell window and the Edge browser - you are ready to create your Azure Stack HCI cluster.

Next steps
-----------
With your Azure Stack HCI nodes created and running, you can choose your preferred deployment approach for creating the Azure Stack HCI cluster, either with **Windows Admin Center** or **PowerShell**

* **Module 2 | Scenario 2a** - [Deploying Azure Stack HCI with Windows Admin Center](/modules/module_2/2a_Cluster_AzSHCI_WAC.md)
* **Module 2 | Scenario 2b** - [Deploying Azure Stack HCI with PowerShell](/modules/module_2/2b_Cluster_AzSHCI_PS.md)

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!