Hybrid Jumpstart | Lab Configuration
==============

Overview <!-- omit in toc -->
-----------
In order to deploy and work through the different hands-on-labs in the jumpstart, we'll be using MSLab. Developed by Dell Technologies GEOS member, Jaromir Kaspar, MSLab is an open-source project that helps to quickly and easily deploy standardized virtualized environments for the purpose of learning, feature testing and more. The use of MSLab in this jumpstart ensures that all participants can experience a more standardized and structured flow through the different technologies within the Hybrid Jumpstart.

Section duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
--------

- [Step 1 - Download files](#step-1---download-files)
- [Step 2 - Extract and review MSLab files](#step-2---extract-and-review-mslab-files)
- [Step 3 - Lab hydration](#step-3---lab-hydration)
  - [Edit the LabConfig file](#edit-the-labconfig-file)
  - [Exploring the LabConfig file](#exploring-the-labconfig-file)
  - [Run the MSLab Prereq Script](#run-the-mslab-prereq-script)
  - [Download the latest Cumulative Updates](#download-the-latest-cumulative-updates)
  - [Create your parent virtual hard disks](#create-your-parent-virtual-hard-disks)
- [Next steps](#next-steps)
- [Raising issues](#raising-issues)

Step 1 - Download files
--------
In the previous sections, you reviewed the infrastructure and Azure prerequisites. If you're planning on running through the jumpstart by deploying on a physical server, you should have that system ready now, with the Hyper-V role installed and ready to go. If you didn't have any hardware available, you should have walked through deploying the Azure VM, ready to proceed with MSLab.

1. On your **Hyper-V host** (physical, or the Azure VM previously deployed) **open your preferred web browser**, and navigate to **http://aka.ms/mslab/download**. The download should start automatically, and by default, will store the ZIP file in your **Downloads folder**.
2. Still in the browser, you'll now need to download a Windows Server 2022 ISO file, for use with a number of the virtual machine images. There are a number of ways to do this, depending on what you have access to. If you're not sure, it's recommended to use the ISO file from the Eval Center. This will involve completing a short registration form.
   1. [**MSDN Downloads**](https://my.visualstudio.com/downloads)
   2. [**Eval Center**](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022) - Select "**Download the ISO**"
   3. [**VLSC Portal**](https://www.microsoft.com/licensing/servicecenter)
3. Finally, you'll need to download the latest Azure Stack HCI operating system ISO, by navigating to **https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/**, completing the short registration form, and downloading the ISO file.

Once completed, you'll have the 3 files downloaded, and be ready to proceed.

![All files downloaded for MSLab](/modules/module_0/media/mslab_downloaded_files.png "All files downloaded for MSLab")

Step 2 - Extract and review MSLab files
--------
With the files downloaded, you'll first need to extract the files into a location that has **at least 100GB of available, high performance SSD/NVMe storage**. In our case, this will be on our **V:**.

1. To extract, simply **right-click the mslab_v##.##.# folder**, select **Extract All**
2. Navigate to your chosen directory, **create a folder** named **HybridJumpstart** and click **Extract**

Alternatively, if you wish to extract using PowerShell, simply open a **PowerShell console as Administrator (Right-click, Run as Administrator)** and run the following command, amending the path to your downloaded ZIP file.

```powershell
Expand-Archive -LiteralPath 'C:\<path to zip>.Zip' -DestinationPath 'V:\HybridJumpstart'
```

![All MSLab files extracted](/modules/module_0/media/mslab_extracted_files.png "All MSLab files extracted")

With the files extracted, it's important to understand the purpose of each of these files.

* **1_Prereq** - When run, this script automates the configuration of your host system to support the deployment of MSLab. It'll perform tasks such as defining the folder structure, download additional scripts, tools, PowerShell DSC modules, and define telemetry settings.
* **2_CreateParentDisks** - The CreateParentDisks script automates transforming the ISO files that you previously downloaded, into space-efficient virtual hard disks that will be subsequently used by virtual machines deployed by MSLab. We'll explore the concept of Parent and differencing virtual hard disks later.
* **3_Deploy** - The Deploy script automates the creation of the lab environment - this includes a number of virtual machines that serve different purposes in the lab - such as a domain controller, mamagement server and Azure Stack HCI cluster nodes.
* **Cleanup** - As the name suggests, this removes all previously deployed resources, but does **not** remove the parent disks, as these are still valid for future re-deployments. Post-cleanup, the HybridJumpstart folder will be left in the same state it was **prior** to running the 3_Deploy script.
* **LabConfig** - This file is critical to the deployment of the environment. In a similar way to a JSON-based ARM Template defining the characteristics of an Azure deployment, the MSLab LabConfig file is an editable text file that defines the characteristics of the MSLab deployment. It can be used to define aspects such as the size and shape of virtual machines, internet access, networks and subnets, and much more. We'll explore the LabConfig more later.

Step 3 - Lab hydration
--------
Now that we have an understanding of each of the MSLab files, we can get started by preparing our Hyper-V host, and creating those parent virtual hard disks.

### Edit the LabConfig file

1. Navigate to your **HybridJumpstart folder**, and double-click the **LabConfig file** to open the file in Notepad.
2. Once opened, use **CTRL+A** to select all, and **delete** the contents of the LabConfig file.
3. **Copy** the following content into the LabConfig file, and **save the file**. You can then close the file.

```powershell
# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; `
        DomainNetbiosName = 'Dell'; DomainName = "Dell.hybrid"; Internet = $true ; VMs = @()
}

# Deploy domain-joined Azure Stack HCI Nodes
1..4 | ForEach-Object { 
    $VMNames = "AzSHCI" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
            ParentVHD = 'AzSHCI21H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
            MemoryStartupBytes = 4GB; MGMTNICs = 4 ; NestedVirt = $true
    } 
}

# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }
```

### Exploring the LabConfig file
Let's break down what this LabConfig file does.

```powershell
# Define core lab characteristics
$LabConfig = @{ DomainAdminName = 'LabAdmin'; AdminPassword = 'LS1setup!'; DCEdition = '4'; `
        DomainNetbiosName = 'Dell'; DomainName = "Dell.hybrid"; Internet = $true ; VMs = @()
}
```
This section first defines the **credentials** of the Active Directory domain that will be used throughout the deployment, then specifies the **edition of Windows Server** that will be used for the parent disk, in this case, **DCEdition='4'** would deploy Windows Server 2022 Datacenter with Desktop Experience (GUI) and **DCEdition='3'** would deploy the Server Core deployment of the same OS. The script also defines a custom domain name, then finally, we specify the **Internet=$true**, which tells MSLab's automation processes to configure networking to allow external access from the virtual environment.

There are a number of additional parameters that can be provided for this initial configuration, all of which you can review at the [MSLAb source](https://raw.githubusercontent.com/microsoft/MSLab/master/Scripts/LabConfig.ps1).

```powershell
# Deploy domain-joined Azure Stack HCI Nodes
1..4 | ForEach-Object { 
    $VMNames = "AzSHCI" ; $LABConfig.VMs += @{ VMName = "$VMNames$_" ; Configuration = 'S2D' ; `
            ParentVHD = 'AzSHCI21H2_G2.vhdx' ; HDDNumber = 12; HDDSize = 4TB ; `
            MemoryStartupBytes = 4GB; MGMTNICs = 4 ; NestedVirt = $true
    } 
}
```
This section focuses on the Azure Stack HCI cluster nodes themselves - as you can see, for each of the 4 nodes, it **defines names**, **size** attributes such as **memory**, **storage**, **network adapters**, and references a specific **parent virtual hard disk** that will be used to instantiate these virtual machines.

```powershell
# Deploy Windows Admin Center Management Server
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }
```
Finally, this section defines the characteristics for one final virtual machine - specifically one that will be used for management purposes, into which **Windows Admin Center** will be deployed. As you can see, it again references a parent virtual hard disk that would be created ahead of time.

### Run the MSLab Prereq Script
Now that the LabConfig file is understood, let's move on to hydrating the environment. Firstly, you need to run the 1_Prereq script. This process should take around 5 minutes, depending on your internet connection speed.

1. In your HybridJumpstart folder, **right-click** the **1_Prereq** file, and click **Run with PowerShell**. The script will automatically elevate, so allow it to **Run as Administrator**.

![Run 1_Prereq in PowerShell](/modules/module_0/media/mslab_prereq.png "Run 1_Prereq in PowerShell")

2. You may be prompted to install **nuget v2.#.#.#** to allow PowerShell packages and modules to be installed - enter **Y** if you are prompted, to allow the process to continue.

![Install NuGet](/modules/module_0/media/mslab_nuget.png "Install NuGet")

3. Once the script has completed, all files will have been downloaded, and folder structure created. You can safely close the PowerShell window by pressing **Enter**.

![Prereq install complete](/modules/module_0/media/mslab_prereq_complete.png "Prereq install complete")

With the script completed, return to your **HybridJumpstart folder**, and you'll notice some additional folders, specifically the **ParentDisks** and **Temp** folders.

![New MSLab folders](/modules/module_0/media/mslab_post_prereq.png "New MSLab folders")

4. Navigate into the **Temp** folder, and you'll see additonal folders and files containing tools that MSLab will use during it's creation and deployment processes.
5. Navigate back to the **HybridJumpstart folder**, and then into the **ParentDisks** folder, and you'll see a number of useful PowerShell script files relating to the creation of virtual hard disks that support the lab environment.

![New Parent Disk tools](/modules/module_0/media/mslab_parent_disk_tools.png "New Parent Disk tools")

### Download the latest Cumulative Updates
Top ensure your virtual hard disk images are created with the latest patches applied, you'll now run the **DownloadLatestCU** script, to grab the latest cumulative updates that will be injected into the virtual hard disks when they are being created later.

For the purpose of showcasing the functionality, we'll just grab the latest cumulative updates for the Windows Server 2022 operating system.

1. Within the **ParentDisks folder**, **Right-click** on the **DownloadLatestCU** file, and select **Run with PowerShell**
2. The **MSCatalog** PowerShell module will be installed, and once completed, you'll be prompted for a path. Press **Enter** to accept the default.
3. When prompted to download **preview **updates****, press **Enter** to accept the default response of **No**.
4. A window will pop up, asking you to select the chosen operating system that you'd like to download the latest cumulative updates for. Select **Azure Stack HCI 21H2 and Windows Server 2022**, then click **OK**. The download will take a few moments, depending on your connection speed.
5. Once complete, press **Enter** and within the **ParentDisks** folder, you should find a sub-folder containing the latest cumulative update.

![Cumulative updates downloaded](/modules/module_0/media/mslab_cumulative_update.png "Cumulative updates downloaded")

### Create your parent virtual hard disks
With the MSLab prerequisites completed, you can now move on to creating the parent virtual hard disks for both the Windows Server 2022-based virtual machines, as well as the Azure Stack HCI-based virtual machines that will be used in the jumpstart.

If the concept of **parent virtual hard disks** is new to you, fear not, we'll kick off the creation process, then spend some time walking through what is meant by the parent virtual hard disks.

1. Back in the **HybridJumpstart folder**, **right-click** the **2_CreateParentDisks** file, and click **Run with PowerShell**

![Creating the Parent Disks](/modules/module_0/media/mslab_create_parent_disks.png "Creating the Parent Disks")

2. If this is the first time you've run the script, you may be prompted with an option to **share telemetry** about your usage to improve the usage of MSLab. No Personally Identifiable Information (PII) is captured. Make your selection to proceed.
3. A new window will pop up, asking for the location of an **ISO file**. Navigate to the location where you downloaded the **Windows Server 2022 ISO** and click **Open**.
4. You then have the opportunity to select any **cumulative updates** that have been previously downloaded. Navigate to your **HybridJumpstart\ParentDisks** folder, and locate the **MSU file** within the subfolders, then click **Open**.

![Adding the cumulative updates](/modules/module_0/media/mslab_parent_msu.png "Adding the cumulative updates")

5. The creation of the parent virtual hard disks will then begin. This may take a few minutes, which in the meantime, it's worth understanding **what parent virtual hard disks are**, and how they are used in MSLab.

__________________________

### Understanding Differencing Disks <!-- omit in toc -->
In production environments, virtual machines typically have a single virtual hard disk for their operating system drive, and potentially some additional virtual hard disks for data drives.

In a scenario where you have 4 Windows Server 2022 virtual machines, each with 100GB fixed-size virtual hard disks allocated to the respectiev operating systems, that's **400GB** of physical capacity used for those 4 virtual machines, even though the majority of the data inside those virtual hard disks, is identical.

![Storage consumption without differencing disks](/modules/module_0/media/mslab_differencing1.png "Storage consumption without differencing disks")

With the use of differencing disks however, you create a single "Gold image", which contains a generalized instance of the chosen operating system, in this case, Windows Server 2022, and each virtual machine that you create, instantiates a small differencing disk, or **child virtual hard drive** that has a direct relationship with a **single parent virtual hard disk**. As shown below however, multiple virtual machines can **share** the parent virtual hard disk.

![Storage consumption with differencing disks](/modules/module_0/media/mslab_differencing2.png "Storage consumption with differencing disks")

As you can see, in this simple example, our storage consumption **drops from 400GB, to 100GB**, plus any unique delta changes that occur within each of the individual virtual machines. Remember, the virtual machines themselves don't know about this parent-child relationship, nor do they know they are writing to a differencing disk, rather than the gold image. This approach means that we can be very efficient on physical storage consumption - great for lab and test environments, but also for virtual desktop scenarios.
__________________________

6. Once the parent virtual hard disk has been created, you have the option to clean up unnecessary files and folders - press **Enter** to perform the clean up, then press **Enter** again to close the window.

7. Still in the **HybridJumpstart folder**, you will now notice a **LAB folder** which contains an offline Windows Server 2022 Active Directory Domain Controller image that was created during the parent disk creation process. This domain controller will be deployed later.

8. Back in the **HybridJumpstart folder**, in the **ParentDisks** subfolder, you should now see a set of virtual hard disks that will be used for the jumpstart.

![First set of virtual hard disks created](/modules/module_0/media/mslab_ws_parent_disks.png "First set of virtual hard disks created")

9. Back in the **HybridJumpstart\ParentDisks** folder, right click on **CreateParentDisk** and click **Run with PowerShell**.
10. In the **Please select ISO image** window, navigate to your **Azure Stack HCI ISO file** and click **Open**.
11. Again, You have the opportunity to select any **cumulative updates** that have been previously downloaded. Click **Cancel** in this window, as we will not update the Azure Stack HCI virtual hard disk image at this time.
12. When prompted for the **VHD name**, accept the default and press **Enter**.
13. When prompted to enter the **size of the image in GB**, accept the default and press **Enter** to begin the creeation process. This will take a few minutes.

 ![Azure Stack HCI virtual hard disk created](/modules/module_0/media/mslab_parentdisks_complete.png "Azure Stack HCI virtual hard disk created")

 14. Once complete, press **Enter** to close the window.
 15. In the **HybridJumpstart\ParentDisks** folder, you'll now find the additional Azure Stack HCI virtual hard disk.

 ![Azure Stack HCI virtual hard disk created](/modules/module_0/media/mslab_azshci_parent_disk.png "Azure Stack HCI virtual hard disk created")

Next steps
-----------
Now that you've completed the necessary prerequisites, you're ready to create and deploy your first Azure Stack HCI cluster. However, before doing so, it's recommended that you spend some time familiarizing yourself with the [**hybrid landscape in module 1**](/modules/module_1/1_hybrid_landscape.md).

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!