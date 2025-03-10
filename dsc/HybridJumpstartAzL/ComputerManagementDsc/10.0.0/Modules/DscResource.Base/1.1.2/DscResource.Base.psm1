#Region '.\prefix.ps1' -1

$script:dscResourceCommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/DscResource.Common'
Import-Module -Name $script:dscResourceCommonModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
#EndRegion '.\prefix.ps1' 5
#Region '.\Enum\1.Ensure.ps1' -1

<#
    .SYNOPSIS
        The possible states for the DSC resource parameter Ensure.
#>

enum Ensure
{
    Present
    Absent
}
#EndRegion '.\Enum\1.Ensure.ps1' 11
#Region '.\Classes\002.Reason.ps1' -1

class Reason
{
    [DscProperty()]
    [System.String]
    $Code

    [DscProperty()]
    [System.String]
    $Phrase
}
#EndRegion '.\Classes\002.Reason.ps1' 11
#Region '.\Classes\010.ResourceBase.ps1' -1

<#
    .SYNOPSIS
        A class with methods that are equal for all class-based resources.

    .DESCRIPTION
        A class with methods that are equal for all class-based resources.

    .NOTES
        This class should be able to be inherited by all DSC resources. This class
        shall not contain any DSC properties, neither shall it contain anything
        specific to only a single resource.
#>

class ResourceBase
{
    # Property for holding localization strings
    hidden [System.Collections.Hashtable] $localizedData = @{}

    # Property for derived class to set properties that should not be enforced.
    hidden [System.String[]] $ExcludeDscProperties = @()

    # Default constructor
    ResourceBase()
    {
        $this.ImportLocalization($null)
    }

    ResourceBase([System.String] $BasePath)
    {
        $this.ImportLocalization($BasePath)
    }

    hidden [void] ImportLocalization([System.String] $BasePath)
    {
        $getLocalizedDataRecursiveParameters = @{
            ClassName = ($this | Get-ClassName -Recurse)
        }

        if (-not [System.String]::IsNullOrEmpty($BasePath))
        {
            <#
                Passing the base directory of the module that contain the
                derived class.
            #>
            $getLocalizedDataRecursiveParameters.BaseDirectory = $BasePath
        }

        <#
            TODO: When this fails, for example when the localized string file is missing
                the LCM returns the error 'Failed to create an object of PowerShell
                class SqlDatabasePermission' instead of the actual error that occurred.
        #>
        $this.localizedData = Get-LocalizedDataRecursive @getLocalizedDataRecursiveParameters
    }

    [ResourceBase] Get()
    {
        $this.Assert()

        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.GetCurrentState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $getCurrentStateResult = $this.GetCurrentState($keyProperty)

        $dscResourceObject = [System.Activator]::CreateInstance($this.GetType())

        # Set values returned from the derived class' GetCurrentState().
        foreach ($propertyName in $this.PSObject.Properties.Name)
        {
            if ($propertyName -in @($getCurrentStateResult.Keys))
            {
                $dscResourceObject.$propertyName = $getCurrentStateResult.$propertyName
            }
        }

        $keyPropertyAddedToCurrentState = $false

        # Set key property values unless it was returned from the derived class' GetCurrentState().
        foreach ($propertyName in $keyProperty.Keys)
        {
            if ($propertyName -notin @($getCurrentStateResult.Keys))
            {
                # Add the key value to the instance to be returned.
                $dscResourceObject.$propertyName = $this.$propertyName

                $keyPropertyAddedToCurrentState = $true
            }
        }

        if (($this | Test-DscProperty -Name 'Ensure') -and -not $getCurrentStateResult.ContainsKey('Ensure'))
        {
            # Evaluate if we should set Ensure property.
            if ($keyPropertyAddedToCurrentState)
            {
                <#
                    A key property was added to the current state, assume its because
                    the object did not exist in the current state. Set Ensure to Absent.
                #>
                $dscResourceObject.Ensure = [Ensure]::Absent
                $getCurrentStateResult.Ensure = [Ensure]::Absent
            }
            else
            {
                $dscResourceObject.Ensure = [Ensure]::Present
                $getCurrentStateResult.Ensure = [Ensure]::Present
            }
        }

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare($getCurrentStateResult, @())

        <#
            Return the correct values for Reasons property if the derived DSC resource
            has such property and it hasn't been already set by GetCurrentState().
        #>
        if (($this | Test-DscProperty -Name 'Reasons') -and -not $getCurrentStateResult.ContainsKey('Reasons'))
        {
            # Always return an empty array if all properties are in desired state.
            $dscResourceObject.Reasons = $propertiesNotInDesiredState |
                Resolve-Reason -ResourceName $this.GetType().Name |
                ConvertFrom-Reason
        }

        # Return properties.
        return $dscResourceObject
    }

