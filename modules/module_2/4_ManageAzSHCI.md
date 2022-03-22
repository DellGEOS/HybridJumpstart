Module 2 | Scenario 4 - Exploring local Azure Stack HCI management
============

Overview <!-- omit in toc -->
------------

With your Azure Stack HCI 21H2 cluster deployed and registered successfully, you can now walk through some of the core management operations. For completeness, we'll show you the processes with both Windows Admin Center and PowerShell where appropriate.

Scenario duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
-----------
- [Before you begin](#before-you-begin)
- [Storage](#storage)
  - [Explore Storage Settings](#explore-storage-settings)
  - [Create volumes for VMs](#create-volumes-for-vms)
- [Explore Cluster-wide settings](#explore-cluster-wide-settings)
- [Explore Hyper-V Host settings](#explore-hyper-v-host-settings)
- [Deploy your first virtual machine](#deploy-your-first-virtual-machine)
  - [Create the virtual machine](#create-the-virtual-machine)
  - [Live migrate the virtual machine](#live-migrate-the-virtual-machine)
  - [Explore the VM settings](#explore-the-vm-settings)


Before you begin
-----------
At this stage, you should have completed the previous section of the workshop, [Scenario 2a - Clustering Azure Stack HCI with Windows Admin Center](/modules/module_2/2a_Cluster_AzSHCI_WAC.md) or [Scenario 2b - Clustering Azure Stack HCI with PowerShell](/modules/module_2/2a_Cluster_AzSHCI_PS.md) and have an Azure Stack HCI cluster successfully deployed, along with a cloud/file share witness.

You should have also followed the steps to register your Azure Stack HCI cluster during [Scenario 3 - Integrate Azure Stack HCI with Azure](/modules/module_2/3_Integrate_Azure.md).

With those steps completed, you're now at a stage where you can explore the Azure Stack HCI environment, and perform some useful initial configuration tasks.

Storage
----------
A core element of Azure Stack HCI is **Storage Spaces Direct**. However, prior to Storage Spaces Direct, **Storage Spaces** was first introduced in Windows 7 and Windows Server 2012. It is conceptually similar to RAID, implemented in software, allowing you to group three or more internal/external drives together into a storage pool and then use capacity from that pool to create Storage Spaces, onto which you can run your workloads. Storage Spaces was simple and efficient to manage, offered more advanced functionality like thin provisioning, and provided redundancy against disk failure, or in the event of a Windows Server Failover Cluster, redundancy against node failure.

Fast forward to Windows Server 2016 and the evolution of Storage Spaces, into **Storage Spaces Direct**, which in turn, transformed Windows Server into a true hyperconverged infrastructure solution. With Storage Spaces Direct, administrators could continue to benefit from the ease of administration, but now, with a high performance, scalable storage solution incorperating some of the latest storage enhanecments such as **caching**, **tiering**, **resiliency** and **erasure coding** to name but a few.

### Explore Storage Settings
For this section, you'll use Windows Admin Center to explore some of the key storage settings within Azure Stack HCI.

1. On **HybridWorkshop-DC**, logged in as **dell\labadmin**, in your edge broswer, navigate to **https://wacgw/** to open Windows Admin Center, and on the **All connections** page, select your azshci-cluster.
2. In the bottom-left corner, click **Settings**
3. In the settings menu, you'll notice that there are 2 sub-settings for storage: **In-memory cache** and **Storage Spaces and pools**. We'll look at In-memory cache first:

![In-memory cache settings in Windows Admin Center](/modules/module_2/media/in-mem_cache.png "In-memory cache settings in Windows Admin Center")

____________________

 With the Cluster Shared Volumes in-memory caching, you're able to use spare physical **memory** capacity to boost the performance of **read-intensive** workloads - it can improve performance for workloads running on Hyper-V, as this uses unbuffered I/O to access VHD or VHDX files. (Unbuffered I/Os are any operations that are not cached by the Windows Cache Manager.) The reads in-memory are local to the host where the VM is running, so it doesn't impact the network, or impose any additional latency challenges.

The downside of the in-memory cache, is that it can introduce a performance overhead if your workloads are **write intensive**, in which case, you should consider turning this feature off.

To configure this feature, you simply use the check box to enable, and set the desired maximum memory **per cluster node** - this figure can be up to 80% of the host's memory!

To configure with PowerShell, you can use the following command:

```powershell
# Get existing cache size in MiB
(Get-Cluster).BlockCacheSize

# Set new cache size in MiB
(Get-Cluster).BlockCacheSize = 2048

# Run this command to move CSV's between servers to apply
Get-ClusterSharedVolume | ForEach-Object {
    $Owner = $_.OwnerNode
    $_ | Move-ClusterSharedVolume
    $_ | Move-ClusterSharedVolume -Node $Owner
}
```

> This command sets the cache to 2 GiB (Gibibytes), which is 2048 mebibytes (MiB)

You can [read more about the in-memory cache, here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/use-csv-cache).

____________________

4. Click on **Storage Spaces and pools** to be presented with additional information about the storage available to this cluster.

![Storage Spaces and Pools in Windows Admin Center](/modules/module_2/media/spaces_pools.png "Storage Spaces and pools in Windows Admin Center")

_________
The first set of options apply universally across all pools and spaces in this cluster:

* When adding physical drives to the system, you can determine if Storage Spaces direct automatically claims these new drives. You can [read more about adding drives here](https://docs.microsoft.com/en-us/windows-server/storage/storage-spaces/add-nodes#adding-drives).
* You can determine what happens if a failed drive is detected - Storage Spaces Direct automatically retires and evacuates failed drives. When this has happened, the drive status is Retired, and its storage capacity bar is empty. You can [read more about replacing failed drives here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/replace-drives).
* Finally, you can adjust the storage repair speed - this adjustable storage repair speed offers more control over the data resync process by allocating resources to either repair data copies (resiliency) or run active workloads (performance). This helps improve availability and allows you to service your clusters more flexibly and efficiently to best meet your needs. You can [read more about the storage repair speed here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/storage-repair-speed).

![Storage Spaces and Pools in Windows Admin Center](/modules/module_2/media/spaces_pools2.png "Storage Spaces and pools in Windows Admin Center")

The second set of options allows you to make storage pool-specific changes, such as the friendly name, the storage pool version and the default provisioning type.

* You should always be using the latest **Storage pool version**, unless you're planning to revert to a previous Azure Stack HCI version after an update. Once you've moved the storage pool version forward, it can't be rolled back.
* Traditionally, volumes are fixed provisioned, meaning that all storage is allocated from the storage pool when a volume is created. Despite the volume being empty, a portion of the storage pool’s resources are depleted. Other volumes can't make use of this storage, which impacts storage efficiency and requires more maintenance. New in Azure Stack HCI 21H2, you can now **Thin Provision** volumes - Thin provisioning is recommended over the traditional fixed provisioning if you don't know exactly how much storage a volume will need and want more flexibility. You can [read more about the volume provisioning here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/thin-provisioning).

![Storage Spaces and Pools in Windows Admin Center](/modules/module_2/media/spaces_pools3.png "Storage Spaces and pools in Windows Admin Center")

The final set of options allows you to define the storage cache settings. **Note** - this is different from the in-memory cache discussed earlier. This particular cache, a feature of Storage Spaces Direct, is a built-in server-side cache to maximize storage performance while reducing costs. It's a large, persistent, real-time read *and* write cache that is configured automatically upon deployment. In most cases, no manual management whatsoever is required. How the cache works depends on the types of drives present - Persistent Memory, NVMe, SSD or HDD.

As you can see from the graphic above, cache settings are automatically determined for you and Storage Spaces Direct automatically uses **all drives of the fastest type** for caching:

* For example, if you have NVMe and SSDs, the **NVMe will cache** for the SSDs.
* If you have SSDs and HDDs, the **SSDs will cache** for the HDDs
* When all drives are of the same type, no cache is configured automatically

You can [read more about the server-side caching here](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/cache).

__________________

### Create volumes for VMs
In this step, you'll create some volumes on your Azure Stack HCI cluster, and explore some of the additional storage settings.

#### Explore your drives
Before we create a volume, let's take a quick look at the drives available to our Azure Stack HCI cluster:

1. On the left hand navigation, under **Storage** select **Drives**.  The central **Drives** page shows you should show a summary of the drives in your cluster:

![Physical drives in Windows Admin Center](/modules/module_2/media/storage_drives.png "Physical drives in Windows Admin Center")

2. As you can see, you should have **48 drives** if you've followed the guide so far. Click on **Inventory** to see information about the drives.

![Physical drives in Windows Admin Center](/modules/module_2/media/storage_drives2.png "Physical drives in Windows Admin Center")

If these were real physical drives, you'd see information about specific serial numbers, the **type** would likely show a mix of HDD, SSD and/or NVMe, you'd also see **cache** and **capacity** drives. You'd also be able to select specific disk and trigger an LED light on the drive for identification, or retire/unretire drives. In a nested virtualization environment, many of these elements aren't functional.

#### Create a Three-way mirror volume

1. On the left hand navigation, under **Storage** select **Volumes**.  The central **Volumes** page shows you should have a single volume currently
2. On the Volumes page, select the **Inventory** tab, and then select **Create**
3. In the **Create volume** pane, enter **Volume01** for the volume name, and leave **Resiliency** as **Three-way mirror**
4. In Size on HDD, specify **50GB** for the size of the volume.
5. Expand **More options** and under **Provision as**, select **Thin**.
6. Leave the remaining defaults and then click **Create**.

![Create a volume on Azure Stack HCI](/modules/module_2/media/create_volume.png "Create a volume on Azure Stack HCI")

7. Creating the volume can take a few minutes. Notifications in the upper-right will let you know when the volume is created. The new volume appears in the Inventory list

![Volume created on Azure Stack HCI](/modules/module_2/media/wac_vm_storage_deployed.png "Volume created on Azure Stack HCI")

________________
In order to perform the same task with **PowerShell**, you can run the following command:

```powershell
$ClusterName = "AzSHCI-Cluster"
New-Volume -CimSession $ClusterName -FileSystem CSVFS_ReFS `
    -StoragePoolFriendlyName S2D* -Size 50GB -FriendlyName "Volume01" `
    -ResiliencySettingName Mirror -ProvisioningType Thin
```
_______________

#### Optional - Create a mirror-accelerated parity volume

> **NOTE** - This can only be perfomed on clusters with **4 or more nodes**. If you deployed less than 4 nodes, skip this optional step.

Mirror-accelerated parity reduces the footprint of the volume on the HDD. For example, a three-way mirror volume would mean that for every 10 terabytes of size, you will need 30 terabytes as footprint. To reduce the overhead in footprint, create a volume with mirror-accelerated parity. This reduces the footprint from 30 terabytes to just 22 terabytes, even with only 4 servers, by mirroring the most active 20 percent of data, and using parity, which is more space efficient, to store the rest. You can adjust this ratio of parity and mirror to make the performance versus capacity tradeoff that's right for your workload. For example, 90 percent parity and 10 percent mirror yields less performance but streamlines the footprint even further.

1. Still in **Windows Admin Center**, on the Volumes page, select the **Inventory** tab, and then select **Create**
2. In the **Create volume** pane, enter **Volume02_PAR** for the volume name, and set **Resiliency** as **Mirror-accelerated parity**
3. In **Parity percentage**, set the percentage of parity to **80% parity, 20% mirror**
4. In Size on HDD, specify **50GB** for the size of the volume.
5. Expand **More options** and under **Provision as**, select **Thin**.
6. Leave the remaining defaults and then click **Create**.

![Create a volume on Azure Stack HCI](/modules/module_2/media/create_volume_par.png "Create a volume on Azure Stack HCI")

_________________

In order to perform the same task with **PowerShell**, you can run the following command:

```powershell
$ClusterName = "AzSHCI-Cluster"
New-Volume -CimSession $ClusterName -FileSystem CSVFS_ReFS `
    -StoragePoolFriendlyName S2D* -Size 50GB -FriendlyName "Volume02_PAR" `
    -ResiliencySettingName Parity -ProvisioningType Thin
```
_________________

For more information on planning volumes with Azure Stack HCI, you should [refer to the official docs](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/plan-volumes "Planning volumes for Azure Stack HCI 21H2").

#### Deduplication and compression
In addition to the options during creation time, you also have the ability to enable deduplication and compression for your new volumes.

1. Still in **Windows Admin Center**, on the Volumes page, select the **Inventory** tab, and then select your **Volume01** volume
2. On the Volume Volume01 pane, you'll see a simple rocker switch to enable **Deduplication and compression**.  Click to enable it, and click **Start**

![Enable deduplication on volume](/modules/module_2/media/wac_enable_dedup.png "Enable deduplication on volume")

3. In the **Enable deduplication** pane, use the drop-down to select **Hyper-V** then click **Enable Deduplication**. This should be enabled quickly, as there's no files on the volume.

> **NOTE** - You'll notice there there are 3 options; default, Hyper-V and Backup.  If you're interested in learning more about Deduplication in Azure Stack HCI 21H2, you should [refer to our documentation](https://docs.microsoft.com/en-us/azure-stack/hci/manage/volume-encryption-deduplication "Deduplication overview")

________________
In order to perform the same task with **PowerShell**, you can run the following command:

```powershell
Invoke-Command -ComputerName AZSHCI1 -ScriptBlock {
    Enable-DedupVolume -Volume "C:\ClusterStorage\Volume01" `
        -UsageType HyperV
}
```
_______________

You'll also notice that you can enable **BitLocker**. This will encrypt the volume and provides options as to where to store the recovery password - including in Active Directory. If you wish to store the encrption key locally, you can enable BitLocker with PowerShell. You can [read more about BitLocker on Azure Stack HCI here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/bitlocker-on-csv).

Finally, you can turn on **Integrity checksums** - an optional feature that protects your data against file corruptions and long-term degradation. This can only be turned on or off at creation time. You can [read more about integrity checksums here](https://docs.microsoft.com/en-us/windows-server/storage/refs/integrity-streams).

You now have a couple of volumes created and ready to accept workloads.  Whilst we deployed the volumes using the Windows Admin Center, you can also do the same through PowerShell.  If you're interested in taking that approach, [check out the official docs that walk you through that process](https://docs.microsoft.com/en-us/azure-stack/hci/manage/create-volumes "Official documentation for creating volumes")

Explore Cluster-wide settings
---------
With the initial storage settings defined and test volumes created, it's time to explore some of the cluster-specific settings.

![Cluster settings in Windows Admin Center](/modules/module_2/media/cluster_settings.png "Cluster settings in Windows Admin Center")

1. In **Windows Admin Center**, click **Settings** and under **Cluster**, you'll notice a number of menu options.
2. Click on **Access point** - this is the name of your Azure Stack HCI cluster.
3. Click on **Node shutdown behaviour** - when the node is shutdown gracefully, this setting determines if virtual machines will be live migrated to other available nodes, or shutdown/saved.
4. Click on * **Cluster traffic encryption**, and then **view them on our new Security tool** - here, you can optionally change the way that traffic between cluster nodes is protected.

![Cluster security settings in Windows Admin Center](/modules/module_2/media/cluster_encryption.png "Cluster security settings in Windows Admin Center")

> By default, all communication between the nodes are sent **signed**, making the use of **certificates**. This may be fine when all the cluster nodes reside in the same rack. However, when nodes are separated in different racks or locations, you may wish to have a little more security and make use of encryption. For storage traffic between nodes, you have both Cluster Shared Volumes (CSV) and Storage Bus Layer (SBL) traffic. For these type of traffic, the default is to send everything in clear text. You may wish to secure this type of data traffic to prevent sniffer traces from accessing the data. Naturally, You should note that there is a notable performance operating cost with any end-to-end encryption protection when compared to non-encrypted. You can [read more about the use of encryption for cluster network traffic here](https://docs.microsoft.com/en-us/windows-server/storage/file-server/smb-direct#smb-encryption-with-smb-direct).

5. Click back to **Settings** and then **Virtual machine load balancing** - this allows you to configure the Azure Stack HCI cluster to **automatically** live migrate virtial machines around the cluster based on the CPU utilization and memory pressure of the Azure Stack HCI nodes themselves, helping to balance performance and resource usage across the cluster.  You can [read more about virtual machine load balancing here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/vm-load-balancing).
6. You can skip **Witness** as this was configured in a previous scenario. Click **Affinity rules**.

![Affinity rules in Windows Admin Center](/modules/module_2/media/affinity_rules.png "Affinity in Windows Admin Center")

> **Affinity** is a rule that establishes a relationship between two or more resource groups or roles, such as virtual machines, to keep them together on the same server, cluster, or site. **Anti-affinity** is the opposite in that it is used to keep the specified VMs or resource groups apart from each other, such as two domain controllers placed on separate servers or in separate sites for disaster recovery.

________________
We do not yet have any virtual machines running on our cluster, but in order to create an affinity rule with **PowerShell**, you could run the following command to ensure a pair of SQL Server VMs run on different physical Azure Stack HCI nodes:

```powershell
New-ClusterAffinityRule -Name SQL -Ruletype DifferentNode -Cluster Cluster1
Add-ClusterGroupToAffinityRule -Groups SQL1,SQL2 –Name SQL -Cluster Cluster1
Set-ClusterAffinityRule -Name SQL -Enabled 1 -Cluster Cluster1
```
_______________

Explore Hyper-V Host settings
---------
Next, we'll review the settings that apply specifically to Hyper-V hosts.

![Hyper-V Host settings in Windows Admin Center](/modules/module_2/media/hyper-v_host_settings.png "Hyper-V Host settings in Windows Admin Center")

1. Under **General**, you have the opportunity to change the default paths for storing Azure Stack HCI artifacts such as virtual hard disks and virtual machine configuration paths. Next to **Virtual Hard Disk Path**, click **Browse**.
2. In the **Select the virtual hard disks path** blade, click the **Up** button until you are at the **root C:\\**, then navigate to **C:\\ClusterStorage\\Volume01**. Click **New Folder** and create a **VMs** folder.
3. Once the new folder is created, double-click the **VMs** folder to enter the directory, then click **New Folder** to create a folder named **VHDs**.
4. Once created, click the **VHDs** folder, then click **OK**.
5. Next to **Virtual Machines Path**, click **Browse**.
6. In the **Select the virtual machines path** blade, click the **Up** button until you are at the **root C:\\**, then navigate to **C:\\ClusterStorage\\Volume01**. Click **VMs** and click **OK**.
7. Back on the **General** page, click **Save**.

![Hyper-V Host folder settings in Windows Admin Center](/modules/module_2/media/vms_folder.png "Hyper-V Host folder settings in Windows Admin Center")

> You can optionally choose to change the **Hypervisor Scheduler Type** but it's recommended that you leave it set to the default **Core Scheduler** - You can [read more about the hypervisor scheduler types here](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/about-hyper-v-scheduler-type-selection) and also [here](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-scheduler-types).

8. Click on **Enhanced Session Mode** - allow redirection of local devices and resources from virtual machines, **tick the box to allow enhanced session mode**, then click **Save**. Note that enhanced session mode connections require a supported guest operating system.
9. Click on **NUMA Spanning**. By enabling Non-uniform memory architecture (NUMA) spanning, you can provide a virtual machine with more memory than what is available on a single NUMA node, which helps to increase the **scalability** of your system to accommodate more virtual machines, however, it *may* decrease performance.
10. Click on **Live Migration** - here, you can choose to enable/disable live migrations of running virtual machines between Azure Stack HCI cluster nodes. In addition, you can choose to control the maximum number of **simultaneous** live migrations, and desired authentication and performance settings:

![Hyper-V Host live migration settings in Windows Admin Center](/modules/module_2/media/live_migration.png "Hyper-V Host live migration settings in Windows Admin Center")

> You have 2 options for authentication when initializing a live migration - either use **CredSSP**, which is the default, and requires the migration to be initialized *from* the source host, or **Kerberos** authentication, which is more secure, but does require some additional configuration of **Constrained Delegation** in **Active Directory** - you can read about [setting up Constrained Delegation here](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/deploy/set-up-hosts-for-live-migration-without-failover-clustering#BKMK_Step1)

> Secondly, you can choose a preferred performance option. **Compression** is the default, which involves using some host resources to compress the memory of a VM before sending over the network. You can revert back to the older, slower **TCP/IP migration**, or, with appropriate **RDMA network adapters** for your live migration networks, you can use the **SMB** live migration type, which offers the highest performance. 

________________
We do not yet have any virtual machines running on our cluster, but in order to configure the live migration settings with **PowerShell**, you could run the following example commands on **each** Azure Stack HCI node:

```powershell
Enable-VMMigration
Set-VMMigrationNetwork 192.168.10.1

# Set authentication type as CredSSP/Kerberos
Set-VMHost -VirtualMachineMigrationAuthenticationType Kerberos

# Set performance option as SMB/Compression/TCPIP
Set-VMHost -VirtualMachineMigrationPerformanceOption SMB
```

You can also optionally disable end-to-end encryption of SMB data to deliver higher migration speeds:
```powershell
Set-SmbServerConfiguration -EncryptData $false `
-RejectUnencryptedAccess $false
```
_______________

11. Finally, click **Storage Migration** - here, you can specify the number of **simultaneous live storage migrations** can be performed.

Deploy your first virtual machine
---------
In this step, you'll deploy a VM onto your storage volume you created earlier.

### Create the virtual machine
You should still be in **Windows Admin Center** for the next steps.

1. Once logged into **Windows Admin Center**, on the left hand navigation, under **Compute** select **Virtual machines**.  The central **Virtual machines** page shows you no virtual machines deployed currently
2. On the **Virtual machines** page, select the **Inventory** tab, and then select **Add**, then select **New**.
3. In the **New virtual machine** pane, enter **VM001** for the name, and enter the following pieces of information, then click **Create**

    * Generation: **Generation 2 (Recommended)**
    * Host: **Leave as recommended**
    * Path: **Should default to C:\ClusterStorage\Volume01\VMs**
    * Virtual processors: **1**
    * Startup memory (GB): **0.5**
    * Network: **ComputeStorage Team**
    * Storage: **Add, then Create an empty virtual hard disk** and set size to **5GB**
    * Operating System: **Install an operating system later**

4. The creation process will take a few moments, and once complete, **VM001** should show within the **Virtual machines view**
5. Click on the **VM** and then click **Power** and then **Start** - within moments, the VM should be running (click refresh if required)

![VM001 up and running](/modules/module_2/media/wac_vm001.png "VM001 up and running")

7. Click on **VM001** to view the properties and status for this running VM
8. Click on **Connect** - you may get a **VM Connect** prompt:

![Connect to VM001](/modules/module_2/media/vm_connect.png "Connect to VM001")

9. Click on **Go to Settings** and in the **Remote Desktop** pane, click on **Allow remote connections to this computer**, then **Save**
10. Click the **Back** button in your browser to return to the VM001 view, then click **Connect**, and when prompted with the certificate prompt, click **Connect** and enter appropriate credentials
11. There's no operating system installed here, so it should show a UEFI boot summary, but the VM is running successfully
12. Click **Disconnect**

You've successfully created a VM using **Windows Admin Center**! In order to perform the same task using PowerShell, you could run the following commands:

```powershell
# Create the new virtual machine
New-VM -ComputerName AZSHCI1 -Name VM001 -MemoryStartupBytes 512MB `
    -BootDevice VHD -NewVHDSizeBytes 5GB `
    -NewVHDPath "C:\ClusterStorage\Volume01\VMs\VHDs\VM001.vhdx" `
    -Generation 2 -Switch "ComputeStorage Team"

# Update the vCPU information
Set-VM -ComputerName AZSHCI1 -Name VM001 -ProcessorCount 1

# Cluster the VM for high availability
Add-ClusterVirtualMachineRole -VirtualMachine VM001 `
    -Cluster "AzSHCI-Cluster"
```

### Live migrate the virtual machine ###
The final step we'll cover is using Windows Admin Center to live migrate VM001 from it's current node, to an alternate node in the cluster.

1. Still within the **Windows Admin Center** , under **Compute**, click on **Virtual machines**
2. On the **Virtual machines** page, select the **Inventory** tab
3. You'll be able to see through the default grouping, which Azure Stack HCI node the VM is currently running on - make a note of this.
4. Next to **VM001**, click the tick box next to VM001, then click **Manage**.  You'll notice you can Clone, Domain Join and also Move the VM. Click **Move**.

![Start Live Migration using Windows Admin Center](/modules/module_2/media/wac_move.png "Start Live Migration using Windows Admin Center")

5. In the **Move Virtual Machine** pane, ensure **Failover Cluster** is selected, and leave the default **Best available cluster node** to allow Windows Admin Center to pick where to migrate the VM to, then click **Move**

![Live Migration using Windows Admin Center](/modules/module_2/media/wac_move2.png "Live Migration using Windows Admin Center")

> If no **Member server** is shown in the drop down, change the **destination type** to **Server** and then back to **Failover Cluster** and it should refresh.

6. The live migration will then begin, and within a few seconds, the VM should be running on a different node.
7. On the left hand navigation, under **Compute** select **Virtual machines** to return to the VM dashboard view, which aggregates information across your cluster, for all of your VMs.

### Explore the VM settings
With a VM deployed and migrated, you should take a few minutes to review the settings associated with a virtual machine.

1. On the **Virtual machines** page, under **Inventory**, click on VM001.
2. On the **VM001** properties page, you can now see a wealth of information about this VM across general properties, checkpoints (snapshots) and storage/networks.
3. Click on **Power** and then **Turn off**, confirming when prompted. This will ensure that as we explore the different VM settings shortly, all options are available to us, as some settings are not available while VMs are running.
4. Click on **Settings**.
5. 