@{
    # Version number of this module.
    moduleVersion     = '4.0.0'

    # ID used to uniquely identify this module
    GUID              = 'f5a5f169-7026-4053-932a-19a7c37b1ca5'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'This module contains DSC resources for deployment and configuration of Microsoft Hyper-V.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion        = '4.0'

    # Functions to export from this module
    FunctionsToExport = @()

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    DscResourcesToExport = @('Vhd','VhdFile','VMDvdDrive','VMHardDiskDrive','VMHost','VMHyperV','VMNetworkAdapter','VMProcessor','VMScsiController','VMSwitch')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = 'preview0005'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/HyperVDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/HyperVDsc'

            # A URL to an icon representing this module.
            IconUri = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [4.0.0-preview0005] - 2022-07-17

- HyperVDsc
  - BREAKING CHANGE
    - Renamed _xHyper-V_ to _HyperVDsc - fixes [Issue #69](https://github.com/dsccommunity/HyperVDsc/issues/213).
    - Changed all MSFT_xResourceName to DSC_ResourceName.
    - Updated DSCResources, Examples, Modules and Tests for new naming.
    - Updated README.md from _xHyper-V_ to _HyperVDsc
  - Renamed default branch to `main` - Fixes [Issue #198](https://github.com/dsccommunity/HyperVDsc/issues/198).
  - Moved documentation to the HyperVDsc GitHub Wiki.
  - Updated all examples to correct folders and naming so they show up
    in the GitHub Wiki documentation and conceptual help.
  - VMNetworkAdapter
    - BREAKING CHANGE: Rename embedded instance class #203
    - Fix multiple DNS IP adresses does not work #190
    - NetworkSetting parameter is now optional and no default actions are taken if not specified

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