    [void] Set()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.SetDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $this.Assert()

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare()

        if ($propertiesNotInDesiredState)
        {
            $propertiesToModify = $propertiesNotInDesiredState | ConvertFrom-CompareResult

            $propertiesToModify.Keys |
                ForEach-Object -Process {
                    Write-Verbose -Message ($this.localizedData.SetProperty -f $_, $propertiesToModify.$_)
                }

            <#
                Call the Modify() method with the properties that should be enforced
                and was not in desired state.
            #>
            $this.Modify($propertiesToModify)
        }
        else
        {
            Write-Verbose -Message $this.localizedData.NoPropertiesToSet
        }
    }

    [System.Boolean] Test()
    {
        # Get all key properties.
        $keyProperty = $this | Get-DscProperty -Attribute 'Key'

        Write-Verbose -Message ($this.localizedData.TestDesiredState -f $this.GetType().Name, ($keyProperty | ConvertTo-Json -Compress))

        $this.Assert()

        $isInDesiredState = $true

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        $propertiesNotInDesiredState = $this.Compare()

        if ($propertiesNotInDesiredState)
        {
            $isInDesiredState = $false
        }

        if ($isInDesiredState)
        {
            Write-Verbose -Message $this.localizedData.InDesiredState
        }
        else
        {
            Write-Verbose -Message $this.localizedData.NotInDesiredState
        }

        return $isInDesiredState
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare()
    {
        # Get the current state, all properties except Read properties .
        $currentState = $this.Get() | Get-DscProperty -Attribute @('Key', 'Mandatory', 'Optional')

        return $this.Compare($currentState, @())
    }

    <#
        Returns a hashtable containing all properties that should be enforced and
        are not in desired state, or $null if all enforced properties are in
        desired state.

        This method should normally not be overridden.
    #>
    hidden [System.Collections.Hashtable[]] Compare([System.Collections.Hashtable] $currentState, [System.String[]] $excludeProperties)
    {
        # Get the desired state, all assigned properties that has an non-null value.
        $desiredState = $this | Get-DscProperty -Attribute @('Key', 'Mandatory', 'Optional') -HasValue

        $CompareDscParameterState = @{
            CurrentValues     = $currentState
            DesiredValues     = $desiredState
            Properties        = $desiredState.Keys
            ExcludeProperties = ($excludeProperties + $this.ExcludeDscProperties) | Select-Object -Unique
            IncludeValue      = $true
            # This is needed to sort complex types.
            SortArrayValues   = $true
        }

        <#
            Returns all enforced properties not in desires state, or $null if
            all enforced properties are in desired state.
        #>
        return (Compare-DscParameterState @CompareDscParameterState)
    }

    # This method should normally not be overridden.
    hidden [void] Assert()
    {
        # Get the properties that has a non-null value and is not of type Read.
        $desiredState = $this | Get-DscProperty -Attribute @('Key', 'Mandatory', 'Optional') -HasValue

        $this.AssertProperties($desiredState)
    }

    <#
        This method can be overridden if resource specific property asserts are
        needed. The parameter properties will contain the properties that was
        assigned a value.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidEmptyNamedBlocks', '')]
    hidden [void] AssertProperties([System.Collections.Hashtable] $properties)
    {
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the properties that should be enforced and that are not in desired
        state.
    #>
    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.ModifyMethodNotImplemented
    }

    <#
        This method must be overridden by a resource. The parameter properties will
        contain the key properties.
    #>
    hidden [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        throw $this.localizedData.GetCurrentStateMethodNotImplemented
    }
}
#EndRegion '.\Classes\010.ResourceBase.ps1' 285
#Region '.\Private\ConvertFrom-CompareResult.ps1' -1

<#
    .SYNOPSIS
        Returns a hashtable with property name and their expected value.

    .DESCRIPTION
        Returns a hashtable with property name and their expected value.

    .PARAMETER CompareResult
        The result from Compare-DscParameterState.

    .EXAMPLE
        ConvertFrom-CompareResult -CompareResult (Compare-DscParameterState)

        Returns a hashtable that contain all the properties not in desired state
        and their expected value.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function ConvertFrom-CompareResult
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Hashtable[]]
        $CompareResult
    )

    begin
    {
        $returnHashtable = @{}
    }

    process
    {
        $CompareResult | ForEach-Object -Process {
            $returnHashtable[$_.Property] = $_.ExpectedValue
        }
    }

    end
    {
        return $returnHashtable
    }
}
#EndRegion '.\Private\ConvertFrom-CompareResult.ps1' 48
#Region '.\Private\ConvertFrom-Reason.ps1' -1

