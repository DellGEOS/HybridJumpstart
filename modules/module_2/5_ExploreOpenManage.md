Module 2 | Scenario 5 - Exploring Dell OpenManage Integration with Microsoft Windows Admin Center
============

Overview <!-- omit in toc -->
------------

So far in this jumpstart, you've learned how to deploy an Azure Stack HCI cluster, deployed and configured storage, deployed a VM, and explored some of the key settings and configuration options for your Azure Stack HCI environment. So far however, the configuration has focused on the Azure Stack HCI operating system itself. In this scenario, you'll explore how enable and configure the Dell OpenManage Integration with Windows Admin Center.

If you're not already familiar, the Dell OpenManage Integration with Windows Admin Center extension enables streamlined lifecycle management at the **physical server level** for the following platforms:

* Azure Stack HCI clusters running on AX nodes - part of the Dell Integrated System for Microsoft Azure Stack HCI portfolio
* Storage Spaces Direct Ready Nodes - part of the Dell HCI Solutions for Microsoft Window Server and Hyper-V portfolio
* Standalone or Failover clusters based on PowerEdge servers.

The goal of the integration is simple; simplify the tasks of IT administrators by remotely managing Dell Intergrated Systems for Microsoft Azure Stack HCI Solutions along with PowerEdge servers and clusters throughout their life cycle.

