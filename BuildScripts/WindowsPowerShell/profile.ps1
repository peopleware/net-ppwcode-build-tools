# my profile
Write-Host 'Initializing...'

# load PPWCode module
Write-Host 'Loading module PPWCode'
Import-Module PPWCode

# PPWCode module configuration
$PPWCodeCfg.localrepo = 'local'
$PPWCodeCfg.repos.debug = @("ppwcode-debug", "nuget")
$PPWCodeCfg.repos.release = @("ppwcode-release", "nuget")
$PPWCodeCfg.folders.code = 'C:\Development\PPWCode'
$PPWCodeCfg.folders.package = 'C:\Temp'
$PPWCodeCfg.verbosity = 3
