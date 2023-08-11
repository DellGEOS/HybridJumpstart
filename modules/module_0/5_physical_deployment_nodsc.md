Hybrid Jumpstart | Deployment on physical hardware (without PowerShell DSC)
==============

Overview <!-- omit in toc -->
-----------
If you have followed the instructions to deploy the hybrid jumpstart on physical hardware ([as described here](/modules/module_0/4_physical_deployment.md)), but have issues with WinRM, or PowerShell DSC deploying correctly, you can use these steps to take a more traditional PowerShell script-based approach to deploying the hybrid jumpstart environment. There are no changes to the supported environment - this can be run on a physical server, workstation or a laptop, or, it could also be an appropriately sized virtual machine running on an an existing virtualization platform, such as Hyper-V or VMware vSphere.
_____________________
**NOTE** - If you do choose to deploy the environment inside a virtual machine on an existing virtualization platform, ensure that the VM you create is large enough, and supports nested virtualization.
_____________________

Section duration <!-- omit in toc -->
-------------
60 Minutes

Contents <!-- omit in toc -->
--------

- [Hybrid Jumpstart | Deployment on physical hardware (without PowerShell DSC)](#hybrid-jumpstart--deployment-on-physical-hardware-without-powershell-dsc)
  - [Download the DeployHybridJumpstartCore.ps1 script](#download-the-deployhybridjumpstartcoreps1-script)
  - [Starting deployment](#starting-deployment)
      - [Deployment with automatic ISO downloads and default external DNS forwarders](#deployment-with-automatic-iso-downloads-and-default-external-dns-forwarders)
      - [Deployment with user-provided ISOs and custom external DNS forwarders](#deployment-with-user-provided-isos-and-custom-external-dns-forwarders)
  - [Exploring the environment](#exploring-the-environment)
  - [Next steps](#next-steps)
  - [Raising issues](#raising-issues)

Download the DeployHybridJumpstartCore.ps1 script
--------
In order to streamline the deployment of the hybrid jumpstart on your existing Windows Server or Windows Client machine (which doesn't support modificatiion to WinRM, or running PowerShell DSC), download the **DeployHybridJumpstartCore.ps1** script with the following PowerShell commands. Please note, to run the script, you will need to relax your PowerShell execution policy to allow remote scripts to run on the system.

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
Invoke-Webrequest https://raw.githubusercontent.com/DellGEOS/HybridJumpstart/main/manual/DeployHybridJumpstartCore.ps1 `
    -UseBasicParsing -OutFile DeployHybridJumpstartCore.ps1
```

2. You should now have the **DeployHybridJumpstartCore.ps1** in a folder on your desktop. Once run, the script will generate a log file that will also appear in this folder, which can help with troubleshooting, should something go wrong.

### Exploring the DeployHybridJumpstartCore.ps1 script <!-- omit in toc -->

The script will perform the following tasks:
* Enable Hyper-V and accompanying management tools, along with rebooting the machine
* Download all necessary software binaries for deployment
* Automate deployment of MSLab, which in turn, will deploy a Windows Server 2022 Domain Controller, management server and Azure Stack HCI nodes

On a new machine, the script will need to be run at least twice - the first time, it will enable Hyper-V and supporting roles, then reboot. After the reboot, you will rerun the script with the same parameters to deploy the hybrid jumpstart.

The script accepts a number of parameters to customize deployment of the hybrid jumpstart:

- **-azureStackHCINodes** - this is the number of Azure Stack HCI nodes you'd like to run on this system. Enter a number between 1 and 4.
- **-azureStackHCINodeMemory** - this is the amount of memory per Azure Stack HCI node you'd like to allocate. Enter 4, 8, 12, 16, 24, 32 or 48.
- **-updateImages** - choose this if you'd like to automatically update your Azure Stack HCI and Windows Server 2022 images with the latest cumulative update. Please note, this will increase the runtime of the script considerably.
- **-jumpstartPath** - this is the folder on your local system where all the hybrid jumpstart virtual machines and lab files will reside.
- **-WindowsServerIsoPath** - if you have already downloaded the Windows Server 2022 iso, provide the full path.
- **-AzureStackHCIIsoPath** - if you have already downloaded the Azure Stack HCI 22H2 iso, provide the full path.
- **-dnsForwarders** - if you wish to use a custom external DNS forwarder(s), use the format "9.9.9.9". If you wish to use multiple DNS forwarders, enter them separated by a comma (,) and with no spaces: "9.9.9.9,149.112.112.112". Alternatively, enter the parameter "Default" and the deployment will use 8.8.8.8 and 1.1.1.1.
- **-telemetryLevel** - this sets the telemetry level for the MSLab automated deployment. Options are Full, Basic and None. You can [read more about MSLab telemetry on GitHub](https://github.com/microsoft/MSLab/blob/master/Docs/mslab-telemetry.md).

Starting deployment
--------
To run the DeployHybridJumpstartCore.ps1 script, you will need to provide all the necessary parameters up front.

1. Still in your **PowerShell console as administrator** from earlier, run the following commands (adjust for your environment):

#### Deployment with automatic ISO downloads and default external DNS forwarders

```powershell
.\DeployHybridJumpstartCore.ps1 -azureStackHCINodes 2 -azureStackHCINodeMemory 16 -updateImages "No" `
    -jumpstartPath "D:\HybridJumpstart" -dnsForwarders "Default" -telemetryLevel "Full"
```

#### Deployment with user-provided ISOs and custom external DNS forwarders

```powershell
.\DeployHybridJumpstartCore.ps1 -azureStackHCINodes 2 -azureStackHCINodeMemory 16 -updateImages "No" `
    -jumpstartPath "D:\HybridJumpstart" -WindowsServerIsoPath "D:\WS\WS2022.iso" `
    -AzureStackHCIIsoPath "D:\AzSHCI\AzSHCI22H2.iso" -dnsForwarders "208.67.222.222" -telemetryLevel "Full"
```

The script will begin to execute. If the Hyper-V role and accompanying management tools are not installed, you will be prompted to install and enable those:

![Deployment started - enabling Hyper-V](/modules/module_0/media/deploy_hybrid_jumpstart_enable_hyperv2.png "Deployment started - enabling Hyper-V")

2. When prompted, enter **Y** to continue. Once the install has completed, enter **Y** again to reboot your machine.

3. Once your machine is back online, reopen your **PowerShell console as administrator** and navigate to your desktop folder by running the following PowerShell commands:

```powershell
$desktopPath = "$([Environment]::GetFolderPath("Desktop"))\HybridJumpstart"
Set-Location $desktopPath
```

4. Press the **Up** key on your keyboard to cycle through the previously run PowerShell commands, until you find your deployment command from earlier. Alternatively, copy and paste the same commands from above.

5. Once you have the command in place, press **Enter** to execute the command and start the deployment process. This should take around **50-60 minutes**, depending on your download speed (to download the ISO files, if you didn't provide them) and the speed/performance of your physical system.

6. After around 60 minutes, the deployment should have completed successfully, and you should see a new **remote desktop icon** on your desktop. As you can see, in this case, the deployment took around 51 minutes, of which downloading the ISO files took 12 minutes.

![Deployment complete](/modules/module_0/media/deploy_hybrid_jumpstart_complete2.png "Deployment complete")

1. When you're ready, **close the PowerShell window**. If you run into issues, or the PowerShell DSC deployment doesn't complete successfully, please [raise an issue](#raising-issues).

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

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!