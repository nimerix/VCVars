using namespace System.Collections.Generic
using namespace System.IO

function Get-VSProductType {
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0")]
    [Alias("v")]
    [String]
    $Version,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [Alias("p")]
    [String]
    $Directory
    )
  
  If ($Version -match "15.0") {
    $tdir = [Path]::GetFileName($Directory)
    $detected_product = If (@("Professional", "BuildTools", "Enterprise", "Community") -contains $tdir) { $tdir } Else { "BuildTools" }
    return $detected_product
  }
    $ddiv_path = (Join-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\DevDiv\vs\Servicing" $Version)
    
    return $( If (Test-Path (Join-Path $ddiv_path "enterprise")) { "Enterprise" } 
                        ElseIf (Test-Path (Join-Path $ddiv_path "premium")) { "Enterprise" } 
                        ElseIf (Test-Path (Join-Path $ddiv_path "ultimate")) { "Enterprise" } 
                        ElseIf (Test-Path (Join-Path $ddiv_path "professional")) { "Professional" } 
                        ElseIf (Test-Path (Join-Path $ddiv_path "community")) { "Community" } 
                        Else { "BuildTools" })
}

function Get-VSVersionInfo {
  $vs_sxs = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7"
  $valid_vs_vers = $("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0")
  $versions = @()
  Get-Item $vs_sxs `
  | Select-Object -ExpandProperty property `
  | Where-Object { ($valid_vs_vers -contains $_) -and ($(try {Test-Path (Get-ItemPropertyValue $vs_sxs $_) } catch {$false})) } `
  | Foreach-Object { 
      $tpath = $(Get-ItemPropertyValue $vs_sxs $_)
      $tver = $_
      $tprod = (Get-VSProductType -Version $tver -Directory $tpath)
      $versions += New-Object PSObject -Property @{ Version = $tver; InstallationPath = $tpath ; Source = $vs_sxs; Product = $tprod } 
  } 
  
  $valid_vs_vers `
  | Where-Object { ($versions.Version -notcontains $_) -and ($(try {Test-Path([System.Environment]::GetEnvironmentVariable("VS" + $_.TrimEnd(".0") + "0COMNTOOLS"))} catch {$false})) } `
  | Foreach-Object { 
    $tsrc = "VS" + $_.TrimEnd(".0") + "0COMNTOOLS"
    $tpath = [System.Environment]::GetEnvironmentVariable($tsrc)
    while (@("Common7", "Tools") -contains (Split-Path $tpath -leaf)) { $tpath = (Split-Path $tpath -Parent) }
    $versions += New-Object PSObject -Property @{ Version = $_; InstallationPath = $tpath; Source = $tsrc; Product = "BuildTools" } 
  } 
  $versions = $versions | sort {[float]$_.Version} | Get-Unique
  return $versions
}
<#
  .SYNOPSIS
    Returns a list of all installed Visual Studio versions
#>
function Find-VSVersions {
  [CmdletBinding(DefaultParameterSetName="All")]
  param(
    [Alias("l")]
    [Switch]
    $Latest = $false
  )
  
  <#
  $vs_sxs = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7"
  $valid_vs_vers = $("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0")
  $versions = [List[String]]::new()
  Get-Item $vs_sxs `
  | Select-Object -ExpandProperty property `
  | Where-Object { ($valid_vs_vers -contains $_) -and ($(try {Test-Path (Get-ItemProperty -Path $vs_sxs -Name $_).$_ } catch {$false})) } `
  | Foreach-Object { $versions.Add([String]::new($_)) } 
  
  $valid_vs_vers `
  | Where-Object { ($versions -notcontains $_) -and ($(try {Test-Path([System.Environment]::GetEnvironmentVariable("VS" + $_.TrimEnd(".0") + "0COMNTOOLS"))} catch {$false})) } `
  | Foreach-Object { $versions.Add([String]::new($_)) } 

  $versions = $versions | sort {[float]$_} | Get-Unique
  #>
  $versions = (Get-VSVersionInfo)
  if (-not $Latest) { return $versions }
  @($versions) | Select-Object -Last 1
}

function Get-VCDir {
  [CmdletBinding()]
  param(
    [ValidateSet("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0", "Latest")]
    [Alias("v")]
    [String]
    $Version = "Latest"
  )
  $vs_ver = If ($Version -match "Latest") { $(Find-VSVersions -Latest) } Else { $Version }
  $(try { Get-ItemPropertyValue "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7" $vs_ver } catch {$null})
}
<#
  .SYNOPSIS
    Returns either *all* vcvarsall.bat files, a specific installed product's
    vcvarsall.bat, or the most recently installed vcvarsall.bat
