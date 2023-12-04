
@{

  # Script module or binary module file associated with this manifest.
    RootModule = 'Hyper-ConvertImage.psm1'

  # Version number of this module.
	ModuleVersion = '10.2'

  # ID used to uniquely identify this module
	GUID = 'bd4390dc-a8ad-4bce-8d69-f53ccf8e4163'

  # Author of this module
	Author = 'Artem Pronichkin and Friends'

  # Company or vendor of this module
	CompanyName = 'Microsoft'

  # Copyright statement for this module
	Copyright = '(c) 2016 . All rights reserved.'

  # Description of the functionality provided by this module
    Description = "Microsoft hasn't published any approved PRs on their Convert-WindowsImage module in years. This is a more recent version."

  # Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.0'

  # Name of the Windows PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the Windows PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module
  # CLRVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  # RequiredModules = @()

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  # NestedModules = @()

  # Functions to export from this module
	FunctionsToExport = 'Convert-WindowsImage'

  # Cmdlets to export from this module
  #	CmdletsToExport = '*'

  # Variables to export from this module
  #	VariablesToExport = '*'

  # Aliases to export from this module
  #	AliasesToExport = '*'

  # List of all modules packaged with this module
  # ModuleList = @()

  # List of all files packaged with this module
  # FileList   = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess
  PrivateData = @{
    PSData = @{

      # Tags applied to this module. These help with module discovery in online galleries.
      Tags = 'Intune','Azure','Automation'

      # A URL to the license for this module.
      # LicenseUri = ''

      # A URL to the main website for this project.
      ProjectUri = 'https://github.com/tabs-not-spaces/Hyper-ConvertImage'

      # A URL to an icon representing this module.
      # IconUri = ''

      # ReleaseNotes of this module
      ReleaseNotes = @'
10.2 - Fixed to work on Windows Server
10.1 - Initial Commit - Fork of c49aa3a
'@

      # Prerelease string of this module
      # Prerelease = ''

      # Flag to indicate whether the module requires explicit user acceptance for install/update/save
      # RequireLicenseAcceptance = $false

      # External dependent modules of this module
      #ExternalModuleDependencies = @()

    } # End of PSData hashtable
  }

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''

}