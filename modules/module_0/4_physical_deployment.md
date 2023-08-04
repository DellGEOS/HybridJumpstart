Hybrid Jumpstart | Deployment on physical hardware
==============

Overview <!-- omit in toc -->
-----------
If you have suitable hardware ([as discussed earlier](/modules/module_0/1_infra_prerequisites.md)), rather than deploy in Azure, you can instead deploy the Hybrid Jumpstart on your own physical system. This could be a physical server, workstation or a laptop, or, it could also be an appropriately sized virtual machine running on an an existing virtualization platform, such as Hyper-V or VMware vSphere.

_____________________
**NOTE** - If you do choose to deploy the environment inside a virtual machine on an existing virtualization platform, ensure that the VM you create is large enough, and supports nested virtualization.
_____________________

Section duration <!-- omit in toc -->
-------------
60 Minutes

Contents <!-- omit in toc -->
--------

- [Hybrid Jumpstart | Deployment on physical hardware](#hybrid-jumpstart--deployment-on-physical-hardware)
  - [Download the DeployHybridJumpstart.ps1 script](#download-the-deployhybridjumpstartps1-script)
    - [Exploring the DeployHybridJumpstart.ps1 script](#exploring-the-deployhybridjumpstartps1-script)
  - [Option 1 - Automated deployment with parameters](#option-1---automated-deployment-with-parameters)
      - [Deployment with automatic ISO downloads and default external DNS forwarders](#deployment-with-automatic-iso-downloads-and-default-external-dns-forwarders)
      - [Deployment with user-provided ISOs and custom external DNS forwarders](#deployment-with-user-provided-isos-and-custom-external-dns-forwarders)
  - [Option 2 - Semi-automated deployment with manual inputs](#option-2---semi-automated-deployment-with-manual-inputs)
  - [Exploring the environment](#exploring-the-environment)
  - [Next steps](#next-steps)
  - [Troubleshooting](#troubleshooting)
  - [Raising issues](#raising-issues)

Download the DeployHybridJumpstart.ps1 script
--------
In order to streamline the deployment of the hybrid jumpstart on your existing Windows Server or Windows Client machine, download the DeployHybridJumpstart.ps1 script with the following PowerShell commands. Please note, to run the script, you will need to relax your PowerShell execution policy to allow remote scripts to run on the system.

1. Open a PowerShell console **as administrator** and copy/paste the code below:

```powershell
# Update PowerShell Execution Policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Create directory on the desktop.
$desktopPath = "$([Environment]::GetFolderPath("Desktop"))\HybridJumpstart"
New-Item -ItemType Directory -Force -Path $desktopPath
Set-Location $desktopPath

# Download the AzSPoC Script.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-Webrequest https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/dsc/Scripts/DeployHybridJumpstart.ps1 `
    -UseBasicParsing -OutFile DeployHybridJumpstart.ps1
```

2. You should now have the DeployHybridJumpstart.ps1 in a folder on your desktop. Once run, the script will generate a log file that will also appear in this folder, which can help with troubleshooting, should something go wrong.

### Exploring the DeployHybridJumpstart.ps1 script

The script will perform the following tasks:
* Enable PSRemoting to ensure PowerShell DSC can execute correctly
* Enable Hyper-V and accompanying management tools, along with rebooting the machine
* Download all necessary software binaries for deployment
* Automate deployment of MSLab, which in turn, will deploy a Windows Server 2022 Domain Controller, management server and Azure Stack HCI nodes

On a new machine, the script will need to be run at least twice - the first time, it will enable Hyper-V and supporting roles, then reboot. After the reboot, you will rerun the script with the same parameters to deploy the hybrid jumpstart.

The script accepts a number of parameters to customize deployment of the hybrid jumpstart:

- **-azureStackHCINodes** - this is the number of Azure Stack HCI nodes you'd like to run on this system. Enter a number between 1 and 4.
- **-azureStackHCINodeMemory** - this is the amount of memory per Azure Stack HCI node you'd like to allocate. Enter 4, 8, 12, 16, 24, 32 or 48.
- **-updateImages** - choose this if you'd like to automatically update your Azure Stack HCI and Windows Server 2022 images with the latest cumulative update. Please note, this will increase the runtime of the script considerably.
- **-jumpstartPath** - this is the folder on your local system where all the hybrid jumpstart virtual machines and lab files will reside.
- **-AutoDownloadWSiso** - this switch will instruct the script to download a Windows Server 2022 evaluation ISO automatically for you.
- **-AutoDownloadAzSHCIiso** - this switch will instruct the script to download the Azure Stack HCI 22H2 ISO automatically for you.
- **-WindowsServerIsoPath** - if you have already downloaded the Windows Server 2022 iso, provide the full path.
- **-AzureStackHCIIsoPath** - if you have already downloaded the Azure Stack HCI 22H2 iso, provide the full path.
- **-dnsForwarders** - if you wish to use a custom external DNS forwarder(s), use the format "9.9.9.9". If you wish to use multiple DNS forwarders, enter them separated by a comma (,) and with no spaces: "9.9.9.9,149.112.112.112". Alternatively, enter the parameter "Default" and the deployment will use 8.8.8.8 and 1.1.1.1.
- **-telemetryLevel** - this sets the telemetry level for the MSLab automated deployment. Options are Full, Basic and None. You can [read more about MSLab telemetry on GitHub](https://github.com/microsoft/MSLab/blob/master/Docs/mslab-telemetry.md).

There are 2 options for deployment:

* **Option 1** - Automated deployment with parameters
* **Option 2** - Semi-automated deployment with manual inputs

Both options will be covered below.

Option 1 - Automated deployment with parameters
--------
The simplest, and fastest way to run the DeployHybridJumpstart.ps1 script, is to provide all the necessary parameters up front.

1. Still in your **PowerShell console as administrator** from earlier, run the following commands (adjust for your environment):

#### Deployment with automatic ISO downloads and default external DNS forwarders

```powershell
.\DeployHybridJumpstart.ps1 -azureStackHCINodes 2 -azureStackHCINodeMemory 16 -updateImages "No" `
    -jumpstartPath "D:\HybridJumpstart" -AutoDownloadWSiso -AutoDownloadAzSHCIiso `
    -dnsForwarders "Default" -telemetryLevel "Full"
```

#### Deployment with user-provided ISOs and custom external DNS forwarders

```powershell
.\DeployHybridJumpstart.ps1 -azureStackHCINodes 2 -azureStackHCINodeMemory 16 -updateImages "No" `
    -jumpstartPath "D:\HybridJumpstart" -WindowsServerIsoPath "D:\WS\WS2022.iso" `
    -AzureStackHCIIsoPath "D:\AzSHCI\AzSHCI22H2.iso" -dnsForwarders "208.67.222.222" -telemetryLevel "Full"
```

The script will begin to execute. If the Hyper-V role and accompanying management tools are not installed, you will be prompted to install and enable those:

![Deployment started - enabling Hyper-V](/modules/module_0/media/deploy_hybrid_jumpstart_enable_hyperv.png "Deployment started - enabling Hyper-V")

2. When prompted, enter **Y** to continue. Once the install has completed, enter **Y** again to reboot your machine.

3. Once your machine is back online, reopen your **PowerShell console as administrator** and navigate to your desktop folder by running the following PowerShell commands:

```powershell
$desktopPath = "$([Environment]::GetFolderPath("Desktop"))\HybridJumpstart"
Set-Location $desktopPath
```

4. Press the **Up** key on your keyboard to cycle through the previously run PowerShell commands, until you find your deployment command from earlier. Alternatively, copy and paste the same commands from above.

5. Once you have the command in place, press **Enter** to execute the command and start the deployment process. This should take around **50-60 minutes**, depending on your download speed (to download the ISO files, if you didn't provide them) and the speed/performance of your physical system.

![Deployment started - Running PowerShell DSC](/modules/module_0/media/deploy_hybrid_jumpstart_started.png "Deployment started - Running PowerShell DSC")

6. After around 60 minutes, the deployment should have completed successfully, and you should see a new **remote desktop icon** on your desktop. As you can see, in this case, the deployment took around 51 minutes, of which downloading the ISO files took 12 minutes.

![Deployment complete](/modules/module_0/media/deploy_hybrid_jumpstart_complete.png "Deployment complete")

7. When you're ready, **close the PowerShell window**. If you run into issues, or the PowerShell DSC deployment doesn't complete successfully, please refer to the [troubleshooting steps below](#troubleshooting).

Option 2 - Semi-automated deployment with manual inputs
--------
If you prefer to step through the deployment in a slightly more manual approach, this option is for you.

1. From your desktop, navigate into the **HybridJumpstart folder**, then right-click the **DeployHybridJumpstart.ps1** file that you downloaded earlier, and select **Run with PowerShell**

![Initiate manual deployment](/modules/module_0/media/deploy_hybrid_jumpstart_run.png "Initiate manual deployment")

2. A PowerShell console will open and **prompt you to run as administrator**. Click **Yes** to continue.
3. The script will begin to execute. If the Hyper-V role and accompanying management tools are not installed, you will be prompted to install and enable those:

![Deployment started - enabling Hyper-V](/modules/module_0/media/deploy_hybrid_jumpstart_enable_hyperv_manual.png "Deployment started - enabling Hyper-V")

4. When prompted, enter **Y** to continue. Once the install has completed, enter **Y** again to reboot your machine.

5. Once back online, from your desktop, navigate back into the **HybridJumpstart folder**, right-click the **DeployHybridJumpstart.ps1** file, and select **Run with PowerShell**.
6. Accept the **Run as administrator** prompt by selecting **Yes**.

You'll then be asked to work through a number of questions to customize your deployment.

7. For the **Select the number of Azure Stack HCI nodes you'd like to deploy**, enter 1, 2, 3 or 4 (or Q to exit).
8. For the **Select the memory for each of your Azure Stack HCI nodes**, enter 4, 8, 12, 16, 24, 32, or 48 (or Q to exit).
9. For the **Select the telemetry level for the deployment**, enter Full, Basic or None (or Q to exit).
10. For the **Do you wish to update your Azure Stack HCI and Windows Server images automatically**, enter Y or N (or Q to exit). Note, this will increase deployment time considerably.
11. You'll then be prompted to select a location to store your Hybrid Jumpstart files and virtual machines. **Navigate to a folder of your choice**, and **click OK**. You also have the option to create a new folder to store these artifacts.

![Deployment started - select a folder](/modules/module_0/media/deploy_hybrid_jumpstart_manual_folder.png "Deployment started - select a folder")

11. For the **Have you downloaded a Windows Server 2022 ISO**, enter Y or N. If you choose N, a Windows Server 2022 ISO will be automatically downloaded for you. If you choose Y, you'll be prompted to navigate to the ISO using File Explorer.
12. For the **Have you downloaded an Azure Stack HCI 22H2 ISO**, enter Y or N. If you choose N, a Windows Server 2022 ISO will be automatically downloaded for you. If you choose Y, you'll be prompted to navigate to the ISO using File Explorer.
13. For the **Would you like to use custom external DNS forwarders?**, either enter the custom external DNS forwarder address in the format 9.9.9.9 (or for multiple addresses, separated by a comma (,) and with no spaces: 9.9.9.9,149.112.112.112). Alternatively, you can simply press enter to skip, and the deployment will use 8.8.8.8 and 1.1.1.1.

With the questions complete, the deployment will begin. **Leave the PowerShell window open** as the PowerShell DSC executes. The process should take between 40-60 minutes depending on your selections.

![Deployment started - Running PowerShell DSC](/modules/module_0/media/deploy_hybrid_jumpstart_manual_started.png "Deployment started - Running PowerShell DSC")

13.  After around 40-60 minutes, once completed, you'll see the results in the PowerShell window. In addition, you can also review the successful completion by navigating to the **HybridJumpstart folder** on the desktop, and **opening the log file in Notepad**. As you can see below, in our case, deployment took 37 minutes, when using existing ISO's.

![Deployment complete](/modules/module_0/media/deploy_hybrid_jumpstart_manual_complete.png "Deployment complete")

14. When you're ready, **close the PowerShell window**. If you run into issues, or the PowerShell DSC deployment doesn't complete successfully, please refer to the [troubleshooting steps below](#troubleshooting).

Exploring the environment
--------
With the deployment completed, it's worthwhile taking a few minutes to explore what's been deployed.

1. From your start menu, search for **Hyper-V** and open **Hyper-V Manager**.
2. Once opened, you should see your virtual machines running on your physical system.

![List of Hyper-V virtual machines](/modules/module_0/media/hyperv_vm_list.png "List of Hyper-V virtual machines")

3. As you can see, all VMs have been named with a prefix to match the HybridJumpstart, then the date of the deployment, along with the specific VM name.
4. In in the list of VMs, there's a **single Active Directory Domain Controller** (DC), and a **dedicated management server** on which Windows Admin Center has been deployed (WACGW). You can also see your **nested Azure Stack HCI nodes** (AzSHCI1, AzSHCI2 etc).
5. The domain controller provides core Active Directory services, in addition to DHCP, DNS and Routing and Remote Access services, to ensure the other virtual machines traverse through the DC to access external networks.
6. On the right-hand side of Hyper-V Manager, click on **Virtual Switch Manager**.

![Hyper-V Virtual Switches](/modules/module_0/media/vswitches.png "Hyper-V Virtual Switches")

7. Here, you'll see the **Default Switch**, which allows the VMs to access external endpoints, for example, to reach the internet. You'll also see a **HybridJumpstart-\<date>-vSwitch** which is a Private vSwitch. Private vSwitches are isolated from the physical host, and just allow VM to VM communication. In this case, all the VMs that were deployed are attached to this specific vSwitch, and can communicate with each other privately. If they need to access the internet, the traffic first reaches the Domain Controller, which, using the Routing and Remote Access capabilities, handles the NAT outbound and inbound traffic.
8. In the **Virtual Switch Manager** window, click **close**.

Next steps
-----------
Now that you've completed the necessary prerequisites and deployed the sandbox environment, you're ready to create and deploy your first Azure Stack HCI cluster. However, before doing so, it's recommended that you spend some time familiarizing yourself with the [**hybrid landscape in module 1**](/modules/module_1/1_hybrid_landscape.md).


Troubleshooting
-----------
From time to time, a transient, random deployment error may cause the PowerShell DSC process to fail. If that's the case, you can follow these steps to begin troubleshooting.

1. On your physical machine, open a **PowerShell console as administrator** and run the following command to confirm the status of the last run:

```powershell
# Check for last run
Get-DscConfigurationStatus
```

**NOTE** - if you receive an error message similar to *"Get-DscConfigurationStatus : Cannot invoke the Get-DscConfigurationStatus cmdlet. The `<Some DSC Process`> cmdlet is in progress and must return before Get-DscConfigurationStatus can be invoked"* you will need to **wait** until the current DSC process has completed. Once completed, you should be able to successfully run the command.

2. When you run **Get-DscConfigurationStatus**, if you get a status of **Failure** you can re-run the DSC configuration by **running the following commands**:

```powershell
cd "C:\HybridJumpstartSource\HybridJumpstart"
Set-DscLocalConfigurationManager  -Path . -Force
Start-DscConfiguration -Path . -Wait -Force -Verbose -ErrorAction 'Stop'
```

3. Depending on where the initial failure happened, your VM may reboot and you will be disconnected. If that's the case, log back into the VM and wait for deployment to complete. See #1 above to check progress. Generally speaking, once you see the **HybridJumpstart Remote Desktop** icon on your desktop, the process has completed.

4. If all goes well, you should see the DSC configuration reapplied without issues. If you then re-run the following PowerShell command, you should see success, with a number of resources deployed/configured.

```powershell
# Check for last run
Get-DscConfigurationStatus
```

![Result of Get-DscConfigurationStatus](/modules/module_0/media/get-dscconfigurationstatus.png "Result of Get-DscConfigurationStatus")

**NOTE** - If this doesn't fix your issue, consider redeploying your environment by navigating to your -jumpstartPath folder (in the examples above, we used D:\HybridJumpstart), right-clicking **Cleanup**, then **Run with PowerShell**, and accepting the prompts. Once cleaned up, repeat the deployment process.

If the issue persists, please **raise an issue!**

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!