Module 2 | Scenario # - Exploring Azure Benefits on Azure Stack HCI
============

Overview <!-- omit in toc -->
------------

Microsoft Azure offers a range of differentiated workloads and capabilities that are designed to run only on Azure. Azure Stack HCI extends many of the same benefits you get from Azure, while running on the same familiar and high-performance on-premises or edge environments.

Azure Benefits makes it possible for supported Azure-exclusive workloads to work outside of the cloud. You can enable Azure Benefits on Azure Stack HCI at no extra cost. If you have Windows Server workloads, we recommend turning it on.

These benefits include:

* **Windows Server Datacenter: Azure Edition** - You have the option to run this Azure-only guest operating system on top of your Azure Stack HCI cluster, that includes all the latest Windows Server innovations and other exclusive features, including **Hotpatch**, giving you the ability to apply security updates on your VM without rebooting.
* **Extended Security Update (ESUs)** - A program that allows customers to continue to get security updates for End-of-Support SQL Server and Windows Server VMs, now free when running on Azure Stack HCI.
* **Azure Policy guest configuration** - A feature that can audit or configure OS settings as code, for both host and guest machines.

In this scenario, we'll explore each of these benefits through demonstration.

Scenario duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
-----------
- [Module 2 | Scenario # - Exploring Azure Benefits on Azure Stack HCI](#module-2--scenario----exploring-azure-benefits-on-azure-stack-hci)
  - [Before you begin](#before-you-begin)
  - [How it works](#how-it-works)
  - [Enable Azure Benefits](#enable-azure-benefits)
    - [Option 1 - Enable Azure Benefits using Windows Admin Center](#option-1---enable-azure-benefits-using-windows-admin-center)
    - [Option 2 - Enable Azure Benefits using PowerShell](#option-2---enable-azure-benefits-using-powershell)
    - [Exploring Azure benefits](#exploring-azure-benefits)


Before you begin
-----------
At this stage, you should have completed the previous sections of the jumpstart, [Scenario 2a - Clustering Azure Stack HCI with Windows Admin Center](/modules/module_2/2a_Cluster_AzSHCI_WAC.md) or [Scenario 2b - Clustering Azure Stack HCI with PowerShell](/modules/module_2/2a_Cluster_AzSHCI_PS.md) and have an Azure Stack HCI cluster successfully deployed, and you should have also followed the steps to register your Azure Stack HCI cluster during [Scenario 3 - Integrate Azure Stack HCI with Azure](/modules/module_2/3_Integrate_Azure.md).

As long as you have a registered cluster, you can follow along with the steps to configure the Azure benefits on Azure Stack HCI.

How it works
----------
Azure Benefits relies on a built-in platform attestation service on Azure Stack HCI, and helps to provide assurance that VMs are indeed running on Azure environments.

This service is modeled after the same IMDS Attestation service that runs in Azure, in order to enable some of the same workloads and benefits available to customers in Azure. Azure Benefits returns an almost identical payload. The main difference is that it runs on-premises, and therefore guarantees that VMs are running on Azure Stack HCI instead of Azure.

![Azure Benefits architecture](/modules/module_2/media/azure_benefits.png "Azure Benefits architecture")

1. On every server, HciSvc obtains a certificate from Azure, and securely stores it within an enclave on the server. Certificates are renewed every time the Azure Stack HCI cluster syncs with Azure, and each renewal is valid for 30 days. As long as you maintain the usual 30 day connectivity requirements for Azure Stack HCI, no user action is required.
2. HciSvc exposes a private and non-routable REST endpoint, accessible only to VMs on the same server. To enable this endpoint, an internal vSwitch is configured on the Azure Stack HCI host (named AZSHCI_HOST-IMDS_DO_NOT_MODIFY). VMs then must have a NIC configured and attached to the same vSwitch (AZSHCI_GUEST-IMDS_DO_NOT_MODIFY).

> Modifying or deleting this switch and NIC prevents Azure Benefits from working properly. If errors occur, disable Azure Benefits using Windows Admin Center or the PowerShell instructions that follow, and then try again.

3. Consumer workloads (for example, Windows Server Azure Edition guests) request attestation. HciSvc then signs the response with an Azure certificate.

Enable Azure Benefits
----------
Enabling the Azure Benefits is easy, but there are some prerequisites to meet first:

* Azure Stack HCI 21H2, with at least the December 14, 2021 security update KB5008223 or later.
* All servers must be online and registered to Azure.
* Install Hyper-V and RSAT-Hyper-V-Tools
* Windows Admin Center (version 2103 or later) with Cluster Manager extension (version 2.41.0 or later).

With those prereqs met, you can choose to enable the Azure Benefits either using Windows Admin Center, or with PowerShell. We'll walk through and demonstrate both options.

### Option 1 - Enable Azure Benefits using Windows Admin Center
Enabling Azure Benefits using Windows Admin Center takes just a few clicks. Follow the steps below to work through enabling them.

1. On **HybridJumpstart-DC**, logged in as **dell\labadmin**, in your edge browser, navigate to **https://wacgw/** to open Windows Admin Center, and on the **All connections** page, select your azshci-cluster.
2. Log in to the azshci-cluster with your dell\labadmin credentials, should you be prompted.
3. Once logged in, in the bottom-left corner of Windows Admin Center, click **Settings**.
4. On the **Settings** page, scroll down and under Azure Stack HCI, click on **Azure Benefits**.

![Selecting Azure Benefits in Windows Admin Center](/modules/module_2/media/azure_benefits_menu.png "Selecting Azure Benefits in Windows Admin Center")

5. You may need to scroll up the page again, once you've selected Azure Benefits.

![Selecting Azure Benefits in Windows Admin Center](/modules/module_2/media/azure_benefits_splash.png "Selecting Azure Benefits in Windows Admin Center")

6. When the **Turn on Azure benefits for this cluster** blade opens, click **Turn on**. Azure benefits will then be enabled, which will take a few moments.

### Option 2 - Enable Azure Benefits using PowerShell
Enabling Azure Benefits using PowerShell is quick, and is just a few commands. Follow the steps below to work through enabling them.

1. On **HybridJumpstart-DC**, logged in as **dell\labadmin**, open up a **PowerShell console as Administrator** then run the following command:

```powershell
# Remotely enable Azure Benefits
$ClusterName = "AzSHCI-Cluster"
Enable-AzStackHCIAttestation -ComputerName $ClusterName -Force
```
![Enable Azure Benefits with PowerShell](/modules/module_2/media/azure_benefits_enable_ps.png "Enable Azure Benefits with PowerShell")

2. With Azure benefits successfully enabled, use the following command to check the status:

```powershell
# Get cluster node names
$ClusterNodeNames = (Get-ClusterNode -Cluster $ClusterName).Name
Invoke-Command -ComputerName $ClusterNodeNames -ScriptBlock {
    Get-AzureStackHCIAttestation
}
```

![Azure Benefits enabled with PowerShell](/modules/module_2/media/azure_benefits_enabled_ps_status.png "Azure Benefits enabled with PowerShell")

3. Also, check the overall registration status:

```powershell
# Check overall registration
Invoke-Command -ComputerName $ClusterName -ScriptBlock {
    Get-AzureStackHCI
}
```

![Azure Benefits enabled with PowerShell](/modules/module_2/media/azure_benefits_enabled_ps.png "Azure Benefits enabled with PowerShell")

4. To enable Azure benefits on **VM001**, run the following command:

```powershell
Add-AzStackHCIVMAttestation VM001
```

![Azure Benefits enabled for VM001 with PowerShell](/modules/module_2/media/azure_benefits_enabled_ps_vm.png "Azure Benefits for VM001 enabled with PowerShell")

You can explore some of the other commands available to enable/disable Azure benefits [in the official documentation](https://docs.microsoft.com/en-us/azure-stack/hci/manage/azure-benefits#option-2-turn-on-azure-benefits-using-powershell).

### Exploring Azure benefits
With Azure benefits enabled, either with PowerShell, or with Windows Admin Center, it's worth taking a few minutes to explore the results of enabling it on your Azure Stack HCI cluster, and on VM001.

1. If you're not already in Windows Admin Center, navigate to **https://wacgw/** to open Windows Admin Center, and on the **All connections** page, select your azshci-cluster.
2. Log in to the azshci-cluster with your dell\labadmin credentials, should you be prompted.
3. Once logged in, in the bottom-left corner of Windows Admin Center, click **Settings**.
4. On the **Settings** page, scroll down and under Azure Stack HCI, click on **Azure Benefits**.
5. The Azure benefits page should refresh (you may need to scroll up), and you should see a summary of your status. Click on **Cluster** to see your enabled nodes.

![Azure Benefits enabled in Windows Admin Center](/modules/module_2/media/azure_benefits_enabled_cluster.png "Azure Benefits enabled in Windows Admin Center")

> The expiration date will automatically extend as the nodes/cluster sync with Azure. This has to happen at least once every 30 days to continue using Azure benefits. To extend this date manually, you can either click **Sync with Azure**, or run **Sync-AzureStackHCI** with PowerShell.

6. Click on **VMs** to view individual details about the VMs that have been enabled with Azure benefits on this specific cluster.

![VMs under Azure Benefits in Windows Admin Center](/modules/module_2/media/azure_benefits_enabled_VMs.png "VMs under Azure Benefits in Windows Admin Center")

> You can turn on and off Azure benefits for individual VMs.

7. On the left-hand navigation, click on **Virtual switches**. Here you can see the extra **internal** virtual switch, named **AZSHCI_HOST-IMDS_DO_NOT_MODIFY** that has been enabled on each node in the cluster, to facilitate the Azure benefits solution.

![Virtual switches for Azure Benefits in Windows Admin Center](/modules/module_2/media/azure_benefits_vswitch.png "Virtual switches for Azure Benefits in Windows Admin Center")

To perform this with PowerShell, you can run the following command:

```powershell
$ClusterNodeNames = (Get-ClusterNode -Cluster $ClusterName).Name
Get-VMSwitch -CimSession $ClusterNodeNames
```

8. Click on **Virtual machines**, then click on **VM001**. Scroll down to **Related** and on the right-hand side, click on **Networks**. Here you can see the VM will also have been given an additional virtual network adapter that is attached to the vSwitch shown earlier.

![Virtual NIC for Azure Benefits in Windows Admin Center](/modules/module_2/media/azure_benefits_vnic.png "Virtual NIC for Azure Benefits in Windows Admin Center")

To perform this with PowerShell, you can run the following command:

```powershell
$ClusterName = "AzSHCI-Cluster"
Invoke-Command -ComputerName $ClusterName -ScriptBlock {
        Get-VMnetworkadapter -VMName VM001 | FT Name, VMName, SwitchName
    }
```

9. You can also view a new Host virtual network adapter that's used by the Azure benefits infrastructure. In the left-hand navigation, click on **Servers**, then **Inventory**.
10. Tick the box next to **AzSHCI1**, then click **Manage**

![Server inventory in Windows Admin Center](/modules/module_2/media/azure_benefits_manage_server.png "Server inventory in Windows Admin Center")

11. In the left hand navigation, click on **Networks**, and you'll see a list of network adapters in this Azure Stack HCI host, including the Azure-benefits-specific AZSHCI_HOST-IMDS_DO_NOT_MODIFY network adapter.

![Networks for AzSHCI1 in Windows Admin Center](/modules/module_2/media/azure_benefits_networks_wac.png "Networks for AzSHCI1 in Windows Admin Center")

To perform this with PowerShell, you can run the following command:

```powershell
Get-NetAdapter -CimSession AzSHCI1 | Sort-Object Name | `
    FT Name, InterfaceDescription, Status
```

12. Still on On **HybridJumpstart-DC**, open a new tab in Edge, and navigate to **https://portal.azure.com**, logging in when prompted.
13. Under Azure Services, click on **Azure Stack HCI** (if you don't see this, use the search at the top to find Azure Stack HCI), then click on your **AzSHCI-Cluster** cluster.
14. On the left-hand navigation, click on **Configuration**.
15. Here, you should see that the Azure benefits show as enabled in the Azure portal.

![Azure benefits in the Azure portal](/modules/module_2/media/azure_benefits_enabled_portal.png "Azure benefits in the Azure portal")

