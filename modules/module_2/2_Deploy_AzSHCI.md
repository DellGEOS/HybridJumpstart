Hybrid Cloud Workshop - Module 2:2 - Deploying Azure Stack HCI
============
In this section, you'll walk through deployment of an Azure Stack HCI cluster. You'll have a choice to deploy with either **Windows Admin Center** or **PowerShell**

Prerequisites
-----------
At this stage, you should already have a number of Azure Stack HCI nodes up and running, alongside a domain controller, and a management server, however, it's important to double check the **Azure prerequisites** to ensure you'll be able to proceed through the process detailed below.

* **Get an Azure subscription** - if you don't have one, read [more information here](/modules/module_0/2_azure_prerequisites.md#get-an-azure-subscription)
* **Azure subscription permissions** - Owner **or** User Access Administrator + Contributer **or** Custom ([Instructions here](https://docs.microsoft.com/en-us/azure-stack/hci/deploy/register-with-azure#azure-subscription-and-permissions))
* **Azure Active Directory permissions** - Global Admin **or** Cloud Application Administration **or** Custom ([Instructions here](https://docs.microsoft.com/en-us/azure-stack/hci/manage/manage-azure-registration#option-3-create-a-custom-active-directory-role-and-consent-policy))
* **Firewall / Proxy** - If you are running the environment inside your own lab, ensure that your lab deployment has access to all external resources listed below:
  * [Host requirements](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements)
  * [Arc-enabled Servers requirements](https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#networking-configuration)

Architecture
-----------

As shown on the architecture graphic below, in this step, you'll take the nodes that were previously deployed, and be **clustering them into an Azure Stack HCI cluster**. You'll be focused on **creating a cluster in a single site**.

![Architecture diagram for Azure Stack HCI nested](/modules/module_0/media/nested_virt_arch.png "Architecture diagram for Azure Stack HCI nested")

Deployment choices
-----------
Azure Stack HCI supports the creation of a cluster via **Windows Admin Center** or via **PowerShell**. We will detail both paths for your learning.

Next Steps
-----------
Select your deployment preference:

* [**Windows Admin Center**](/modules/module_2/2a_DeployAzSHCI_WAC.md)
* [**PowerShell**](/modules/module_2/2b_DeployAzSHCI_PS.md)

Raising issues
-----------
If you notice something is wrong with the workshop, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridWorkshop/issues), and we'll be sure to fix this as quickly as possible!