<#
    .SYNOPSIS
        Returns a array of the type `System.Collections.Hashtable`.

    .DESCRIPTION
        This command converts an array of [Reason] that is returned by the command
        `Resolve-Reason`. The result is an array of the type `[System.Collections.Hashtable]`
        that can be returned as the value of a DSC resource's property **Reasons**.

    .PARAMETER Reason
        Specifies an array of `[Reason]`. Normally the result from the command `Resolve-Reason`.

    .EXAMPLE
        Resolve-Reason -Reason (Resolve-Reason) -ResourceName 'MyResource'

        Returns an array of `[System.Collections.Hashtable]` with the converted
        `[Reason[]]`.

    .OUTPUTS
        [System.Collections.Hashtable[]]
#>
function ConvertFrom-Reason
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Because the rule does not understands that the command returns [System.Collections.Hashtable[]] when using , (comma) in the return statement')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseSyntacticallyCorrectExamples', '', Justification = 'Because the rule does not yet support parsing the code when the output type is not available. The ScriptAnalyzer rule UseSyntacticallyCorrectExamples will always error in the editor due to https://github.com/indented-automation/Indented.ScriptAnalyzerRules/issues/8.')]
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Reason[]]
        $Reason
    )

    begin
    {
        # Always return an empty array if there are nothing to convert.
        $reasonsAsHashtable = [System.Collections.Hashtable[]] @()
    }

    process
    {
        foreach ($currentReason in $Reason)
        {
            $reasonsAsHashtable += [System.Collections.Hashtable] @{
                Code   = $currentReason.Code
                Phrase = $currentReason.Phrase
            }
        }
    }

    end
    {
        return , [System.Collections.Hashtable[]] $reasonsAsHashtable
    }
}
#EndRegion '.\Private\ConvertFrom-Reason.ps1' 59
#Region '.\Private\Get-ClassName.ps1' -1

<#
    .SYNOPSIS
        Get the class name of the passed object, and optional an array with
        all inherited classes.

    .DESCRIPTION
        Get the class name of the passed object, and optional an array with
        all inherited classes

    .PARAMETER InputObject
        The object to be evaluated.

    .PARAMETER Recurse
        Specifies if the class name of inherited classes shall be returned. The
        recursive stops when the first object of the type `[System.Object]` is
        found.

    .EXAMPLE
        Get-ClassName -InputObject $this -Recurse

        Get the class name of the current instance and all the inherited (parent)
        classes.

    .OUTPUTS
        [System.String[]]
#>
function Get-ClassName
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Because the rule does not understands that the command returns [System.String[]] when using , (comma) in the return statement')]
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Recurse
    )

    begin
    {
        # Create a list of the inherited class names
        $class = @()
    }

    process
    {
        $class += $InputObject.GetType().FullName

        if ($Recurse.IsPresent)
        {
            $parentClass = $InputObject.GetType().BaseType

            while ($parentClass -ne [System.Object])
            {
                $class += $parentClass.FullName

                $parentClass = $parentClass.BaseType
            }
        }
    }

    end
    {
        return , [System.String[]] $class
    }
}
#EndRegion '.\Private\Get-ClassName.ps1' 71
#Region '.\Private\Get-LocalizedDataRecursive.ps1' -1

<#
    .SYNOPSIS
        Get the localization strings data from one or more localization string files.

    .DESCRIPTION
        Get the localization strings data from one or more localization string files.
        This can be used in classes to be able to inherit localization strings
        from one or more parent (base) classes.

        The order of class names passed to parameter `ClassName` determines the order
        of importing localization string files. First entry's localization string file
        will be imported first, then next entry's localization string file, and so on.
        If the second (or any consecutive) entry's localization string file contain a
        localization string key that existed in a previous imported localization string
        file that localization string key will be ignored. Making it possible for a
        child class to override localization strings from one or more parent (base)
        classes.

    .PARAMETER ClassName
        An array of class names, normally provided by `Get-ClassName -Recurse`.

    .PARAMETER BaseDirectory
        Specifies a base module path where it also searches for localization string
        files.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName $InputObject.GetType().FullName

        Returns a hashtable containing all the localized strings for the current
        instance.

    .EXAMPLE
        Get-LocalizedDataRecursive -ClassName (Get-ClassName -InputObject $this -Recurse)

        Returns a hashtable containing all the localized strings for the current
        instance and any inherited (parent) classes.

    .OUTPUTS
        [System.Collections.Hashtable]
