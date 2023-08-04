Hybrid Jumpstart | Azure Prerequisites
==========

Overview <!-- omit in toc -->
--------

In addition to your infrastructure requirements, the hybrid solutions covered in this jumpstart also require access to an **Azure subscription**, and **Azure Active Directory Tenant**. You must also have certain permissions at both the subscription and AAD tenant levels, otherwise some of the steps in the hands-on-labs will not work. This section will cover all the prerequisites you need to successfully complete the different hands-on-labs.

Section duration <!-- omit in toc -->
-------------
10 Minutes

Contents <!-- omit in toc -->
--------
- [Hybrid Jumpstart | Azure Prerequisites](#hybrid-jumpstart--azure-prerequisites)
  - [Get an Azure subscription](#get-an-azure-subscription)
  - [Azure subscription \& Azure Active Directory permissions](#azure-subscription--azure-active-directory-permissions)
  - [Firewall / Proxy Configuration](#firewall--proxy-configuration)
  - [Next steps](#next-steps)
  - [Raising issues](#raising-issues)

Get an Azure subscription
-----------
As mentioned earlier, to evaluate the different hybrid solutions, you'll need an Azure subscription. If you already have one provided by your company, you can skip this step, but if not, you have a couple of options.

The first option would apply to Visual Studio subscribers, where you can use Azure at no extra charge. With your monthly Azure DevTest individual credit, Azure is your personal sandbox for dev/test. You can provision virtual machines, cloud services, and other Azure resources. Credit amounts vary by subscription level, but if you manage your usage efficiently, you can test the scenarios well within your subscription limits.

The second option would be to sign up for a [free trial](https://azure.microsoft.com/en-us/free/ "Azure free trial link"), which gives you $200 credit for the first 30 days, and 12 months of popular services for free.

*******************************************************************************************************

**NOTE** - The free trial subscription provides $200 for your usage, however the largest individual VM you can create is capped at 4 vCPUs, which is **not** enough to run this jumpstart environment if you choose to deploy the hands-on-labs within a single Azure VM. Once you have signed up for the free trial, you can [upgrade this to a pay as you go subscription](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription "Upgrade to a PAYG subscription") and this will allow you to keep your remaining credit ($200 to start with) for the full 30 days from when you signed up. You will also be able to deploy VMs with greater than 4 vCPUs.

*******************************************************************************************************

Azure subscription & Azure Active Directory permissions
-----------
Depending on the particular module and hands-on-lab, the permissions required for both the Azure subscription and AAD tenant may vary. Below is a table summarizing the different permissions that are required for the main modules in the course. These permissions will also be available at the start of each hands-on-lab.

| Module | Topic | Subscription Permissions | AAD Permissions |
|:--|---|---|---|
| 2 | Azure Stack HCI | Owner / User Access Administrator + Contributer / Custom | Not required
| 3 | AKS hybrid | Owner / Custom Service Principal | Global Admin / Cloud Application Administration / Custom


Firewall / Proxy Configuration
-----------
If you are deploying the infrastructure on your own physical hardware, you may need to request access to certain extternal resources with your network team. The following links provide guidance on the specific endpoints that need to be accessible for the different modules and hands-on-labs:

| Module | Topic | Firewall/Proxy requirements
|:--|---|---|
| 2 | Azure Stack HCI | [Host requirements](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements)
| 2 | Azure Stack HCI | [Arc-enabled Servers requirements](https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#networking-configuration)
| 3 | AKS hybrid | [AKS hybrid](https://docs.microsoft.com/en-us/azure-stack/aks-hci/system-requirements#network-port-and-url-requirements)
| 3 | AKS hybrid | [Arc-enabled Kubernetes requirements](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#meet-network-requirements)

With the Azure requirements and prerequisites reviewed, it's time to begin your deployment of the lab environment.

Next steps
-----------
Based on your available hardware, choose one of the following options:

- **Lab Deployment on Physical Hardware** - If you've got your own **suitable hardware**, proceed on to [deploy the hybrid jumpstart on your physical hardware](/modules/module_0/4_physical_deployment.md).
- **Lab Deployment in Azure** - If you're choosing to deploy with an **Azure virtual machine**, head on over to the [Azure VM deployment guidance](/modules/module_0/3_azure_vm_deployment.md).

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!