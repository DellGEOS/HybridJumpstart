Hybrid Jumpstart | Infrastructure Prerequisites
==========

Overview <!-- omit in toc -->
--------
In this section, we'll review the infrastructure requirements to participate in the Hybrid Jumpstart. You'll have a choice of either deploying on physical hardware if you have any available, or, if you prefer, inside an Azure virtual machine. In either case, you'll be set up to explore some of the key capabilities within the hybrid portfolio.

Section duration <!-- omit in toc -->
-------------
20 Minutes

Contents <!-- omit in toc -->
----------

- [Introduction](#introduction)
- [Nested Virtualization](#nested-virtualization)
- [Option 1 - Lab Deployment on Physical Hardware](#option-1---lab-deployment-on-physical-hardware)
  - [Architecture](#architecture)
  - [Will my hardware support this?](#will-my-hardware-support-this)
  - [Supported operating systems](#supported-operating-systems)
- [Option 2 - Lab Deployment in Azure](#option-2---lab-deployment-in-azure)
- [Next steps](#next-steps)
- [Raising issues](#raising-issues)

Introduction
----------

As previously discussed, the jumpstart is broken down into a number of modules and sub-modules that delve into deeper content around specific topics, such as Azure Stack HCI, Azure Arc and more.

Within each module, you'll find a mix of presentation to add extra context, alongside hands-on-lab guidance to help provide a guided and consistent way to experience the solutions first-hand.

In order to participate in the hands-on-labs, and follow along with the guided instructions in the jumpstart, you'll need an environment where you can deploy the virtualized infrastucture and hybrid workloads. For this, **you have a couple of options**:

- Single physical server/desktop/laptop
- Single Azure virtual machine

In each case, you'll be using **Nested Virtualization** which allows you to consolidate a full lab infrastructure down on to a single Hyper-V host, running on one of the 2 options above.

__________________________

### Important Note - Production Deployments <!-- omit in toc -->
The use of nested virtualization in this jumpstart is aimed at providing flexibility for evaluating the various hybrid solutions. For **production** use, **Azure Stack HCI and corresponding workloads should be deployed on validated physical hardware**, of which you can find the Dell Integrated System for Microsoft Azure Stack HCI on the [Azure Stack HCI Catalog](https://azurestackhcisolutions.azure.microsoft.com/#/catalog?Manufacturer=Dell+Technologies "Azure Stack HCI Catalog").
__________________________

Nested Virtualization
-----------
If you're not familiar with Nested Virtualization, at a high level, it allows a virtualization platform, such as Hyper-V, or VMware ESXi, to run virtual machines that, within those virtual machines, run a virtualization platform. It may be easier to think about this in an architectural view.

![Nested virtualization architecture](/modules/module_0/media/nested_virt.png "Nested virtualization architecture")

As you can see from the graphic, at the base layer, you have your physical hardware, onto which you install a hypervisor. In this case, for our example, we're using Windows Server with the Hyper-V role enabled, but this could also be Windows 10/11 with Hyper-V enabled. The hypervisor on the lowest level is considered L0 or the level 0 hypervisor. On that physical host, you create a virtual machine, and into that virtual machine, you deploy an OS that itself, has a hypervisor enabled.  In this example, that 1st Virtualized Layer is running a **nested** Azure Stack HCI operating system. This would be an L1 or level 1 hypervisor. Finally, in our example, inside Azure Stack HCI, you create a virtual machine to run a workload. This could in fact also contain a hypervisor, which would be known as the L2 or level 2 hypervisor, and so the process continues, with multiple levels of nested virtualization possible.

The use of nested virtualization opens up amazing opportunities for building complex scenarios on significantly reduced hardware footprints, however it shouldn't be seen as a substitute for real-world deployments, performance and scale testing etc.

Option 1 - Lab Deployment on Physical Hardware
-----------
In this section, we will cover the requirements for running the jumpstart on a physical system. This could be a single physical server, a workstation, desktop PC, or a laptop. Depending on the system resources available, you may not be able to deploy all components of the different hands-on-labs. We will discuss this in more detail below.

### Architecture
From an architecture perspective, the following graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for Azure Stack HCI nested on a physical system](/modules/module_0/media/nested_virt_physical.png "Architecture diagram for Azure Stack HCI nested on a physical system")

### Will my hardware support this?
If you're thinking about running this all on a laptop, it's certainly possible. Many modern laptops ship with powerful multi-core CPUs, and high-performance flash storage.  Neither of these components are likely to be a blocker to your evaluation; most likely memory will be the biggest consideration, but if we optimize accordingly, you can still deploy all of the key components and have a good experience.  Most laptops today support in excess of 16GB memory, but many ship with less.  For the purpose of this guide, your minimum recommended hardware requirements are:

* 64-bit Processor with Second Level Address Translation (SLAT).
* CPU support for VM Monitor Mode Extension (VT-x on Intel CPU's).
* 16GB memory
* 100GB+ SSD/NVMe Storage

The following items will need to be enabled in the system BIOS:

* Virtualization Technology - may have a different label depending on motherboard manufacturer.
* Hardware Enforced Data Execution Prevention.

### Important note for systems with AMD CPUs <!-- omit in toc -->
For those of you wanting to evaluate Azure Stack HCI in a nested configuration, with **AMD-based systems**, the only official way this is currently possible is to use **Windows 11 or Windows Server 2022** as your Hyper-V host. Your system should have AMD's 1st generation Ryzen/Epyc or newer CPUs. You can get more information on [nested virtualization on AMD here](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization#amd-epycryzen-processor-or-later "Nested virtualization on AMD-based systems").

If you can't run the Windows 11 or Windows Server 2022 on your AMD-based system, it may be a better approach to [deploy in Azure instead](#deployment-in-azure "Deployment in Azure").

### Verify Hardware Compatibility <!-- omit in toc -->
After checking the operating system and hardware requirements above, verify hardware compatibility in Windows by opening a PowerShell session or a command prompt (cmd.exe) window, typing **systeminfo**, and then checking the Hyper-V Requirements section. If all listed Hyper-V requirements have a value of **Yes**, your system can run the Hyper-V role. If any item returns No, check the requirements above and make adjustments where possible.

![Hyper-V requirements](/modules/module_0/media/systeminfo_upd.png "Hyper-V requirements")

If you run **systeminfo** on an existing Hyper-V host, the Hyper-V Requirements section reads:

```
Hyper-V Requirements: A hypervisor has been detected. Features required for Hyper-V will not be displayed.
```

With 16GB memory, running on a laptop, we'll need to ensure that we're taking advantage of features in Hyper-V, such as Dynamic Memory, to optimize the memory usage as much as possible, to ensure you can experience as much as possible on the system you have available.

**NOTE** When you configure your nested Azure Stack HCI nodes later, they will **require a minimum of 4GB RAM per node**, otherwise, they won't boot, so on a 16GB system, expect 2-3 nodes plus management infrastructure realistically - if you see the screenshot below, on a 16GB laptop, you'll see 2 Azure Stack HCI nodes, with DC01/MGMT01, with a little memory left over for the host.

![Azure Stack HCI cluster running on a laptop](/modules/module_0/media/azshci_laptop.png "Azure Stack HCI cluster running on a laptop")

Obviously, if you have a larger physical system, such as a workstation, or server, you'll likely have a greater amount of memory available to you, therefore you can adjust the memory levels for the different resources accordingly.

If your physical system doesn't meet these recommended requirements, you're still free to test, and see if you can proceed with lower numbers, but it may be a better approach to [deploy in Azure instead.](/modules/module_0/3_azure_vm_deployment.md "Deployment in Azure")

### Supported operating systems
For the purpose of this guide, you'll need to use one of the following operating systems (all of which support Hyper-V) on a [suitable piece of hardware](#will-my-hardware-support-this)

* Windows Server 2019 / 2022
* Windows 10 / 11 Pro
* Windows 10 / 11 Enterprise
* Windows 10 / 11 Education

**NOTE** - The Hyper-V role **cannot** be installed on Windows 10 / 11 Home.

We'll also assume that your physical host is fully up to date, but if not, now is a good time to check for updates:

1. Open the **Start Menu** and search for **Update**
2. In the results, select **Check for Updates**
3. In the Updates window, click **Check for updates**. If any are required, ensure they are downloaded and installed.
4. Restart if required, and once completed, log back into your physical system.

With the OS updated, and back online after any required reboot, you're now ready to continue.

Option 2 - Lab Deployment in Azure
-----------
If you do not have suitable physical hardware to run the lab infrastructure and hybrid workloads, one alternative is to run the environment inside an appropriately-sized Azure virtual machine.

From an architecture perspective, the following graphic showcases the different layers and interconnections between the different components:

![Architecture diagram for Azure Stack HCI nested in Azure](/modules/module_0/media/nested_virt_arch.png "Architecture diagram for Azure Stack HCI nested in Azure")

In this configuration, you'll take advantage of the nested virtualization support provided within certain Azure VM sizes.  You'll deploy a single Azure VM running Windows Server 2019 to act as your main Hyper-V host - in which you'll run the various hands-on-labs.

To reiterate, in this case the whole configuration will run **inside the single Azure VM**.

Next steps
-----------
Now that you understand the infrastructure requirements for the jumpstart, in the next step, we'll break down the different Azure requirements that need to be met in order to work through the various guides in the jumpstart.

Head over to review the **[Hybrid Cloud Jumpstart | Azure Prerequisites](/modules/module_0/2_azure_prerequisites.md)**

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!