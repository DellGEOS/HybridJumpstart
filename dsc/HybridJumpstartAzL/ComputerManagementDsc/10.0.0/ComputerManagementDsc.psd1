@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'ComputerManagementDsc.psm1'

    # Version number of this module.
    moduleVersion        = '10.0.0'

    # ID used to uniquely identify this module
    GUID                 = 'B5004952-489E-43EA-999C-F16A25355B89'

    # Author of this module
    Author               = 'DSC Community'

    # Company or vendor of this module
    CompanyName          = 'DSC Community'

    # Copyright statement for this module
    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'DSC resources for configuration of a Windows computer. These DSC resources allow you to perform computer management tasks, such as renaming the computer, joining a domain and scheduling tasks as well as configuring items such as virtual memory, event logs, time zones and power settings.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '5.0'

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
    DscResourcesToExport = @('Computer','OfflineDomainJoin','PendingReboot','PowerPlan','PowerShellExecutionPolicy','RemoteDesktopAdmin','ScheduledTask','SmbServerConfiguration','SmbShare','SystemLocale','SystemProtection','SystemRestorePoint','TimeZone','VirtualMemory','WindowsEventLog','WindowsCapability','IEEnhancedSecurityConfiguration','UserAccountControl','PSResourceRepository')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{

        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/ComputerManagementDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/ComputerManagementDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [10.0.0] - 2025-01-25

### Added

- SystemProtection
  - New resource to configure System Protection settings (formerly xWindowsRestore) - Fixes [Issue #364](https://github.com/dsccommunity/ComputerManagementDsc/issues/364).
- SystemRestorePoint
  - New resource to create and delete restore points (formerly xSystemRestorePoint) - Fixes [Issue #364](https://github.com/dsccommunity/ComputerManagementDsc/issues/364).
- ScheduledTask
  - Added support for ScheduleType ''OnIdle'', ''AtCreation'', ''OnSessionState''.
    Fixes [Issue #282](https://github.com/dsccommunity/ComputerManagementDsc/issues/282).
  - Added support for StateChange to allow specifying which session state changes should
    trigger the task (with ScheduleType = OnSessionState).
  - Added support for StopAtDurationEnd permitting control over the ''Stop all running tasks
    at the end of the repetition duration'' feature.
    Fixes [Issue #168](https://github.com/dsccommunity/ComputerManagementDsc/issues/168).
  - Added support for TriggerExecutionTimeLimit permitting control over per-trigger ''Stop task
    if it runs longer than...'' feature.

### Fixed

- BREAKING CHANGE: ScheduledTask
  - Fixed SynchronizeAcrossTimeZone issue where Test always throws False when a date & time is used
    where Daylight Savings Time is in operation. Fixes [Issue #374](https://github.com/dsccommunity/ComputerManagementDsc/issues/374).
  - Fixed Test-DateStringContainsTimeZone to correctly process date strings behind UTC (-), as well
    as UTC Zulu ''Z'' strings.
  - Fixed User parameter to correctly return the user that triggers an AtLogon or OnSessionState
    Schedule Type, instead of the current value of ExecuteAsCredential. This parameter
    is only valid when using the AtLogon and OnSessionState Schedule Types.
  - Fixed User parameter to permit use even if LogonType = Group.
  - Updated RandomDelay logic from a blacklist to a whitelist.
  - Updated Delay parameter logic to reflect other TimeSpan based values.
  - Updated unit tests to use Should -Invoke for Pester 5 compatibility.
  - Updated various parameters with requirements in documentation.
- `VirtualMemory` fix incorrect variable name
- `SmbServerConfiguration` remove errant argument
- Update all calls to edit the registry so that the value Type is explicitly set.
  Fixes [Issue #433](https://github.com/dsccommunity/ComputerManagementDsc/issues/433).
- Made AppVeyor use ModuleFast to resolve dependencies.

### Changed

- BREAKING CHANGE: ScheduledTask
  - StartTime has chnage the type from DateTime to String.
  - StartTime is now processed on the device, rather than at compile time. This makes it possible
    to configure start times based on each device''s timezone, rather than being fixed to the time zone
    configured on the device where the Desired State Configuration compilation was run.
  - Allow StartTime to be used to set the ''Activate'' setting when adding ScheduleType triggers
    other than ''Once'', ''Daily'' and ''Weekly''.
  - Changed the default StartTime date from today to 1st January 1980 to prevent configuration flip flopping,
    and added note to configuration README to advise always supplying a date, and not just a time.
    Fixes [Issue #148](https://github.com/dsccommunity/ComputerManagementDsc/issues/148).
    Fixes [Issue #411](https://github.com/dsccommunity/ComputerManagementDsc/issues/411).
  - Added examples & note to configuration README to supply a timezone when using SynchronizeAcrossTimeZone.
  - Allow SynchronizeAcrossTimeZone to be used when adding ScheduleType triggers other than ''Once'',
    ''Daily'' and ''Weekly''.
  - Updated Delay parameter to support ScheduleType AtLogon, AtStartup, AtCreation, OnSessionState.
    Fixes [Issue #345](https://github.com/dsccommunity/ComputerManagementDsc/issues/345).
  - Updated User parameter for use with ScheduleType OnSessionState in addition to AtLogon.
  - Updated integration tests to ensure resource and configuration names are matching.
- Converted tests to Pester 5
- Rename Delete-ADSIObject to Delete-ADSIObject to satisfy HQRM
- No longer uses alias `New-InvalidArgumentException` but instead `New-ArgumentException`

### Removed

- Removed `Get-InvalidOperationRecord` to use version provided by `DscResource.Test`

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