#>
function Find-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any",
    [ValidateSet("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0", "Latest")]
    [Alias("v")]
    [String]
    $MSVC = "Latest",
    [Alias("l")]
    [Switch]
    $Latest = $false,
    [Switch]
    $Legacy = $false
  )

  
  $instances = $()
  if(@("15.0", "Latest") -contains $MSVC) { $instances = Get-VSSetupInstance | Sort-Object -Property InstallDate | Where-Object { @([Path]::GetFileName($_.InstallationPath), "Any") -contains $Product } }
  
  if ($Latest) { $instances = $instances | Select-Object -Last 1 }
  
  if ($Legacy -or -not $instances) {
    $instances = (Get-VSVersionInfo) | Where-Object { (@($_.Product, "Any") -contains $Product) -and (@($_.Version, "Latest") -contains $MSVC) }
  }
  $instances `
  | ForEach-Object { $_.InstallationPath } `
  | ForEach-Object { Get-ChildItem vcvarsall.bat -Path "$_\VC" -Recurse }
}



<#
  .SYNOPSIS
    Returns a list of all legacy Visual Studio installs

function Find-VSLegacyInstall {
  [CmdletBinding(DefaultParameterSetName="All")]
  param(
	[ValidateSet("Any", "2005", "2008", "2010", "2012", "2013", "2015")]
    [Alias("v")]
    [String]
    $Year = "Any",
    [ValidateSet("Any", "Community", "Professional", "Enterprise", "Express")]
    [Alias("p")]
    [String]
    $Product = "Any",
    [Alias("l")]
    [Switch]
    $Latest = $false
  )
  
 
  $msvc_search_versions = 
	If ($Latest -or { @("Any", "All") -contains $Year })  { 
		@("8","9","10","11","12","14") 
	} Else {
		switch -wildcard ($Year) {
		"2005" { @(8) }
		"2008" { @(9) }
		"2010" { @(10) }
		"2012" { @(11) }
		"2013" { @(12) }
		"2015" { @(14) }
	}
  $vs_sxs = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7"
  Get-Item $vs_sxs `
  | Select-Object -ExpandProperty property `
  | Where-Object { $msvc_search_versions -contains $_.TrimEnd(".0") } `
  | Foreach-Object { }
  
  $10 = (Get-ItemProperty -Path $path).KitsRoot10
  $8 = (Get-ItemProperty -Path $path).KitsRoot81
  $versions = [List[Version]]::new()
  Get-Item $8 `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  Get-ChildItem "$10\Lib" `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  if (-not $Latest) { return $versions }
  $versions.Sort()
  @($versions) | Select-Object -Last 1
}
#>
<#
  .SYNOPSIS
    Returns a list of all installed Windows Kits SDKs
#>
function Find-VCWindowsKitsVersions {
  [CmdletBinding(DefaultParameterSetName="All")]
  param(
    [Alias("l")]
    [Switch]
    $Latest = $false
  )

  $path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
  $10 = (Get-ItemProperty -Path $path).KitsRoot10
  $8 = (Get-ItemProperty -Path $path).KitsRoot81
  $versions = [List[Version]]::new()
  Get-Item $8 `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  Get-ChildItem "$10\Lib" `
  | ForEach-Object { $versions.Add([Version]::new($_.Name)) }
  if (-not $Latest) { return $versions }
  $versions.Sort()
  @($versions) | Select-Object -Last 1
}

<#
  .SYNOPSIS
    Executes a vcvarsall.bat with specific host and target settings.
    Passes $Product to Find-VCVars.
    Returns a HashTable representing the difference in environment variables
#>
function Invoke-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("ARM", "ARM64", "x86", "AMD64")]
    [Alias("t")]
    [String]
    $TargetArch = "AMD64",

    [ValidateSet("x86", "AMD64")]
    [Alias("h")]
    [String]
    $HostArch = "AMD64",

    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any",

    [Alias("s")]
    [Version]
    $SDK,

    [Alias("u")]
    [Switch]
    $UWP = $false,
    
    [ValidateSet("8.0", "9.0", "10.0", "11.0", "12.0", "14.0", "15.0", "Latest")]
    [Alias("v")]
    [String]
    $MSVC = "Latest"
  )

  
  $hst = switch -wildcard ($HostArch) {
    "AMD64" { "amd64" }
    "x86" { "x86" }
  }

  $target = switch -wildcard ($TargetArch) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    "ARM" { "arm" }
    "x86" { "x86" }
  }

  $arch = if ($hst -ne $target) { "{0}_{1}" -f $hst, $target } else { $target }
  $batch = (Find-VCVars -Product $Product -MSVC $MSVC | Select-Object -Last 1).FullName
  $environment = @{}
  $current = @{}

  cmd /c set `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $current += $_ }

  if ($UWP -and ($SDK -eq $null)) {
    throw "Cannot use Universal Windows Platform without SDK version"
  }

  if ($UWP) { $platform = "uwp" }

  cmd /c "`"$batch`" $arch $platform $SDK & set" `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $environment += $_ }

  foreach ($entry in $current.GetEnumerator()) {
    if ($entry.Value -ne $environment[$entry.Name]) { continue }
    $environment.Remove($entry.Name)
  }

  return $environment
}