Scenario duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
-----------
- [Before you begin](#before-you-begin)
- [Installing the OMIMSWAC Extension](#installing-the-omimswac-extension)
- [Infrastructure health](#infrastructure-health)
- [Inventory](#inventory)
- [iDRAC information](#idrac-information)
- [Security](#security)
- [Compute resources and cluster expansion](#compute-resources-and-cluster-expansion)
- [Update management](#update-management)
- [Other settings](#other-settings)
- [Next Steps](#next-steps)
- [Raising issues](#raising-issues)


Before you begin
-----------
__________________
**IMPORTANT NOTE** - The Dell OpenManage Integration with Microsoft Windows Admin Center (OMIMSWAC) **requires** physical hardware - it will not work in a nested virtualization environment, both in Azure, or on-premises in your own environment. The steps below are for your reference, and the accompanying video will demonstrate some of the core functionality of the solution.
__________________

Aside from physical servers, you will also need to ensure that you are correctly **licensed** to use the Dell OpenManage Integration with Microsoft Windows Admin Center extension. OMIMSWAC is available for free with basic management features enabled for all supported devices or licensed for advanced lifecycle management with a premium license for systems with an iDRAC9.

The premium license for OMIMSWAC is **included** with the Dell Integrated System for Microsoft Azure Stack HCI AX nodes.

You can [read more about licensing here](https://www.dell.com/support/kbdoc/en-us/000177828/support-for-dell-emc-openmanage-integration-with-microsoft-windows-admin-center#OMIMSWAC-Licensing).

There is also a **30-day free trial** available to fully test and experience all the features, with [more information available here](https://www.dell.com/support/kbdoc/en-us/000176472/idrac-cmc-openmanage-enterprise-openmanage-integration-with-microsoft-windows-admin-center-openmanage-integration-with-servicenow-and-dpat-trial-licenses)

Installing the OMIMSWAC Extension
-----------
Before you can configure the OpenManage integration, you first need to install the extension in Windows Admin Center.

1. If you're not already logged in, open your web browser, and navigate to your Windows Admin Center web console.
2. Once logged in, in the top-right hand corner, click the **gear icon** to enter **settings**.
3. Under **Gateway**, click **Extensions**, enter **Dell** into the search box:

![Dell extensions for Windows Admin Center](/modules/module_2/media/WAC_extensions.png "Dell extensions for Windows Admin Center")

4. In the results, select **Dell OpenManage Integration** and select **Install**. This will take a few moments, and once complete, Windows Admin Center will automatically refresh.
5. Navigate back to the Windows Admin Center landing page, and under **All connections**, select your Azure Stack HCI cluster, and log in if required.
6. On the left-hand navigation, towards the bottom, under **Extensions** you should see the newly installed **Dell OpenManage** extension present.

![Dell OpenManage extension for Windows Admin Center installed](/modules/module_2/media/wac_extension_installed.png "Dell OpenManage extension for Windows Admin Center installed")

7. Read the customer notice, then select the **I Accept the terms of the Dell Software Agreement** checkbox, then click **Accept**.
8. The extension will then attempt to communicate with your Azure Stack HCI nodes.

> You may receive an error relating to **Secured-core**, with a few suggestions to fix. Most likely, it's related to credentials. Navigate to the **Security tab** and provide run-as credentials.

![Credentials for the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_openmanage_creds.png "Credentials for the Dell OpenManage extension for Windows Admin Center")

You have now successfully installed the OpenManage integration with Windows Admin Center, so you can move on to exploring some of the core extension capabilities.

![Dell OpenManage extension for Windows Admin Center successfully configured](/modules/module_2/media/wac_extension_configured.png "Dell OpenManage extension for Windows Admin Center successfully configured")

Infrastructure health
-----------
With the OpenManage integration with Windows Admin Center successfully installed, the first key tab to explore is the **Health** tab. This dashboard provides you with a high level overview of key health metrics for your physical Azure Stack HCI nodes, including:

* CPUs
* Accelerators
* Memory
* Storage Controllers
* Storage Enclosures
* Physical Disks
* iDRAC
* Power Supplies
* Fans
* Voltages
* Temperatures

1. From within the the **Dell OpenManage** extension, click on the **Health** tab. Scroll down and review the different charts showing the health of the different system components.
2. Scroll back up and click on the donut chart for **Overall Health Status**
3. Once loaded, you'll see your Azure Stack HCI nodes listed. Expand one of the nodes to list all key system components and their health status:

![Infrastructure health in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_infra_health.png "Infrastructure health in the Dell OpenManage extension for Windows Admin Center")

4. Back on the **Health** dashboard, if you wish to see specific components, you can click on one of the donut charts for that particular category.

Inventory
-----------
The **system inventory** builds on what we've just observed in the health dashboard, providing you with details about the following components:

* System
* Firmware
* CPUs
* Memory
* Storage controllers
* Storage enclosures
* Network devices
* Physical disks
* Power supplies
* Fans

1. From within the the **Dell OpenManage** extension, click on the **Inventory** tab. 
2. You should see the nodes of your Azure Stack HCI cluster.

![Inventory information in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_dell_inventory.png "Inventory information in the Dell OpenManage extension for Windows Admin Center")

3. Click on one of your nodes. You will be presented with the different components that you can review. The example below shows the firmware view across all the different components:

![Inventory information in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_dell_inventory2.png "Inventory information in the Dell OpenManage extension for Windows Admin Center")

4. Click on **Physical Disks**. Here you can view the properties of all physical disks in that particicular node, and you have the ability to blink/unblink the drive LEDs.

![Inventory information in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_dell_inventory3.png "Inventory information in the Dell OpenManage extension for Windows Admin Center")

iDRAC information
-----------
For those of you not familiar, iDRAC stands for the **Integrated Dell Remote Access Controller**, which provides secure local and remote server management and helps IT administrators deploy, update and monitor Dell PowerEdge-based servers anywhere, anytime.

Through the Dell OpenManage Integration with Microsoft Windows Admin Center, you're able to view useful information about the iDRAC configuration across your Azure Stack HCI nodes, all from within Windows Admin Center.

1. From within the the **Dell OpenManage** extension, click on the **iDRAC** tab. 
2. You should see the nodes of your Azure Stack HCI cluster. Click on one of your nodes.
3. You can now view key iDRAC information such as the iDRAC IP address, licensing status and more.

![iDRAC information in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_idrac.png "iDRAC information in the Dell OpenManage extension for Windows Admin Center")

Security
-----------
When it comes to security in the Dell OpenManage extension, there are 2 key components - **Infrastructure Lock** and **Secured-core**.

### Infrastructure lock <!-- omit in toc -->
Infrastructure lock (also known as iDRAC lockdown mode or system lockdown mode) helps in preventing unintended changes after a system is provisioned. Infrastructure lock is applicable to both hardware configuration and firmware updates. When the infrastructure is locked, any attempt to change the system configuration is blocked. If any attempts are made to change the critical system settings, an error message is displayed. Enabling infrastructure lock also blocks the server or cluster firmware
update using the OpenManage Integration extension.

In the OpenManage extension dashboard, the icon the left to the server or cluster title name indicates the infrastructure lock status. The following are the possible status:

![Infrastructure lock in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_infra_lock.png "Infrastructure lock in the Dell OpenManage extension for Windows Admin Center")

> When the infrastructure lock is in place, you can still **retrieve health, inventory and iDRAC details**, and **blink/unblink server LEDs**. All other functionality is **disabled**.

1. From within the the **Dell OpenManage** extension, click on the **Security** tab, and then click on **Infrastructure Lock**. You'll be presented with the current status of the Infrastructure Lock.

![Infrastructure lock in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_infra_lock2.png "Infrastructure lock in the Dell OpenManage extension for Windows Admin Center")

2. To enable/disable the **infrastructure lock**, simply click **Enable/Disable**.

The extension will communicate with iDRAC, turns on the iDRAC Lockdown Mode, which prevents modification of the iDRAC settings to prevent misactions or malicious modifications.

### Secure your cluster with Secured-core <!-- omit in toc -->
A malicious attacker who has physical access to a system can tamper with the BIOS. Modified BIOS code poses a high security threat and makes the system vulnerable to further attacks.

Secured-core server combines hardware, firmware, and driver capabilities to further protect the operating environment - from the boot process through to data in memory. It's built on three key pillars:

* **Simplified security** - Certified OEM hardware for Secured-core server gives you the assurance that the hardware, firmware, and drivers meet the requirements for Secured-core server capabilities. Best of all, everything can be easily managed from Windows Admin Center.
* **Advanced protection** - Take advantage of multiple levels of protection within a Secured-core server - Hardware root-of-trust with TPM 2.0, Secure Boot with Dynamic Root of Trust for Measurement (DRTM), System Guard with Kernel Direct Memory Access (DMA) protection, along with Virtualization-based security (VBS) and Hypervisor-based code integrity (HVCI)
* **Preventative defense** - Enabling Secured-core functionality helps proactively defend against and disrupt many of the paths attackers may use to exploit a system. Secured-core server enables advanced security features at the bottom layers of the technology stack, protecting the most privileged areas of the system before many security tools would be aware of exploits with no additional tasks or monitoring needed by the IT and SecOps teams

You can [read more about Secured-core here](https://docs.microsoft.com/en-us/windows-server/security/secured-core-server).

To configure the Secured-core server, there's a few places to go as it involves enabling both BIOS and OS security features. Both Dell and Microsoft recommend to enable BIOS security features and OS security features respectively to protect your infrastructure from external threats. Fortunately, Windows Admin Center makes the whole process easy:

1. Still in Windows Admin Center, on the left-hand navigation, click on **Security**.
2. You'll be presented with a security dashboard. From the dashboard, click **Secured-core**.
3. As you can see, in our case, some of the requirements have not been met:

![Secured-core status in the Security extension in Windows Admin Center](/modules/module_2/media/wac_security.png "Secured-core status in the Security extension in Windows Admin Center")

4. Click on each of the items that have not been configured, and click **Enable**. It may take a few minutes to enable the features.
5. Once enabled, navigate to the **Dell OpenManage** extension, click on the **Security** tab, and then **Secured-core**. Enter your credentials if prompted.
7. After meeting the pre-requisites (correct platform, processor type, OS version, BIOS version, OMIMSWAC license), you'll be presented with an overall Secured-core status for both BIOS and the OS for the entire cluster.

![Secured-core status in the Dell OpenManage extension for Windows Admin Center](/modules/module_2/media/wac_secured_core.png "Secured-core status in the Dell OpenManage extension for Windows Admin Center")

8. You can optionally toggle the view for the **Node Level Details** to break down the information on a node-by-node basis.

Compute resources and cluster expansion
-----------

Update management
-----------


Other settings
-----------












Next Steps
-----------
In this step, you've successfully registered your Azure Stack HCI cluster. With this complete, you can now move on to:

* [**Module 2 | Scenario 4** - Explore some of the core management operations of your Azure Stack HCI environment](/modules/module_2/4_ManageAzSHCI.md "Explore the management of your Azure Stack HCI environment")

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!