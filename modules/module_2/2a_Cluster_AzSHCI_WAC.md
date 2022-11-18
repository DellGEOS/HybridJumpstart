Module 2 | Scenario 2a - Clustering Azure Stack HCI with Windows Admin Center
============

Overview <!-- omit in toc -->
------------

In this section, you'll walk through deployment of an Azure Stack HCI cluster using **Windows Admin Center**. If you have a preference for deployment with PowerShell, head over to the [PowerShell cluster creation guidance](/modules/module_2/2b_Cluster_AzSHCI_PS.md).

Scenario duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
-----------
- [Before you begin](#before-you-begin)
- [Architecture](#architecture)
  - [Log into your environment](#log-into-your-environment)
  - [Decide on cluster type](#decide-on-cluster-type)
- [Creating a (local) cluster](#creating-a-local-cluster)
  - [Get started](#get-started)
  - [Networking](#networking)
  - [Clustering](#clustering)
  - [Storage](#storage)
  - [SDN](#sdn)
- [Configuring the cluster witness](#configuring-the-cluster-witness)
  - [Witness Option 1 - File Share Witness](#witness-option-1---file-share-witness)
  - [Witness Option 2 - Cloud Witness](#witness-option-2---cloud-witness)
- [Next steps](#next-steps)
- [Raising issues](#raising-issues)

Before you begin
-----------
Before we create our Azure Stack HCI cluster, it's important to double check the **Infrastructure prerequisites** and the **Azure prerequisites** to ensure you'll be able to proceed through the deployment process.

### Infrastructure prerequisites <!-- omit in toc -->
You should have completed the **initial hybrid jumpstart deployment** either on a [**physical system**](/modules/module_0/4_physical_deployment.md), or inside an [**Azure virtual machine**](/modules/module_0/3_azure_vm_deployment.md). If you haven't, go back and perform the deployment - it should take between 40-60 minutes, depending on your configuration choices.

### Azure prerequisites <!-- omit in toc -->
For connecting and integrating the Azure Stack HCI environment with Azure, you'll need to review the list below.

* **Get an Azure subscription** - if you don't have one, read [more information here](/modules/module_0/2_azure_prerequisites.md#get-an-azure-subscription)
* **Azure subscription permissions** - Owner **or** User Access Administrator + Contributer **or** Custom ([Instructions here](https://docs.microsoft.com/en-us/azure-stack/hci/deploy/register-with-azure#assign-permissions-from-azure-portal))
* **Firewall / Proxy** - If you are running the environment inside your own lab, ensure that your lab deployment has access to all external resources listed below:
  * [Host requirements](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements)
  * [Arc-enabled Servers requirements](https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#networking-configuration)

Architecture
-----------
As shown on the architecture graphic below, in this step, you'll be creating the **Nested Azure Stack HCI cluster**, shown on the left hand side of the graphic. The automated deployment process you performed previously, has deployed the DC, WACGW and the AzSHCI nodes themselves, so you're ready to **transform them into an Azure Stack HCI cluster**. You'll be focused on **creating a cluster in a single site**.

![Architecture diagram for Azure Stack HCI nested](/modules/module_0/media/nested_virt_physical.png "Architecture diagram for Azure Stack HCI nested")

### Log into your environment
If you aren't already, make sure you're logged into your Hyper-V host (either the previously deployed Azure VM, or your physical system).

1. Once logged in, from your start menu, search for **Hyper-V** and open **Hyper-V Manager**.
2. Once opened, you should see your virtual machines **running** on your physical system. If any of the VM's aren't running, right-click the VM, and click **Start**.

![List of Hyper-V virtual machines](/modules/module_0/media/hyperv_vm_list.png "List of Hyper-V virtual machines")

3. Minimize Hyper-V Manager, and from your desktop, double-click the **HybridJumpstart** remote desktop icon to remotely connect to the Domain Controller inside the hybrid jumpstart sandbox.

4. Provide the appropriate credentials for the lab, which are:

* **Username:** dell\labadmin
* **Password:** LS1setup!

5. Once logged into the Domain Controller VM, open **Server Manager**.
6. Once opened, right-click on **All Servers** and select **Add Servers**

![Add Servers in Server Manager](/modules/module_0/media/server_manager_add_servers.png "Add Servers in Server Manager")

7. In the **Add Servers** window, click **Find Now**, and you'll see all the domain-joined machines in the current jumpstart deployment. Select all the servers in the list, then click the **right arrow** to add them to the management view on this Domain Controller machine, then click **OK**.
8. In **Server Manager**, under **All Servers**, you should now see all the servers in the domain listed, and available for management from this interface.

### Allow popups in Edge browser <!-- omit in toc -->
To give the optimal experience with Windows Admin Center, you should enable **Microsoft Edge** to allow popups for Windows Admin Center.

1. From inside your **DC** machine, open the **Microsoft Edge icon** on your taskbar.
2. If you haven't already, complete the initial Edge configuration settings.
3. Navigate to **edge://settings/content/popups**
4. Click the slider button to **disable** pop-up blocking
5. Close the **settings tab**.

### Configure Windows Admin Center <!-- omit in toc -->
With Windows Admin Center, you have the ability to construct Azure Stack HCI clusters from the previously deployed nodes. There are no additional extensions to install, the workflow is built-in and ready to go, however, it's worth checking to ensure that your Cluster Creation extension is fully up to date and make a few changes to the Edge browser to streamline things later.

During the **initial hybrid jumpstart deployment** either on a [**physical system**](/modules/module_0/4_physical_deployment.md), or inside an [**Azure virtual machine**](/modules/module_0/3_azure_vm_deployment.md), the latest version of Windows Admin Center was automatically installed for you. In addition, all previously installed extensions should have been updated, however there are some additional configuration steps that must be performed before you can use it to deploy Azure Stack HCI.

1. In your Edge browser, navigate to **https://wacgw**.
2. If you're prompted, log in with your usual credentials, which by default, are:

   * **Username**: dell\labadmin
   * **Password**: LS1setup!

3. Once Windows Admin Center is open, you may receive notifications in the top-right corner, indicating that some extensions are updating automatically. **Let these finish updating before proceeding**. Windows Admin Center may refresh automatically during this process.
4. Once complete, navigate to **Settings**, then **Extensions**
5. Click on **Installed extensions** and you should see **Cluster Creation** listed as installed.

![Installed extensions in Windows Admin Center](/modules/module_2/media/installed_extensions_cluster.png "Installed extensions in Windows Admin Center")

____________

**NOTE** - Ensure that your Cluster Creation extension is the **latest available version**. If the **Status** is **Installed**, you have the latest version. If the **Status** shows **Update available (2.#.#)**, ensure you apply this update and refresh before proceeding. It is recommended that you also update any of the other extensions that have an update available.

_____________

You're now ready to begin deployment of your Azure Stack HCI cluster with Windows Admin Center. Here are the major steps in the Create Cluster wizard in Windows Admin Center:

* **Get Started** - ensures that each server meets the prerequisites for and features needed for cluster join
* **Networking** - assigns and configures network adapters and creates the virtual switches for each server
* **Clustering** - validates the cluster is set up correctly. For stretched clusters, also sets up up the two sites
* **Storage** - Configures Storage Spaces Direct
* **SDN** - Configures Software Defined Networking (Optional)

### Decide on cluster type ###
Not only does Azure Stack HCI support a cluster in a single site (or a **local cluster** as we'll refer to it going forward) consisting of between 2 and 16 nodes, but, also supports a **Stretch Cluster**, where a single cluster can have nodes distrubuted across two sites.

* If you have 2 Azure Stack HCI nodes, you will be able to create a **local cluster**
* If you have 4 Azure Stack HCI nodes, you will have a choice of creating either a **local cluster** or a **stretch cluster**

In this section, we'll be focusing on deploying a **local cluster** but if you're interested in deploying a stretch cluster, you can [check out the official docs](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/stretched-clusters "Stretched clusters overview on Microsoft Docs")

Creating a (local) cluster
-----------
This section will walk through the key steps for you to set up the Azure Stack HCI cluster with Windows Admin Center

1. If you're not already logged in, log into the **HybridJumpstart-DC** virtual machine, open the **Microsoft Edge icon** on your taskbar, and browse to **https://wacgw**.
2. Once logged into Windows Admin Center, under **All connections**, click **Add**
3. On the **Add or create resources popup**, under **Server clusters**, click **Create new** to open the **Cluster Creation wizard**

### Get started ###
![Choose cluster type in the Create Cluster wizard](/modules/module_2/media/wac_cluster_type_ga.png "Choose cluster type in the Create Cluster wizard")

1. Ensure you select **Azure Stack HCI**, select **All servers in one site** and cick **Create**
2. On the **Check the prerequisites** page, review the requirements and click **Next**
3. On the **Add Servers** page, supply a **username**, which should be **dell\labadmin** and **LS1setup!** and then one by one, enter the node names of your Azure Stack HCI nodes (AZSHCI1, AZSHCI2 and so on), clicking **Add** after each one has been located.  Each node will be validated, and given a **Ready** status when fully validated.  This may take a few moments - once you've added all nodes, click **Next**

![Add servers in the Create Cluster wizard](/modules/module_2/media/add_nodes_ga.png "Add servers in the Create Cluster wizard")

4. On the **Join a domain** page, details should already be in place, as these nodes have already been joined to the domain to save time. If this wasn't the case, WAC would be able to configure this for you. Click **Next**

![Joined the domain in the Create Cluster wizard](/modules/module_2/media/wac_domain_joined_ga.png "Joined the domain in the Create Cluster wizard")

5. On the **Install features** page, Windows Admin Center will query the nodes for currently installed features, and will typically request you install required features. In this case, none of the required features have been pre-installed, so click **Install features**

![Installing required features in the Create Cluster wizard](/modules/module_2/media/wac_installed_features_ga.png "Installing required features in the Create Cluster wizard")

____________

**NOTE** - Due to this being a nested environment, Windows Admin Center will **not** enable the Hyper-V role inside your nested Azure Stack HCI nodes. You will need to run the following command from an **administrative PowerShell console**:

```powershell
$Servers = "AzSHCI1", "AzSHCI2", "AzSHCI3", "AzSHCI4"
Invoke-Command -ComputerName $Servers -ScriptBlock `
{ Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -NoRestart }
```

Once you click on **Install features** again, the status should show green, and you should be able to proceed, so click **Next**
_____________

6. On the **Install updates** page, Windows Admin Center will query the nodes for available updates, and will request you install any that are required. For the purpose of this guide and to save time, we'll ignore this for now and revisit later. Click **Next**
7. On the **Install hardware updates** page, in a nested environment this doesn't apply, however if this were a physical environment, you would be able to launch the Dell OMIMSWAC (OpenManage Integration for Microsoft Windows Admin Center) extension, which we will cover in a future module. For now, click **Next**
8. On the **Restart servers** page, if required, click **Restart servers** and wait for them to come back online, then click **Next**

![Restart nodes in the Create Cluster wizard](/modules/module_2/media/wac_restart_ga.png "Restart nodes in the Create Cluster wizard")

### Networking
With the servers configured with the appropriate features, updated and rebooted, you're ready to configure the network for your Azure Stack HCI nodes.

By default, your nested Azure Stack HCI nodes have 4 host network adapters (pNICs), however many new production systems are shipping with just 2 NICs, albeit with significantly higher performance and bandwidth available - in some cases, each NIC is 100GbE!

With as few as 2 physical NICs in a host, how can you ensure that you have multiple "separate networks" for traffic types like **Management**, **Virtual Machines** and **Storage**?

Fortunately, Azure Stack HCI provides a broad number of choices when it comes to defining the network infrastructure. Here's a few examples:

#### Shared compute and management with separate storage
In the below example, the Azure Stack HCI node has 4 physical NICs (pNICS) - 

![Network diagram with shared compute and management with separate storage](/modules/module_2/media/network-atc-6-disaggregated-management-compute.png "Network diagram with shared compute and management with separate storage")

2 of the NICs are aggregated into a **Switch Embedded Team (SET)** - a specialized type of vSwitch-enabled NIC team that exists on the Hyper-V host, that aggregates the physical NICs, and the teaming/vSwitch functionality.

From there, a single virtual network adapter (vNIC) is created for the Host, that will reside on the designated management network, for example, the 192.168.0.0/24 network. Virtual Machines will also connect to this Team, and their traffic will also flow out via the teamed pNICs.

The remaining 2 pNICs are dedicated to storage traffic between the Azure Stack HCI nodes in the cluster. These don't need teaming, as the redundancy and performance across both adapters is provided by SMB Multichannel.

#### Shared compute and storage with separate management
In the below example, again, the Azure Stack HCI node has 4 physical NICs (pNICS) - 

![Network diagram with compute and storage with separate management](/modules/module_2/media/network-atc-3-separate-management-compute-storage.png "Network diagram with compute and storage with separate management")

This example is particularly common when pNIC01 and pNIC02 are the onboard 1GbE adapters, which are most suited to management traffic, and the remaining 2 pNICs are high-performance adapters, useful for storage traffic, and the traffic coming in and leaving your virtual machines.

In this case, the pNICs are aggregated into 2 separate SET switches, one for management and one for the shared compute and storage, and corresponding host vNICs are created to allow the isolation of those different traffic types. Virtual machines would connect to the "Compute and Storage Team" in this example, sharing the total bandwidth provided by pNIC03 and pNIC04.

#### Shared compute and storage with separate management
In the below example, the Azure Stack HCI node has just 2 physical NICs (pNICS) - 

![Network diagram with a fully converged network configuration](/modules/module_2/media/network-atc-2-full-converge.png "Network diagram with a fully converged network configuration")

In this example, we just have 2 high-performance NICs, yet multiple different traffic types (Compute, Management, Storage) to account for. With this example, you simply aggregate the 2 pNICs into a SET switch, and from there, create the appropriate host vNICs to provide the networks for the different traffic types. All different traffic types share the available pNIC SET bandwidth, so it's important to factor in QoS and traffic management here.

Now that you understand more about the options for network configurations, how do you actually go about **applying** the network configurations?

With Windows Admin Center, there are 2 ways: **Manually**, or with the new **Network ATC**.

![Select host networking in Windows Admin Center](/modules/module_2/media/select_host_networking.png "Select host networking in Windows Admin Center")

With the **manual** approach, you're configuring each layer of the network across each node in the cluster - this can be complex, there are a number of moving parts, and things are easy to misconfigure or overlook. Also, occasionally things can change over time, configurations drift, which leads to additional challenges, especially around troubleshooting. Windows Admin Center aims to simplify the configuration as much as possible for you.

**Network ATC** however, simplifies the deployment and network configuration management for Azure Stack HCI clusters. This provides an intent-based approach to host network deployment. By specifying one or more intents (management, compute, or storage) for a network adapter, you can automate the deployment of the intended configuration. For more information on Network ATC, including an overview and definitions, see the [Network ATC overview](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/network-atc-overview).

> Unfortunately, **deploying Network ATC in virtual environments is not supported**. Several of the host networking properties it configures are not available in virtual machines, which will result in errors.

For the purpose of this guide therefore, we'll be configuring the networking settings **manually**, and the steps below are tailored for use inside nested virtual machines. We'll choose the **Shared compute and storage with separate management** example from above. Ensure that **Manually configure host networking** is selected, and click **Next:Networking**

Firstly, Windows Admin Center will verify your networking setup - it'll tell you how many NICs are in each node, along with relevant hardware information, MAC address and status information.  Review for accuracy, and then click **Next**

![Verify network in the Create Cluster wizard](/modules/module_2/media/wac_verify_network.png "Verify network in the Create Cluster wizard")

The first key step with setting up the networking with Windows Admin Center, is to choose a management NIC that will be dedicated for management use.  You can choose either a single NIC, or two NICs for redundancy. This step specifically designates 1 or 2 adapters that will be used by Windows Admin Center to orchestrate the cluster creation flow. It's mandatory to select at least one of the adapters for management, and in a physical deployment, the 1GbE NICs are usually good candidates for this.

As it stands, this is the way that Windows Admin Center approaches the network configuration, however, if you were not using Windows Admin Center, through PowerShell, there are a number of different ways to configure the network to meet your needs. We will work through the Windows Admin Center approach in this guide.

#### Network Setup Overview
Each of your Azure Stack HCI nodes should have 4 NICs. For this simple evaluation, you'll dedicate the NICs in the following way:

* 2 NICs will be dedicated to management. These NICs will be renamed, teamed and a new virtual network adapter will be created and used for management traffic
* 2 NICs will be dedicated to storage and compute traffic. They will be renamed, teamed and a pair of virtual network adapters will be created for the host, for storage purposes. These storage adapters will reside on the 172.16.1.0/24 subnet.

Again, this is just one **example** network configuration for the simple purpose of evaluation.

1. Back in Windows Admin Center, on the **Select the adapters to use for management** page, ensure you select the **Two physical network adapters teamed for management** box

![Select management adapter in the Create Cluster wizard](/modules/module_2/media/wac_management_nic.png "Select management adapter in the Create Cluster wizard")

2. Then, for each node, **select 2 NICs** that will be dedicated for management. In the nested environment, it doesn't matter which 2 NICs you choose. Once you've finished your selections, scroll to the bottom, then click **Apply and test**. When prompted, click **Yes** and the creation process will begin. This will take a few moments.

![Select management adapters in the Create Cluster wizard](/modules/module_2/media/wac_twomgmt.png "Select management adapters in the Create Cluster wizard")

3. Windows Admin Center will then apply the configuration to your NICs.

![Management team, successfully created](/modules/module_2/media/wac_twomgmt_applied.png "Management team, successfully created")

4. When the management networking configuration is complete and successful, click **Next**.

5. On the **Virtual Switch** page, you have a number of options

![Select vSwitch in the Create Cluster wizard](/modules/module_2/media/wac_vswitches.png "Select vSwitch in the Create Cluster wizard")

* **Create one virtual switch for compute and storage together** - in this configuration, your Azure Stack HCI nodes will create a vSwitch, comprised of multiple NICs, and the bandwidth available across these NICs will be shared by the Azure Stack HCI nodes themselves, for storage traffic, and in addition, any VMs you deploy on top of the nodes, will also share this bandwidth.
* **Create one virtual switch for compute only** - in this configuration, you would leave some NICs dedicated to storage traffic, and have a set of NICs attached to a vSwitch, to which your VMs traffic would be dedicated.
* **Create two virtual switches** - in this configuration, you can create separate vSwitches, each attached to different sets of underlying NICs.  This may be useful if you wish to dedicate a set of underlying NICs to VM traffic, and another set to storage traffic, but wish to have vNICs used for storage communication instead of the underlying NICs.
* You also have a check-box for **Skip virtual switch creation** - if you want to define things later, that's fine too

6. Select the **Create one virtual switch for compute and storage together**. Based on the current configuration, this is the only configuration you can choose, and the network adapters will be automatically selected for you, so click **Next**

7. On the **RDMA** page, you're now able to configure the appropriate RDMA settings for your host networks. If you do choose to tick the box, in a nested environment, you'll be presented with an error, so click **Next**

![Error message when configuring RDMA in a nested environment](/modules/module_2/media/wac_enable_rdma.png "Error message when configuring RDMA in a nested environment")

8. On the **Define networks** page, this is where you can define the specific networks, separate subnets, and optionally apply VLANs.  In this **nested environment**, we have 2 Host vNICs remaining, specifically for Storage. Configure your remaining NICs as follows, by clicking on a field in the table and entering the appropriate information.

____________________________

**NOTE** - we have a simple flat network in this configuration. One of the NICs have been claimed by the Management NIC, The remaining NICs will be show in the table in WAC, so ensure they align with the information below. WAC won't allow you to proceed unless everything aligns correctly.
____________________________

| Node | Name | IP Address | Subnet Mask | VLAN
| :-- | :-- | :-- | :-- | :-- |
| AZSHCI1 | SMB01 | 172.16.1.1 | 24 | 1
| AZSHCI1 | SMB02 | 172.16.1.2 | 24 | 1
| AZSHCI2 | SMB01 | 172.16.1.3 | 24 | 1
| AZSHCI2 | SMB02 | 172.16.1.4 | 24 | 1
| AZSHCI3 | SMB01 | 172.16.1.5 | 24 | 1
| AZSHCI3 | SMB02 | 172.16.1.6 | 24 | 1
| AZSHCI4 | SMB01 | 172.16.1.7 | 24 | 1
| AZSHCI4 | SMB02 | 172.16.1.8 | 24 | 1

You should delete any **default gateway** information from the form. When you click **Apply and test**, Windows Admin Center validates network connectivity between the adapters in the same VLAN and subnet, which may take a few moments.  Once complete, your configuration should look similar to this:

![Define networks in the Create Cluster wizard](/modules/module_2/media/wac_define_network.png "Define networks in the Create Cluster wizard")

**NOTE**, You *may* be prompted with a **Credential Security Service Provider (CredSSP)** box - read the information, then click **Yes**

![Validate cluster in the Create Cluster wizard](/modules/module_2/media/wac_credssp.png "Validate cluster in the Create Cluster wizard")

9. Once the networks have been verified, you can optionally review the networking test report, and once complete, click **Next**

10.  Once changes have been successfully applied, click **Next: Clustering**

### Clustering ###
With the network configured for the jumpstart environment, it's time to construct the local cluster.

1. At the start of the **Cluster** wizard, on the **Validate the cluster** page, click **Validate**.

2. Cluster validation will then start, and will take a few moments to complete - once completed, you should see a successful message.

**NOTE** - Cluster validation is intended to catch hardware or configuration problems before a cluster goes into production. Cluster validation helps to ensure that the Azure Stack HCI solution that you're about to deploy is truly dependable. You can also use cluster validation on configured failover clusters as a diagnostic tool. If you're interested in learning more about Cluster Validation, [check out the official docs](https://docs.microsoft.com/en-us/azure-stack/hci/deploy/validate "Cluster validation official documentation").

![Validation complete in the Create Cluster wizard](/modules/module_2/media/wac_validated.png "Validation complete in the Create Cluster wizard")

1. Optionally, if you want to review the validation report, click on **Download report** and open the file in your browser.
2. Back in the **Validate the cluster** screen, click **Next**
3. On the **Create the cluster** page, enter your **cluster name** as **AzSHCI-Cluster**
4. Under **IP address**, click **Specify one or more static addresses**, and enter **10.0.0.111**
5. Expand **Advanced** and review the settings, then click **Create cluster**

![Finalize cluster creation in the Create Cluster wizard](/modules/module_2/media/wac_create_clus_static.png "Finalize cluster creation in the Create Cluster wizard")

6. With all settings confirmed, click **Create cluster**. This will take a few moments.  Once complete, click **Next: Storage**

![Cluster creation successful in the Create Cluster wizard](/modules/module_2/media/wac_cluster_success.png "Cluster creation successful in the Create Cluster wizard")

### Storage ###
With the cluster successfully created, you're now good to proceed on to configuring your storage.  Whilst less important in a fresh nested environment, it's always good to start from a clean slate, so first, you'll clean the drives before configuring storage.

1. On the storage landing page within the Create Cluster wizard, click **Erase Drives**, and when prompted, with **You're about to erase all existing data**, click **Erase drives**.  Once complete, you should have a successful confirmation message, then click **Next**

![Cleaning drives in the Create Cluster wizard](/modules/module_2/media/wac_clean_drives.png "Cleaning drives in the Create Cluster wizard")

2. On the **Check drives** page, validate that all your drives have been detected, and show correctly.  As these are virtual disks in a nested environment, they won't display as SSD or HDD etc. You should have **12 data drives** per node.  Once verified, click **Next**

![Verified drives in the Create Cluster wizard](/modules/module_2/media/wac_check_drives_ga.png "Verified drives in the Create Cluster wizard")

3. Storage Spaces Direct validation tests will then automatically run, which will take a few moments.

![Verifying Storage Spaces Direct in the Create Cluster wizard](/modules/module_2/media/wac_validate_storage.png "Verifying Storage Spaces Direct in the Create Cluster wizard")

4. Once completed, you should see a successful confirmation.  You can scroll through the brief list of tests, or alternatively, click to **Download report** to view more detailed information, then click **Next**

![Storage verified in the Create Cluster wizard](/modules/module_2/media/wac_storage_validated.png "Storage verified in the Create Cluster wizard")

5. The final step with storage, is to **Enable Storage Spaces Direct**, so click **Enable**.  This will take a few moments.

![Storage Spaces Direct enabled in the Create Cluster wizard](/modules/module_2/media/wac_s2d_enabled.png "Storage Spaces Direct enabled in the Create Cluster wizard")

6. With Storage Spaces Direct enabled, click **Next:SDN**

### SDN ###
With Storage configured, for the purpose of this section, we will skip the SDN configuration, but will revisit SDN in a different part of this module.

1. On the **Define the Network Controller cluster** page, click **Skip**
2. On the **Confirmation page**, click on **Go to connections list**

Configuring the cluster witness
-----------
By deploying an Azure Stack HCI cluster, you're providing high availability for workloads. These resources are considered highly available if the nodes that host resources are up; however, the cluster generally requires more than half the nodes to be running, which is known as having **quorum**.

Quorum is designed to prevent split-brain scenarios which can happen when there is a partition in the network and subsets of nodes cannot communicate with each other. This can cause both subsets of nodes to try to own the workload and write to the same disk which can lead to numerous problems. However, this is prevented with Failover Clustering's concept of quorum which forces only one of these groups of nodes to continue running, so only one of these groups will stay online.

In addition to the nodes themselves, a **witness** can be used to add an additional vote and help to ensure the split-brain scenario doesn't occur.

If you want to learn more about quorum, and the witness concept [check out the official documentation.](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/quorum "Official documentation about Cluster quorum")

With Azure Stack HCI, there are 2 options for the witness:

* File Share Witness
* Cloud Witness

We'll document both options below - feel free to choose the one that's most appropriate for you.

### Witness Option 1 - File Share Witness
The first option is to use a standard SMB file share, *somewhere* in your environment to act as the witness, store the witness.log file and provide quorum for the cluster. This file share should be a redundant file share, but for the purpose of this scenario, you'll be creating a file share on the domain controller, and for speed and simplicity, we'll use PowerShell to create the file share.

1. Open an **Administrative PowerShell console**, and run the following PowerShell commands to create a suitable file share on the domain controller:

```powershell
# Configure Witness
$WitnessServer = "DC"

# Create new directory
$ClusterName = "AzSHCI-Cluster"
$WitnessName = $ClusterName + "Witness"
Invoke-Command -ComputerName $WitnessServer -ScriptBlock `
{ New-Item -Path C:\Shares -Name $using:WitnessName -ItemType Directory }
$accounts = @()
$accounts += "Dell\$ClusterName$"
$accounts += "Dell\Domain Admins"
New-SmbShare -Name $WitnessName -Path "C:\Shares\$WitnessName" `
    -FullAccess $accounts -CimSession $WitnessServer

# Set NTFS permissions 
Invoke-Command -ComputerName $WitnessServer -ScriptBlock `
{ (Get-SmbShare $using:WitnessName).PresetPathAcl | Set-Acl }
```

> The code above first defines the location where the Witness folder and file share will be created. It then creates a new directory, sets the directory as an SMB share on the network, and assigns the appropriate permissions to a core set of accounts.

2. With the file share created, you can now configure the cluster to use this file share as the witness. If you're not already, ensure you're logged into your **Windows Admin Center** instance, and click on the **AzSHCI-Cluster** that you created earlier

![Connect to your cluster with Windows Admin Center](/modules/module_2/media/wac_azshcicluster.png "Connect to your cluster with Windows Admin Center")

3. You may be prompted for credentials, so log in with your **dell\labadmin** credentials and tick the **Use these credentials for all connections** box. You should then be connected to your **AzSHCI-Cluster cluster**
4. After a few moments of verification, the **cluster dashboard** will open. 
5. On the **cluster dashboard**, at the very bottom-left of the window, click on **Settings**
6. In the **Settings** window, click on **Witness** and under **Witness type**, use the drop-down to select **File share witness**

![Set up a file share witness in Windows Admin Center](/modules/module_2/media/wac_fs_witness.png "Set up file share witness in Windows Admin Center")

7. For the **File share path**, enter the path to the file share you created on the domain controller earlier, which by default should be **\\\DC\AzSHCI-ClusterWitness**
8. You can leave the username and password fields blank, and click **Save**.
9. Within a few moments, your witness settings should be successfully applied and you have now completed configuring the quorum settings for the **AzSHCI-Cluster** cluster.

### Witness Option 2 - Cloud Witness
If you prefer, you can choose to use a cloud witness instead of a file share. Cloud Witness is a type of Failover Cluster quorum witness that uses Microsoft Azure to provide a vote on cluster quorum. It uses Azure Blob Storage to read/write a blob file which is then used as an arbitration point in case of split-brain resolution.

1. Open a new tab in your browser, and navigate to **https://portal.azure.com** and login with your Azure credentials
2. You should already have a subscription from an earlier step, but if not, you should [review those steps and create one, then come back here](/modules/module_0/2_azure_prerequisites.md#get-an-azure-subscription)
3. Once logged into the Azure portal, click on **Create a Resource**, click **Storage**, then **Storage account**
4. For the **Create storage account** blade, ensure the **correct subscription** is selected, then enter the following:

    * Resource Group: **Create new**, then enter **azshcicloudwitness**, and click **OK**
    * Storage account name: **azshcicloudwitness**
    * Region: **Select your preferred region**
    * Performance: **Only standard is supported**
    * Redundancy: **Locally-redundant storage (LRS)** - Failover Clustering uses the blob file as the arbitration point, which requires some consistency guarantees when reading the data. Therefore you must select Locally-redundant storage for Replication type.

![Set up storage account in Azure](/modules/module_2/media/azure_cloud_witness.png "Set up storage account in Azure")

5. On the **Advanced** page, ensure that **Enable blob public access** is **unchecked**, and **Minimum TLS version** is set to **Version 1.2**
6. On the **Networking**, **Data protection** and **Tags** pages, accept the defaults and press **Next**
7. When complete, click **Create** and your deployment will begin.  This should take a few moments.
8. Once complete, in the **notification**, click on **Go to resource**
9. On the left-hand navigation, under Settings, click **Access Keys**. When you create a Microsoft Azure Storage Account, it is associated with two Access Keys that are automatically generated - Primary Access key and Secondary Access key. For a first-time creation of Cloud Witness, use the **Primary Access Key**. There is no restriction regarding which key to use for Cloud Witness.
10. Click on **Show keys** and take a copy of the **Storage account name** and **key1**

![Configure Primary Access key in Azure](/modules/module_2/media/azure_keys.png "Configure Primary Access key in Azure")

11. On the left-hand navigation, under Settings, click **Properties** and make a note of your **blob service endpoint**.

![Blob Service endpoint in Azure](/modules/module_2/media/azure_blob.png "Blob Service endpoint in Azure")

**NOTE** - The required service endpoint is the section of the Blob service URL **after blob.**, i.e. for our configuration, **core.windows.net**

12. With all the information gathered, open **Windows Admin Center**.
13. Click on the **AzSHCI-Cluster** that you created earlier

![Connect to your cluster with Windows Admin Center](/modules/module_2/media/wac_azshcicluster.png "Connect to your cluster with Windows Admin Center")

14. You may be prompted for credentials, so log in with your **dell\labadmin** credentials and tick the **Use these credentials for all connections** box. You should then be connected to your **AzSHCI-Cluster cluster**
15. After a few moments of verification, the **cluster dashboard** will open. 
16. On the **cluster dashboard**, at the very bottom-left of the window, click on **Settings**
17. In the **Settings** window, click on **Witness** and under **Witness type**, use the drop-down to select **Cloud witness** and complete the form with your values, then click **Save**

![Providing storage account info in Windows Admin Center](/modules/module_2/media/wac_azure_key.png "Providing storage account info in Windows Admin Center")

18. Within a few moments, your witness settings should be successfully applied and you have now completed configuring the quorum settings for the **AzSHCI-Cluster** cluster.

### Congratulations! <!-- omit in toc -->
You've now successfully deployed and configured your Azure Stack HCI cluster!

Next steps
-----------
In this step, you've successfully created a nested Azure Stack HCI cluster using Windows Admin Center. With this complete, you can now move on to [Register Azure Stack HCI with Azure](/modules/module_2/3_Register_Azure.md "Register Azure Stack HCI with Azure")

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!