Hybrid Cloud Workshop | Deployment in Azure
==============

Overview <!-- omit in toc -->
-----------
As mentioned earlier, with the introduction of [nested virtualization support in Azure](https://azure.microsoft.com/en-us/blog/nested-virtualization-in-azure/ "Nested virtualization announcement blog post") back in 2017, Microsoft has opened the door to a number of new and interesting scenarios. Nested virtualization in Azure is particularly useful for validating configurations that would require additional hardware in your environment, such as running Azure Stack HCI clusters.

In this section, we'll walk you through deploying an Azure virtual machine that will support the different modules of the workshop.

Contents <!-- omit in toc -->
--------
- [Architecture](#architecture)

Architecture
-----------

From an architecture perspective, the following graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for Azure Stack HCI in Azure](/media/nested_virt_arch.png "Architecture diagram for Azure Stack HCI in Azure")

The outer box represents the Azure Resource Group, which will contain all of the artifacts deployed in Azure, including the virtual machine itself, and accompaying network adapter, storage and so on. You'll deploy an Azure VM running Windows Server 2022 Datacenter. On top of this, you'll run an **Azure Stack HCI 21H2 cluster**, and deploy a number of different workloads on top, as you progress through the different modules in the workshop.

Azure VM Size Considerations
-----------

Now, before you deploy the VM in Azure, it's important to choose a **size** that's appropriate for your needs for this workshop, along with a preferred region. It's highly recommended to choose a VM size that has **at least 64GB memory**. This deployment, by default, recommends using a **Standard_E16s_v4**, which is a memory-optimized VM size, with 16 vCPUs, 128 GiB memory, and no temporary SSD storage. The OS drive will be the default 127 GiB in size and the Azure VM deployment will add an additional 8 data disks (32 GiB each by default), so you'll have around 256GiB to deploy Azure Stack HCI 21H2. You can also make this larger after deployment, if you wish.

This is just one VM size that we recommend - you can adjust accordingly to suit your needs, even after deployment. The point here is, think about how large a hybrid infrastructure you'd like to deploy inside this Azure VM, and select an Azure VM size from there. Some potential examples would be:

**D-series VMs (General purpose) with at least 64GB memory**

| Size | vCPU | Memory: GiB | Temp storage (SSD): GiB | Premium Storage |
|:--|---|---|---|---|
| Standard_D16s_v3  | 16  | 64 | 128 | Yes |
| Standard_D16_v4  | 16  | 64 | 0 | No |
| **Standard_D16s_v4**  | **16**  | **64**  | **0**  | **Yes** |
| Standard_D16d_v4 | 16 | 64  | 600 | No |
| Standard_D16ds_v4 | 16 | 64 | 600 | Yes |

For reference, the Standard_D16s_v4 VM size costs approximately US $0.77 per hour based on East US region, under a Visual Studio subscription.

**E-series VMs (Memory optimized - Recommended for this Hybrid Workshop) with at least 64GB memory**

| Size | vCPU | Memory: GiB | Temp storage (SSD): GiB | Premium Storage |
|:--|---|---|---|---|
| Standard_E8s_v3  | 8  | 64  | 128  | Yes  |
| Standard_E8_v4  | 8  | 64  | 0  | No |
| **Standard_E8s_v4**  | **8**  | **64**  | **0**  | **Yes** |
| Standard_E8d_v4 | 8 | 64  | 300  | No |
| Standard_E8ds_v4 | 8 | 64 | 300  | Yes |
| Standard_E16s_v3  | 16  | 128 | 256 | Yes |
| **Standard_E16s_v4**  | **16**  | **128**  | **0**  | **Yes** |
| Standard_E16d_v4 | 16 | 128  | 600 | No |
| Standard_E16ds_v4 | 16 | 128 | 600 | Yes |

For reference, the Standard_E8s_v4 VM size costs approximately US $0.50 per hour based on East US region, under a Visual Studio subscription.

**NOTE 1** - A number of these VM sizes include temp storage, which offers high performance, but is not persistent through reboots, Azure host migrations and more. It's therefore advisable, that if you are going to be running the Azure VM for a period of time, but shutting down frequently, that you choose a VM size with no temp storage, and ensure your nested VMs are placed on the persistent data drive within the OS.

**NOTE 2** - It's strongly recommended that you choose a VM size that supports **premium storage** - when running nested virtual machines, increasing the number of available IOPS can have a significant impact on performance, hence choosing **premium storage** over Standard HDD or Standard SSD, is strongly advised. Refer to the table above to make the most appropriate selection.

**NOTE 3** - Please ensure that whichever VM size you choose, it [supports nested virtualization](https://docs.microsoft.com/en-us/azure/virtual-machines/acu "Nested virtualization support") and is [available in your chosen region](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=virtual-machines "Virtual machines available by region").

Deploying the Azure VM
-----------
The guidance below provides a simple template-based option for deploying the Azure VM. The template deployment will be automated to the point of which you can proceed to the next step, learning about MSLab, and progress through your workshop from there.

### Deployment detail
As part of the deployment, the following steps will be **automated for you**:

1. A Windows Server 2022 Datacenter VM will be deployed in Azure
2. 8 x 32GiB (by default) Azure Managed Disks will be attached and provisioned with a Simple Storage Space for optimal nested VM performance
3. The Hyper-V role and management tools will be installed and configured
4. An Internal vSwitch will be created and NAT configured to enable outbound networking
5. The Microsoft Edge browser will be installed

This automated deployment **should take around 20 minutes**.

### Creating the VM with an Azure Resource Manager JSON Template
To keep things simple, and graphical, we'll show you how to deploy your VM via an Azure Resource Manager template. To simplify things further, we'll use the following buttons.

Firstly, the **Visualize** button will launch the ARMVIZ designer view, where you will see a graphic representing the core components of the deployment, including the VM, NIC, disk and more. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Visualize your template deployment](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FDellGEOS%2FHybridWorkshop%2Fmain%2Fjson%2Fhybridhost.json "Visualize your template deployment")

Secondly, the **Deploy to Azure** button, when clicked, will take you directly to the Azure portal, and upon login, provide you with a form to complete. If you want to open this in a new tab, **hold CTRL** when you click the button.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDellGEOS%2FHybridWorkshop%2Fmain%2Fjson%2Fhybridhost.json "Deploy to Azure")

