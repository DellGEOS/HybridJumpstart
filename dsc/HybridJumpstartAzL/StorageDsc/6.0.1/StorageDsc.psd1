@{
    # Version number of this module.
    moduleVersion        = '6.0.1'

    # ID used to uniquely identify this module
    GUID                 = '00d73ca1-58b5-46b7-ac1a-5bfcf5814faf'

    # Author of this module
    Author               = 'DSC Community'

    # Company or vendor of this module
    CompanyName          = 'DSC Community'

    # Copyright statement for this module
    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'DSC resources for managing storage on Windows Servers.'

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
    DscResourcesToExport = @('DiskAccessPath','MountImage','OpticalDiskDriveLetter','WaitForDisk','WaitForVolume','Disk')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'Disk', 'Storage', 'Partition', 'Volume', 'DevDrive')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/StorageDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/StorageDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [6.0.1] - 2024-06-11

### Fixed

- OpticalDiskDriveLetter:
  - Some operating systems report the optical disk in the Win32_CDROMDrive list,
    but a volume that matches either the DeviceId or DriveLetter can not be found.
    This caused an `Cannot bind argument to parameter ''DevicePath'' because it is an empty string.`
    exception to occur in the `Test-OpticalDiskCanBeManaged`. Prevented this
    exception from occuring by marking disk as not manageable - Fixes [Issue #289](https://github.com/dsccommunity/StorageDsc/issues/289).
- Azure DevOps Build Pipeline:
  - Update pipeline files to use latest DSC Community pattern and sampler tasks.

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
