@{
    # Version number of this module.
    moduleVersion        = '9.0.0'

    # ID used to uniquely identify this module
    GUID                 = 'e6647cc3-ce9c-4c86-9eb8-2ee8919bf358'

    # Author of this module
    Author               = 'DSC Community'

    # Company or vendor of this module
    CompanyName          = 'DSC Community'

    # Copyright statement for this module
    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'DSC resources for configuring settings related to networking.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion           = '4.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport    = @()

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport      = @()

    # DSC resources to export from this module
    DscResourcesToExport = @('DefaultGatewayAddress','DnsClientGlobalSetting','DnsConnectionSuffix','DNSServerAddress','Firewall','FirewallProfile','HostsFile','IPAddress','IPAddressOption','NetAdapterAdvancedProperty','NetAdapterBinding','NetAdapterLso','NetAdapterName','NetAdapterRDMA','NetAdapterRsc','NetAdapterRss','NetAdapterState','NetBIOS','NetConnectionProfile','NetIPInterface','NetworkTeam','NetworkTeamInterface','ProxySettings','Route','WINSSetting','DnsServerAddress','NetAdapterRdma','NetBios','WaitForNetworkTeam','WinsServerAddress','WinsSetting')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{

        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/NetworkingDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/NetworkingDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [9.0.0] - 2022-05-30

### Fixed

- NetBios
  - Fixes configuring network adapters in a disconnected or disabled state - fixes [Issue #434](https://github.com/dsccommunity/NetworkingDsc/issues/434).
- DnsServerAddress
  - Improved error handling - fixes [Issue #446](https://github.com/dsccommunity/NetworkingDsc/issues/446).

### Changed

- NetAdapterLso
  - Protocol now a key field allowing multiple protocol configurations for a
    single network adapter - fixes [Issue #475](https://github.com/dsccommunity/NetworkingDsc/issues/475).
  - Updated wiki documentation showing configuration overlap with
    NetAdapterAdvancedProperty - fixes [Issue #475](https://github.com/dsccommunity/NetworkingDsc/issues/475).
- NetAdapterAdvancedProperty
  - Updated wiki documentation showing configuration overlap with
    NetAdapterLso - fixes [Issue #475](https://github.com/dsccommunity/NetworkingDsc/issues/475).
- Renamed `master` branch to `main` - Fixes [Issue #469](https://github.com/dsccommunity/NetworkingDsc/issues/469).
- Updated build to use `Sampler.GitHubTasks` - Fixes [Issue #489](https://github.com/dsccommunity/NetworkingDsc/issues/489).
- Added support for publishing code coverage to `CodeCov.io` and
  Azure Pipelines - Fixes [Issue #491](https://github.com/dsccommunity/NetworkingDsc/issues/491).
- Minor reformatting of code style for diffability.
- ProxySettings
  - Added function `Get-ProxySettingsRegistryKeyPath` to provide initial
    support for changing proxy settings for current user.
    BREAKING CHANGE: Added support for configuring proxy settings for a user
    account by adding `Target` parameter - Fixes [Issue #423](https://github.com/dsccommunity/NetworkingDsc/issues/423).
- Updated .github issue templates to standard - Fixes [Issue #508](https://github.com/dsccommunity/NetworkingDsc/issues/508).
- Added Create_ChangeLog_GitHub_PR task to publish stage of build pipeline.
- Added SECURITY.md.
- Updated pipeline Deploy_Module anb Code_Coverage jobs to use ubuntu-latest
  images - Fixes [Issue #508](https://github.com/dsccommunity/NetworkingDsc/issues/508).
- Updated pipeline unit tests and integration tests to use Windows Server 2019 and
  Windows Server 2022 images - Fixes [Issue #507](https://github.com/dsccommunity/NetworkingDsc/issues/507).
- NetAdapterState
  - Added a new message when setting the state of an adapter.

### Fixed

- Fixed pipeline by replacing the GitVersion task in the `azure-pipelines.yml`
  with a script.
- NetAdapterState
  - Fixed so that the resource is idempotent so that `Enable-NetAdapter` and
    `Disable-NetAdapter` are only called when change is required.
- NetAdapterLso
  - Fixed integration tests so that they will be skipped if a network adapter
    with NDIS version 6 or greater is not available.

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
