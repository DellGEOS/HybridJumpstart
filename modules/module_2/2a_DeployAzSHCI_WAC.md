Hybrid Cloud Workshop - Module 2:2a - Deploying Azure Stack HCI with Windows Admin Center
============
In this section, you'll walk through deployment of an Azure Stack HCI cluster using Windows Admin Center. If you have a preference for deployment with PowerShell, head over to the [PowerShell cluster creation guidance](/modules/module_2/2b_DeployAzSHCI_PS.md).

Before you begin
-----------
With Windows Admin Center, you now have the ability to construct Azure Stack HCI clusters from the previously deployed nodes. There are no additional extensions to install, the workflow is built in and ready to go, however, it's worth checking to ensure that your Cluster Creation extension is fully up to date and make a few changes to the Edge browser to streamline things later.

Allow popups in Edge browser
-----------
To give the optimal experience with Windows Admin Center, you should enable **Microsoft Edge** to allow popups for Windows Admin Center.

1. If you're not already logged in, log into the **HybridWorkshop-DC** virtual machine, open the **Microsoft Edge icon** on your taskbar.
2. If you haven't already, complete the initial Edge configuration settings.
3. Navigate to **edge://settings/content/popups**
4. Click the slider button to **disable** pop-up blocking
5. Close the **settings tab**.

### Configure Windows Admin Center ###

During the [lab deployment earlier](/modules/module_0/4_mslab.md#step-5---installing-windows-admin-center), you installed the latest version of Windows Admin Center, however there are some additional configuration steps that must be performed before you can use it to deploy Azure Stack HCI.

1. In your Edge browser, **Double-click the Windows Admin Center** shortcut on the desktop.
2. Once Windows Admin Center is open, you may receive notifications in the top-right corner, indicating that some extensions are updating automatically. **Let these finish updating before proceeding**. Windows Admin Center may refresh automatically during this process.
3. Once complete, navigate to **Settings**, then **Extensions**
4. Click on **Installed extensions** and you should see **Cluster Creation** listed as installed

![Installed extensions in Windows Admin Center](/deployment/media/installed_extensions_cluster.png "Installed extensions in Windows Admin Center")

____________

**NOTE** - Ensure that your Cluster Creation extension is the **latest available version**. If the **Status** is **Installed**, you have the latest version. If the **Status** shows **Update available (1.#.#)**, ensure you apply this update and refresh before proceeding.

_____________