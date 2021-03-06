@{
RootModule = 'VCVars.psm1'
ModuleVersion = '1.0'
GUID = '6fc7ca16-9e2f-4c83-bc46-99474fdd06f6'
Author = 'Isabella Muerte'
CompanyName = 'Unknown'
Copyright = '(c) 2017 Isabella Muerte. All rights reserved.'
Description = 'Visual C++ Environment Variable Management Module'
PowerShellVersion = '5.0'
RequiredModules = @('VSSetup')
# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

AliasesToExport = @('vcvars', 'pushvc', 'popvc', 'setvc')
FunctionsToExport = @(
  'Invoke-VCVars',
  'Clear-VCVars',
  'Find-VCVars',
  'Push-VCVars',
  'Pop-VCVars',
  'Set-VCVars'
)

VariablesToExport = '*'
CmdletsToExport = '*'

# List of all files packaged with this module
# FileList = @()

PrivateData = @{

  PSData = @{
    Tags = @(
      'vcvars',
      'c++',
      'msvc',
      'environment'
    )
    # LicenseUri = ''
    ProjectUri = 'https://github.com/slurps-mad-rips/VCVars'
  }
}

# HelpInfo URI of this module
# HelpInfoURI = ''

}
