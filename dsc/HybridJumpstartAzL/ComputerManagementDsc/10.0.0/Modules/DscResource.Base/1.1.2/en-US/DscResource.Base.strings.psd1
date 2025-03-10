<#
    .SYNOPSIS
        The localized resource strings in English (en-US) for the
        DscResource.Base module. This file should only contain
        localized strings for private and public functions.
#>

ConvertFrom-StringData @'
    DebugImportingLocalizationData = Importing localization data from '{0}' (DRB0001)
    ThrowClassIsNotPartOfModule = The class '{0}' is not part of module DscResource.Base and no BaseDirectory was passed. Please provide BaseDirectory. (DRB0002)
    DebugShowAllLocalizationData = Localization data: '{0}' (DRB0003)
'@
