Module 2 - Scenario 3 - Register Azure Stack HCI with Azure
============

Overview <!-- omit in toc -->
------------

With your Azure Stack HCI cluster deployed successfully, you need to register this cluster to unlock full functionality. In this section, you'll walk through the steps required to register your cluster either via Windows Admin Center, or with PowerShell.

Scenario duration <!-- omit in toc -->
-------------
00 Minutes

Contents <!-- omit in toc -->
-----------
- [Module 2 - Scenario 3 - Register Azure Stack HCI with Azure](#module-2---scenario-3---register-azure-stack-hci-with-azure)
  - [Before you begin](#before-you-begin)
    - [Azure prerequisites](#azure-prerequisites)
    - [Understanding Azure subscription permissions](#understanding-azure-subscription-permissions)
      - [Optional - Create a Custom Azure Role](#optional---create-a-custom-azure-role)
  - [Complete Registration](#complete-registration)
    - [Option 1 - Register using PowerShell](#option-1---register-using-powershell)
    - [Option 2 - Register using Windows Admin Center](#option-2---register-using-windows-admin-center)
    - [View registration details in the Azure portal](#view-registration-details-in-the-azure-portal)
  - [Next Steps](#next-steps)
  - [Raising issues](#raising-issues)
  - [Troubleshooting](#troubleshooting)

Before you begin
-----------
At this stage, you should have completed the previous section of the jumpstart, [Scenario 2a - Clustering Azure Stack HCI with Windows Admin Center](/modules/module_2/2a_Cluster_AzSHCI_WAC.md) or [Scenario 2b - Clustering Azure Stack HCI with PowerShell](/modules/module_2/2a_Cluster_AzSHCI_PS.md) and have an Azure Stack HCI cluster successfully deployed, along with a cloud/file share witness. Here you can see our previously deployed cluster in Windows Admin Center:

![Azure Stack HCI cluster in Windows Admin Center](/modules/module_2/media/wac_azshcicluster.png "Azure Stack HCI cluster in Windows Admin Center")

If you don't have an Azure Stack HCI cluster up and running, refer to the previous sections to deploy and configure your cluster.

The following prerequisites were covered in a previous section, but for convenience, we'll include them here again. These are critical to proceed with the registration of your Azure Stack HCI cluster.

### Azure prerequisites
Aside from having internet connectivity, for connecting and integrating the Azure Stack HCI environment with Azure, you'll need to review the list below.

* **Get an Azure subscription** - if you don't have one, read [more information here](/modules/module_0/2_azure_prerequisites.md#get-an-azure-subscription)
* **Azure subscription permissions** - Owner **or** User Access Administrator + Contributer **or** Custom ([Instructions here](https://docs.microsoft.com/en-us/azure-stack/hci/deploy/register-with-azure#azure-subscription-and-permissions))
* **Firewall / Proxy** - If you are running the environment inside your own lab, ensure that your lab deployment has access to all external resources listed below:
  * [Host requirements](https://docs.microsoft.com/en-us/azure-stack/hci/concepts/firewall-requirements)
  * [Arc-enabled Servers requirements](https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#networking-configuration)

### Understanding Azure subscription permissions
The user registering the cluster must have Azure subscription permissions to:

- Register a resource provider
- Create/Get/Delete Azure resources and resource groups

If your Azure subscription is through an EA or CSP, the easiest way is to ask your Azure subscription admin to assign a built-in "Owner" role to your subscription, or a "User Access Administrator" role along with a "Contributor" role.

#### Optional - Create a Custom Azure Role ####

**Your admins may prefer a more restrictive option than using Owner, or Contributor**. In this case, it's possible to create a custom Azure role specific for Azure Stack HCI registration by following these steps:

1. Create a json file called **CustomHCIRole.json** with following content. Make sure to change <subscriptionID> to your Azure subscription ID. To get your subscription ID, visit [portal.azure.com](https://portal.azure.com), navigate to Subscriptions, and copy/paste your ID from the list.

   ```json
   {
     "Name": "Azure Stack HCI registration role",
     "Id": null,
     "IsCustom": true,
     "Description": "Custom Azure role to allow subscription-level access to register Azure Stack HCI",
     "Actions": [
       "Microsoft.Resources/subscriptions/resourceGroups/write",
       "Microsoft.Resources/subscriptions/resourceGroups/read",
       "Microsoft.Resources/subscriptions/resourceGroups/delete",
       "Microsoft.AzureStackHCI/register/action",
       "Microsoft.AzureStackHCI/Unregister/Action",
       "Microsoft.AzureStackHCI/clusters/*",
       "Microsoft.Authorization/roleAssignments/write",
       "Microsoft.HybridCompute/register/action",
       "Microsoft.GuestConfiguration/register/action"
     ],
     "NotActions": [
     ],
   "AssignableScopes": [
       "/subscriptions/<subscriptionId>"
     ]
   }
   ```

2. Create the custom role:

   ```powershell
   New-AzRoleDefinition -InputFile <path to CustomHCIRole.json>
   ```

3. Assign the custom role to the user:

   ```powershell
   $user = Get-AzAdUser -DisplayName <userdisplayname>
   $role = Get-AzRoleDefinition -Name "Azure Stack HCI registration role"
   New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionId $role.Id -Scope /subscriptions/<subscriptionid>
   ```

Complete Registration
-----------

To complete registration, you have 2 options - you can use **Windows Admin Center**, or you can use **PowerShell**.

### Option 1 - Register using PowerShell
We're going to perform the registration from the **HybridJumpstart-DC** machine.

1. On **HybridJumpstart-DC**, open **PowerShell as administrator**
2. Run the following PowerShell command to download the required Azure Stack HCI PowerShell module and dependencies:

```powershell
$ClusterName = "AzSHCI-Cluster"

# Install NuGet and download the Azure Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
if (!(Get-InstalledModule -Name Az.StackHCI -ErrorAction Ignore)) {
    Install-Module -Name Az.StackHCI -Force
}
```

3. Once installed, login to Azure:

```powershell
# Download Azure Accounts module
if (!(Get-InstalledModule -Name az.accounts -ErrorAction Ignore)) {
    Install-Module -Name Az.Accounts -Force
}
# Login to Azure
Login-AzAccount -UseDeviceAuthentication
```
![Logging into Azure with PowerShell](/modules/module_2/media/azure_login.png "Logging into Azure with PowerShell")

4. To select your preferred subscription below, run the following PowerShell:

```powershell
# Select context if more available
$context = Get-AzContext -ListAvailable

# Check if multiple subscriptions are available and choose preferred subscription
if (($context).count -gt 1) {
    $context = $context | Out-GridView -OutputMode Single
    $context | Set-AzContext
}
# Load subscription ID into variable
$subscriptionID = $context.subscription.id
```

![Select Azure subscription with PowerShell](/modules/module_2/media/select_subscription.png "Select Azure subscription with PowerShell")

5. When you're successfully logged into Azure, and have the Az.StackHCI modules installed, it's now time to register your Azure Stack HCI cluster to Azure. First, it's worth exploring how to check existing registration status. The following code assumes you are still in the PowerShell session open from the previous commands.

```powershell
Invoke-Command -ComputerName azshci1 -ScriptBlock {
    Get-AzureStackHCI
}
```

![Check the registration status of the Azure Stack HCI cluster](/modules/module_2/media/reg_check.png "Check the registration status of the Azure Stack HCI cluster")

As you can see from the result, the cluster is yet to be registered, and the cluster status identifies as **Clustered**. Azure Stack HCI needs to register within 30 days of installation per the Azure Online Services Terms. If not clustered after 30 days, the **ClusterStatus** will show **OutOfPolicy**, and if not registered after 30 days, the **RegistrationStatus** will show **OutOfPolicy**.

6. When you register an Azure Stack HCI cluster, it is registered to a particular region - not all Azure regions support Azure Stack HCI registration today, so to check, and select a particular region, run the following PowerShell. When the location window opens, select your preferred region, and click **OK**

```powershell
# Define the Azure resource group name (Customizable)
$ResourceGroupName = $ClusterName + "_Rg"

# Install the Az.Resources module to create resource groups
if (!(Get-InstalledModule -Name Az.Resources -ErrorAction Ignore)) {
    Install-Module -Name Az.Resources -Force
}

# Display and select location for registered cluster (and RG)
$region = (Get-AzLocation | Where-Object Providers -Contains "Microsoft.AzureStackHCI" `
    | Out-GridView -OutputMode Single -Title "Please select Location for Azure Stack HCI metadata").Location

# Create the resource group to contain the registered Azure Stack HCI cluster
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Ignore)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $region
}
```

![Select your preferred region for registration](/modules/module_2/media/select_region.png "Select your preferred region for registration")

7. To register the cluster, with your **Subscription ID** in hand from the earlier PowerShell command, you can **register using the following Powershell commands**, from your open PowerShell window. The initial set of commands below collect tokens from your existing Azure login, to avoid re-prompting you to log into Azure when registering:

```powershell
# Grab the tokens from the existing login session
$armTokenItemResource = "https://management.core.windows.net/"
$graphTokenItemResource = "https://graph.windows.net/"
$azContext = Get-AzContext
$authFactory = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory
$graphToken = $authFactory.Authenticate($azContext.Account, $azContext.Environment, `
        $azContext.Tenant.Id, $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, `
        $null, $graphTokenItemResource).AccessToken
$armToken = $authFactory.Authenticate($azContext.Account, $azContext.Environment, `
        $azContext.Tenant.Id, $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, `
        $null, $armTokenItemResource).AccessToken
$id = $azContext.Account.Id

Register-AzStackHCI `
    -Region $Region `
    -SubscriptionID $subscriptionID `
    -ComputerName  $ClusterName `
    -GraphAccessToken $graphToken `
    -ArmAccessToken $armToken `
    -AccountId $id `
    -ResourceName $ClusterName `
    -ResourceGroupName $ResourceGroupName
```

Of these commands, many are optional:

* **-ResourceName** - If not declared, the Azure Stack HCI cluster name is used
* **-ResourceGroupName** - If not declared, the Azure Stack HCI cluster plus the suffix "-rg" is used
* **-Region** - If not declared, "EastUS" will be used. Additional regions are supported, with the longer term goal to integrate with Azure Arc in all Azure regions.
* **-EnvironmentName** - If not declared, "AzureCloud" will be used, but allowed values will include additional environments in the future
* **-ComputerName** - This is used when running the commands remotely against a cluster.  Just make sure you're using a domain account that has admin privilege on the nodes and cluster
* **-Credential** - This is also used for running the commands remotely against a cluster.

**Register-AzureStackHCI** runs syncronously, with progress reporting, and typically takes 1-2 minutes. The first time you run it, it may take slightly longer, because it needs to install some dependencies, including additional Azure PowerShell modules.

Once complete, you should see a message indicating success, as per below:

![Register Azure Stack HCI with PowerShell](/modules/module_2/media/ps_reg_complete.png "Register Azure Stack HCI with PowerShell")

> If you encounter an issue when registering your Azure Stack HCI cluster, refer to the [Troubleshooting](#troubleshooting) section below.

8. Once the cluster is registered, run the following command on **HybridJumpstart-DC** to check the updated status:

```powershell
Invoke-Command -ComputerName azshci1 -ScriptBlock {
    Get-AzureStackHCI
}
```
![Check updated registration status with PowerShell](/modules/module_2/media/registration_status.png "Check updated registration status with PowerShell")

You can see the **ConnectionStatus** and **LastConnected** time, which is usually within the last day unless the cluster is temporarily disconnected from the Internet. An Azure Stack HCI cluster can operate fully offline for up to 30 consecutive days.

**NOTE** - If when you ran **Register-AzureStackHCI**, you don't have appropriate permissions in Azure Active Directory, to grant admin consent, you will need to work with your Azure Active Directory administrator to complete registration later. You can exit and leave the registration in status "**pending admin consent**," i.e. partially completed. Once consent has been granted, **simply re-run Register-AzureStackHCI** to complete registration.

### Option 2 - Register using Windows Admin Center
If your preference is to use Windows Admin Center for registration, follow the steps below:

1. On **HybridJumpstart-DC**, logged in as **dell\labadmin**, open Windows Admin Center, and on the **All connections** page, select your azshci-cluster.
2. When the cluster dashboard has loaded, in the top-right corner, you'll see the **status of the Azure registration/connection**

![Azure registration status in Windows Admin Center](/modules/module_2/media/wac_azure_reg_dashboard_2.png "Azure registration status in Windows Admin Center")

3. You can begin the registration process by clicking **Register this cluster**
4. If you haven't already, you'll be prompted to register Windows Admin Center with an Azure tenant. Follow the instructions to **Copy the code** and then click on the link to configure device login.
5. When prompted for credentials, **enter your Azure credentials** for a tenant you'd like to register Windows Admin Center
6. Back in Windows Admin Center, you'll notice your tenant information has been added. You can now click **Connect** to connect Windows Admin Center to Azure.

![Connecting Windows Admin Center to Azure](/modules/module_2/media/wac_azure_connect.png "Connecting Windows Admin Center to Azure")

7. Click on **Sign in** and when prompted for credentials, **enter your Azure credentials** and you should see a popup that asks for you to accept the permissions, so click **Accept**

![Permissions for Windows Admin Center](/modules/module_2/media/wac_azure_permissions.png "Permissions for Windows Admin Center")

8. Back in Windows Admin Center, you may need to refresh the page if your 'Register this cluster' link is not active. Once active, click **Register this cluster** and you should be presented with a window requesting more information.
9.  Choose your **Azure subscription** that you'd like to use to register, along with a new or existing **Azure resource group** and **region**. You can also expand **advanced** to see that **Enable Azure Arc** enabled by default. Click **Register**.  This will take a few moments.

![Final step for registering Azure Stack HCI with Windows Admin Center](/modules/module_2/media/wac_azure_register_21H2.png "Final step for registering Azure Stack HCI with Windows Admin Center")

> **NOTE** - you may be prompted for CredSSP credentials - enter your LabAdmin credentials and proceed.

10. Once completed, you should see updated status on Windows Admin Center dashboard, showing that the cluster has been correctly registered.

![Azure registration status in Windows Admin Center](/modules/module_2/media/wac_azure_reg_dashboard.png "Azure registration status in Windows Admin Center")

**NOTE** - If when you ran the registration command, you don't have appropriate permissions in Azure Active Directory, to grant admin consent, you will need to work with your Azure Active Directory administrator to complete registration later. You can exit and leave the registration in status "**pending admin consent**," i.e. partially completed. Once consent has been granted, **simply rerun the process** to complete registration.

### View registration details in the Azure portal
With registration complete, either through Windows Admin Center, or through PowerShell, you should take some time to explore the artifacts that are created in Azure, once registration successfully completes.

1. On **HybridJumpstart-DC**, open the Edge browser and **log into https://portal.azure.com** to check the resources created there. In the **search box** at the top of the screen, search for **Resource groups** and then click on **Resource groups**
2. You should see a new **Resource group** listed, with the name you specified earlier, which in our case, is **AzSHCI-Cluster_Rg**

![Registration resource group in Azure](/modules/module_2/media/registration_rg_ga.png "Registration resource group in Azure")

12. Click on the **AzSHCI-Cluster_Rg** resource group, and in the central pane, you'll see that a record with the name **AzSHCI-Cluster** has been created inside the resource group
13. Click on the **AzSHCI-Cluster** record, and you'll be taken to the new Azure Stack HCI Resource Provider, which shows information about all of your clusters, including details on the currently selected cluster

![Overview of the recently registered cluster in the Azure portal](/modules/module_2/media/azure_portal_hcicluster_21H2.png "Overview of the recently registered cluster in the Azure portal")

### Congratulations! <!-- omit in toc -->
You've now successfully registered your Azure Stack HCI cluster!

Next Steps
-----------
In this step, you've successfully registered your Azure Stack HCI cluster. With this complete, you can now move on to:

* [**Module 2 | Scenario 4** - Explore some of the core management operations of your Azure Stack HCI environment](/modules/module_2/4_ManageAzSHCI.md "Explore the management of your Azure Stack HCI environment")

Raising issues
-----------
If you notice something is wrong with the jumpstart, such as a step isn't working, or something just doesn't make sense - help us to make this guide better!  [Raise an issue in GitHub](https://github.com/DellGEOS/HybridJumpstart/issues), and we'll be sure to fix this as quickly as possible!

Troubleshooting
-----------
When registering your Azure Stack HCI cluster with Azure, should the registration fail at the **Arc integration** stage, with an error message like that shown below, follow these steps to troubleshoot:

![Azure Stack HCI Arc integration error](/modules/module_2/media/ps_arc_error.png "Azure Stack HCI Arc integration error")

1. Firstly, you can explore the logs by running the following PowerShell command on **HybridJumpstart-DC**:

```powershell
# Validate task and start task
$ArcRegistrationTaskName = "ArcRegistrationTask"
Get-ClusteredScheduledTask -Cluster $ClusterName -TaskName $ArcRegistrationTaskName
Get-ScheduledTask -CimSession (Get-ClusterNode -Cluster $ClusterName).Name `
    -TaskName $ArcRegistrationTaskName | Start-ScheduledTask

# Explore Azure Arc install logs
Invoke-Command -ComputerName $ClusterName -Scriptblock `
{ Get-ChildItem -Path c:\windows\Tasks\ArcForServers | Get-Content }
```

2. To resolve the registration issue, run the following PowerShell commands:

```powershell
if (-not (Get-AzContext)) {
    Login-AzAccount -UseDeviceAuthentication
}

function Get-GraphAccessToken {
    param(
        [string] $TenantId,
        [string] $EnvironmentName
    )
    
    # Below commands ensure there is graph access token in cache
    Get-AzADApplication -DisplayName SomeApp1 -ErrorAction Ignore | Out-Null
    
    $graphTokenItemResource = (Get-AzContext).Environment.GraphUrl
    
    $authFactory = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory
    $azContext = Get-AzContext
    $graphTokenItem = $authFactory.Authenticate($azContext.Account, $azContext.Environment, $azContext.Tenant.Id, `
            $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $graphTokenItemResource)
    return $graphTokenItem.AccessToken
}
    
$azContext = Get-AzContext
$TenantId = $azContext.Tenant.Id
$AccountId = $azContext.Account.Id
$GraphAccessToken = Get-GraphAccessToken -TenantId $TenantId -EnvironmentName $EnvironmentName

Connect-AzureAD -TenantId $TenantId -AadAccessToken $GraphAccessToken -AccountId $AccountId | Out-Null

$arcStatus = Invoke-Command -computername $ClusterName -ScriptBlock { Get-AzureStackHCIArcIntegration }
$arcAppId = $arcStatus.ApplicationId
$app = Get-AzureADApplication -Filter "AppId eq '$arcAppId'"
$sp = Get-AzureADServicePrincipal -Filter "AppId eq '$arcAppId'"
# Create password
$start = Get-Date
$end = $start.AddYears(300)
$pw = New-AzureADServicePrincipalPasswordCredential -ObjectId $sp.ObjectId -StartDate $start -EndDate $end

$Region = (Get-AzLocation | Where-Object Providers -Contains "Microsoft.AzureStackHCI" `
    | Out-GridView -Title "Please select Location" -OutputMode Single).Location
$ResourceGroupName = "AzureStackHCIClusters"

# Define Azure Arc intregration parameters
$ArcRegistrationParams = @{
    AppId          = $app.appid
    Secret         = $pw.value
    TenantId       = $TenantId
    SubscriptionId = $SubscriptionId
    Region         = $Region
    ResourceGroup  = $ResourceGroupName
}

# Initialize Azure Arc integration
Invoke-Command -ComputerName $ClusterName -ScriptBlock `
{ Initialize-AzureStackHCIArcIntegration @Using:ArcRegistrationParams }

# Start Registration task
$ArcRegistrationTaskName = "ArcRegistrationTask"
Get-ScheduledTask -CimSession (Get-ClusterNode -Cluster $ClusterName).Name `
    -TaskName $ArcRegistrationTaskName | Start-ScheduledTask

Start-Sleep 20

# Explore Azure Arc install logs
Invoke-Command -ComputerName $ClusterName -Scriptblock `
{ Get-ChildItem -Path c:\windows\Tasks\ArcForServers | Get-Content }
```