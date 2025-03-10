@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'DscResource.Common.psm1'

    # Version number of this module.
    ModuleVersion     = '0.17.2'

    # ID used to uniquely identify this module
    GUID              = '9c9daa5b-5c00-472d-a588-c96e8e498450'

    # Author of this module
    Author            = 'DSC Community'

    # Company or vendor of this module
    CompanyName       = 'DSC Community'

    # Copyright statement for this module
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Common functions used in DSC Resources'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Assert-BoundParameter','Assert-ElevatedUser','Assert-IPAddress','Assert-Module','Compare-DscParameterState','Compare-ResourcePropertyState','ConvertFrom-DscResourceInstance','ConvertTo-CimInstance','ConvertTo-HashTable','Find-Certificate','Get-ComputerName','Get-DscProperty','Get-EnvironmentVariable','Get-LocalizedData','Get-LocalizedDataForInvariantCulture','Get-PSModulePath','Get-TemporaryFolder','Get-UserName','New-ArgumentException','New-ErrorRecord','New-Exception','New-InvalidDataException','New-InvalidOperationException','New-InvalidResultException','New-NotImplementedException','New-ObjectNotFoundException','Remove-CommonParameter','Set-DscMachineRebootRequired','Set-PSModulePath','Test-AccountRequirePassword','Test-DscParameterState','Test-DscProperty','Test-IsNanoServer','Test-IsNumericType','Test-ModuleExist')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = 'New-InvalidArgumentException'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DSC', 'Localization')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/DscResource.Common/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/DscResource.Common'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.17.2] - 2024-07-20

### Added

- Public command:
  - `Get-UserName` - get current user name cross platform.

### Fixed

- `Get-PSModulePath`
  - Throws an exception if the My Documents folder cannot be found when
    calling the command with the scope `CurrentUser` ([issue #122](https://github.com/dsccommunity/DscResource.Common/issues/122)).

'

            Prerelease   = ''
        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