<#
  .SYNOPSIS
    Forces all environment variables given to be set in the current environment
    This does not save the current environment and bypasses the VCVars Stack
    entirely. Most useful when working with a single install and toolchain
#>
function Set-VCVars {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("e")]
    [HashTable]
    $Environment
  )

  foreach ($entry in $Environment.GetEnumerator()) {
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
}

<#
  .SYNOPSIS
    Calls /clean_env on the vcvarsall.bat. If no vcvarsall.bat command was
    run, this will error. Forcibly resets the environment, bypassing the VCVars
    Stack entirely
#>
function Clear-VCVars {
  [CmdletBinding()]
  param(
    [ValidateSet("Any", "Community", "Professional", "Enterprise", "BuildTools")]
    [Alias("p")]
    [String]
    $Product = "Any"
  )

  $batch = (Find-VCVars $Product | Select-Object -Last 1).FullName
  $environment = @{}
  cmd /c "`"$batch`" /clean_env & set" `
  | Where-Object { $_ -match "=" } `
  | ForEach-Object { $_ -replace '\\', '\\' } `
  | ConvertFrom-StringData `
  | ForEach-Object { $environment += $_ }

  Set-VCVars $environment
}

<#
  .SYNOPSIS
    Preserves the current environment variables by placing them onto an
    internal stack.
#>
function Push-VCVars {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("e")]
    [HashTable]
    $Environment
  )

  $vars = @{}
  foreach ($entry in $Environment.GetEnumerator()) {
    $current = [Environment]::GetEnvironmentVariable($entry.Name)
    $vars.Add($entry.Name, $current)
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
  $script:VCVarsStack.Push($vars)
}

<#
  .SYNOPSIS
    Resets the environment variables to the previous state that was pushed
    onto the internal stack. It then returns the state that was replaced in
    the form of a HashTable
#>
function Pop-VCVars {
  [CmdletBinding()]
  param()
  trap { throw $_ }

  if (-not $script:VCVarsStack) { return @{} }

  $state = $script:VCVarsStack.Pop()
  $dict = @{}
  foreach ($entry in $state.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($entry.Name)
    $dict.Add($entry.Name, $value)
    Set-Item -Force -Path env:$($entry.Name) -Value $entry.Value
  }
  return $dict
}

function VCSDKArgumentCompletion {
  param($command, $parameter, $word, $ast, $fake)
  Find-VCWindowsKitsVersions `
  | Where-Object { $_ -like "*$word*" } `
  | ForEach-Object { New-Object CompletionResult $_, $_, 'ParameterValue', $_ }
}

Register-ArgumentCompleter `
  -CommandName Invoke-VCVars `
  -ParameterName SDK `
  -ScriptBlock $function:VCSDKArgumentCompletion

function VSVersionArgumentCompletion {
  param($command, $parameter, $word, $ast, $fake)
  Find-VSVersions `
  | Where-Object { $_ -like "*$word*" } `
  | ForEach-Object { New-Object CompletionResult $_, $_, 'ParameterValue', $_ }
}

Register-ArgumentCompleter `
  -CommandName Invoke-VCVars `
  -ParameterName MSVC `
  -ScriptBlock $function:VSVersionArgumentCompletion

$script:VCVarsStack = New-Object Stack[HashTable]

Set-Alias vcvars Invoke-VCVars
Set-Alias pushvc Push-VCVars
Set-Alias popvc Pop-VCVars
Set-Alias setvc Set-VCVars