Upon clicking the **Deploy to Azure** button, enter the details, which should look something similar to those shown below, and click **Purchase**.

![Custom template deployment in Azure](/media/azure_vm_custom_template_new.png "Custom template deployment in Azure")

**NOTE** - For customers with Software Assurance, Azure Hybrid Benefit for Windows Server allows you to use your on-premises Windows Server licenses and run Windows virtual machines on Azure at a reduced cost. By selecting **Yes** for the "Already have a Windows Server License", **you confirm I have an eligible Windows Server license with Software Assurance or Windows Server subscription to apply this Azure Hybrid Benefit** and have reviewed the [Azure hybrid benefit compliance](http://go.microsoft.com/fwlink/?LinkId=859786 "Azure hybrid benefit compliance document")

The custom template will be validated, and if all of your entries are correct, you can click **Create**. Within a few minutes, your VM will be created.

![Custom template deployment in Azure completed](/media/azure_vm_custom_template_completed.png "Custom template deployment in Azure completed")

If you chose to **enable** the auto-shutdown for the VM, and supplied a time, and time zone, but want to also add a notification alert, simply click on the **Go to resource group** button and then perform the following steps:

1. In the **Resource group** overview blade, click the **HybridHost001** virtual machine
2. Once on the overview blade for your VM, **scroll down on the left-hand navigation**, and click on **Auto-shutdown**
3. Ensure the Enabled slider is still set to **On** and that your **time** and **time zone** information is correct
4. Click **Yes** to enable notifications, and enter a Webhook URL, or Email address
5. Click **Save**

You'll now be notified when the VM has been successfully shut down as the requested time.

With that completed, skip on to [connecting to your Azure VM](#connect-to-your-azure-vm)

#### Deployment errors ####
If your Azure VM fails to deploy successfully, and the error relates to the **HybridHost001/ConfigureHybridHost** PowerShell DSC extension, please refer to the [troubleshooting steps below](#troubleshooting).






Raising issues
-----------
If you notice something is wrong with the workshop, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridWorkshop/issues), and we'll be sure to fix this as quickly as possible!