#>
function Get-LocalizedDataRecursive
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]]
        $ClassName,

        [Parameter()]
        [System.String]
        $BaseDirectory
    )

    begin
    {
        $localizedData = @{}
    }

    process
    {
        foreach ($name in $ClassName)
        {
            if ($name -match '\.psd1$')
            {
                # Assume we got full file name.
                $localizationFileName = $name -replace '\.psd1$'
            }
            else
            {
                # Assume we only got class name.
                $localizationFileName = '{0}.strings' -f $name
            }

            Write-Debug -Message ($script:localizedData.DebugImportingLocalizationData -f $localizationFileName)

            if ($name -eq 'ResourceBase')
            {
                # The class ResourceBase will always be in the same module as this command.
                $path = $PSScriptRoot
            }
            elseif ($null -ne $BaseDirectory)
            {
                # Assuming derived class that is not part of this module.
                $path = $BaseDirectory
            }
            else
            {
                # Assuming derived class that is not part of this module.
                throw ($script:localizedData.ThrowClassIsNotPartOfModule -f $name)
            }

            # Get localized data for the class
            $classLocalizationStrings = Get-LocalizedData -DefaultUICulture 'en-US' -BaseDirectory $path -FileName $localizationFileName -ErrorAction 'Stop'

            # Append only previously unspecified keys in the localization data
            foreach ($key in $classLocalizationStrings.Keys)
            {
                if (-not $localizedData.ContainsKey($key))
                {
                    $localizedData[$key] = $classLocalizationStrings[$key]
                }
            }
        }
    }

    end
    {
        Write-Debug -Message ($script:localizedData.DebugShowAllLocalizationData -f ($localizedData | ConvertTo-JSON))

        return $localizedData
    }
}
#EndRegion '.\Private\Get-LocalizedDataRecursive.ps1' 115
#Region '.\Private\Resolve-Reason.ps1' -1

<#
    .SYNOPSIS
        Returns a array of the type `[Reason]`.

    .DESCRIPTION
        This command builds an array from the properties that is returned by the command
        `Compare-DscParameterState`. The result is an array of the type `[Reason]`.

    .PARAMETER Property
        The result from the command Compare-DscParameterState.

    .PARAMETER ResourceName
        The name of the resource. Will be used to populate the property Code with
        the correct value.

    .EXAMPLE
        Resolve-Reason -Property (Compare-DscParameterState) -ResourceName 'MyResource'

        Returns an array of `[Reason]` that contain all the properties not in desired
        state and why a specific property is not in desired state.

    .OUTPUTS
        [Reason[]]
#>
function Resolve-Reason
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseSyntacticallyCorrectExamples', '', Justification = 'Because the rule does not yet support parsing the code when the output type is not available. The ScriptAnalyzer rule UseSyntacticallyCorrectExamples will always error in the editor due to https://github.com/indented-automation/Indented.ScriptAnalyzerRules/issues/8.')]
    [CmdletBinding()]
    [OutputType([Reason[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.Collections.Hashtable[]]
        $Property,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceName
    )

    begin
    {
        # Always return an empty array if there are no properties to add.
        $reasons = [Reason[]] @()
    }

    process
    {
        foreach ($currentProperty in $Property)
        {
            if ($currentProperty.ExpectedValue -is [System.Enum])
            {
                # Return the string representation of the value (instead of the numeric value).
                $propertyExpectedValue = $currentProperty.ExpectedValue.ToString()
            }
            else
            {
                $propertyExpectedValue = $currentProperty.ExpectedValue
            }

            if ($property.ActualValue -is [System.Enum])
            {
                # Return the string representation of the value so that conversion to json is correct.
                $propertyActualValue = $currentProperty.ActualValue.ToString()
            }
            else
            {
                $propertyActualValue = $currentProperty.ActualValue
            }

            <#
                In PowerShell 7 the command ConvertTo-Json returns 'null' on null
                value, but not in Windows PowerShell. Switch to output empty string
                if value is null.
            #>
            if ($PSVersionTable.PSEdition -eq 'Desktop')
            {
                if ($null -eq $propertyExpectedValue)
                {
                    $propertyExpectedValue = ''
                }

                if ($null -eq $propertyActualValue)
                {
                    $propertyActualValue = ''
                }
            }

            # Convert the value to Json to be able to easily visualize complex types
            $propertyActualValueJson = $propertyActualValue | ConvertTo-Json -Compress
            $propertyExpectedValueJson = $propertyExpectedValue | ConvertTo-Json -Compress

            # If the property name contain the word Path, remove '\\' from path.
            if ($currentProperty.Property -match 'Path')
            {
                $propertyActualValueJson = $propertyActualValueJson -replace '\\\\', '\'
                $propertyExpectedValueJson = $propertyExpectedValueJson -replace '\\\\', '\'
            }

            $reasons += [Reason] @{
                Code   = '{0}:{0}:{1}' -f $ResourceName, $currentProperty.Property
                # Convert the object to JSON to handle complex types.
                Phrase = 'The property {0} should be {1}, but was {2}' -f @(
                    $currentProperty.Property,
                    $propertyExpectedValueJson,
                    $propertyActualValueJson
                )
            }
        }
    }

    end
    {
        return $reasons
    }
}
#EndRegion '.\Private\Resolve-Reason.ps1' 119
