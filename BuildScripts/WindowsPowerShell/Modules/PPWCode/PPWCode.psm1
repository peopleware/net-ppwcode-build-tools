###############################################################################
###   PPWCode Powershell module                                             ###
###############################################################################
###   Copyright 2015 by PeopleWare n.v..                                    ###
###############################################################################
###   Authors: Ruben Vandeginste                                            ###
###############################################################################
###                                                                         ###
###  A PowerShell module that assists with                                  ###
###  the development of the PPWCode code.                                   ###
###                                                                         ###
###  It provides functionality for:                                         ###
###                                                                         ###
###   - initial clone of the code                                           ###
###   - creating clean builds                                               ###
###   - creating release packages                                           ###
###   - tagging release builds                                              ###
###   - generating release version notes                                    ###
###   - checking out specific version                                       ###
###                                                                         ###
###############################################################################


#region PRIVATE HELPERS

###############################################################################
###  PRIVATE HELPERS                                                        ###
###############################################################################

# Give a warning if the given command is not available
function WarnAboutCommandAvailability {
    param(
        [String]
        $cmd
    )

    if (!$(Get-Command "$cmd" -ErrorAction SilentlyContinue)) {
        Write-Warning "Complete functionality of this module depends on '$cmd' being available from the commandline."
    }
}

# Throw an error if the given command is not available
function CheckCommandAvailability {
    param(
        [String]
        $cmd
    )

    if (!$(Get-Command "$cmd" -ErrorAction SilentlyContinue)) {
        throw "'$cmd' not available from the commandline!"
    }
}

# Give a warning if the given setting is not set, or is empty
function WarnAboutSettingAvailability {
    param(
        [String]
        $cfgname
    )

    if ($(Invoke-expression "`$ENV:$cfgname") -eq $null) {
        Write-Warning "Complete functionality of this module depends on the setting '$cfgname'."
    }
}

# Give an error if the given setting is not set, or is empty
function CheckSettingAvailability {
    param(
        [String]
        $cfgname
    )

    if ($(Invoke-expression "`$ENV:$cfgname") -eq $null) {
        throw "Setting '$cfgname' is empty!"
    }
}

# Stolen from Psake, helper function to execute external commands and respect exit code.
function Exec {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = 1)][scriptblock]$cmd,
        [Parameter(Position = 1, Mandatory = 0)][string]$errorMessage = 'Bad command.',
        [Parameter(Position = 2, Mandatory = 0)][int]$maxRetries = 0,
        [Parameter(Position = 3, Mandatory = 0)][string]$retryTriggerErrorPattern = $null
    )
    
    $tryCount = 1
    
    do
    {
        try
        {
            $global:lastexitcode = 0
            & $cmd
            if ($lastexitcode -ne 0)
            {
                throw ('Exec: ' + $errorMessage)
            }
            break
        }
        catch [Exception]
        {
            if ($tryCount -gt $maxRetries)
            {
                throw $_
            }
            
            if ($retryTriggerErrorPattern -ne $null)
            {
                $isMatch = [regex]::IsMatch($_.Exception.Message, $retryTriggerErrorPattern)
                
                if ($isMatch -eq $false)
                {
                    throw $_
                }
            }
            
            Write-Host "Try $tryCount failed, retrying again in 1 second..."
            
            $tryCount++
            
            [System.Threading.Thread]::Sleep([System.TimeSpan]::FromSeconds(1))
        }
    }
    while ($true)
}

###############################################################################
# Helper for chatter
#
function Chatter {
    param
    (
        [string]
        $msg = '.',

        [int]
        $level = 3
    )

    if ($level -le $($global:PPWCodeCfg).verbosity) {
        Write-Host $msg -ForegroundColor Yellow
    }
}

###############################################################################
# Helper git credentials
#
function ConfigureGitCredentials() {
    if ('wincred' -ne $(git.exe config --global --get credential.helper)) {
        Exec { & git.exe config --global credential.helper wincred }
    }
}

#endregion


#region SETTINGS

###############################################################################
### SETTINGS ###
###############################################################################

# configure base settings
if ($global:PPWCodeCfg -eq $null) {
    $global:PPWCodeCfg = @{
      localrepo = 'local'
      repos = @{
        # repos used for debug builds
        debug = @('ppwcode-debug', 'nuget')
        # repos used for release builds
        release = @('ppwcode-release', 'nuget')
      }
      folders = @{
        # root folder for the source code checkouts
        code = 'C:\Development\PPWCode'
        # root folder for preparing a new installation package
        package = 'C:\Development\PPWCode\_Release'
      }
      verbosity = 1
	  usenugetcache = $false
    }
}
else {
    Write-Warning ">>> `$global:PPWCodeCfg not initialized, since it already exists! <<<"
}

# nuget available?
WarnAboutCommandAvailability nuget

# git available?
WarnAboutCommandAvailability git


#region PPWCODE PROJECT INFORMATION

# Fixed information on the PPWCode repositories
$PPWCodeRepositories = @{
    'oddsandends' = @{
        project = 'PPWCode.Util.OddsAndEnds'
		name = 'ppwcode-util-oddsandends'
		folder = 'ppwcode-util-oddsandends'
		git = 'net-ppwcode-util-oddsandends'
        bookmarks = '01.Code.1'
		wiki = $true
        psake = $true
    }
    'exceptions' = @{
        project = 'PPWCode.Vernacular.Exceptions'
		name = 'ppwcode-vernacular-exceptions'
		folder = 'ppwcode-vernacular-exceptions'
		git = 'net-ppwcode-vernacular-exceptions'
        bookmarks = '01.Code.2'
		wiki = $false
        psake = $true
    }
    'semantics' = @{
        project = 'PPWCode.Vernacular.Semantics'
		name = 'ppwcode-vernacular-semantics'
		folder = 'net-ppwcode-vernacular-semantics'
		git = 'net-ppwcode-vernacular-semantics'
        bookmarks = '01.Code.3'
		wiki = $false
        psake = $true
    }
    'persistence' = @{
        project = 'PPWCode.Vernacular.Persistence'
		name = 'ppwcode-vernacular-persistence'
		folder = 'ppwcode-vernacular-persistence'
		git = 'net-ppwcode-vernacular-persistence'
        bookmarks = '01.Code.4'
		wiki = $false
        psake = $true
    }
    'nhibernate' = @{
        project = 'PPWCode.Vernacular.NHibernate'
		name = 'ppwcode-vernacular-nhibernate'
		folder = 'ppwcode-vernacular-nhibernate'
		git = 'net-ppwcode-vernacular-nhibernate'
        bookmarks = '01.Code.5'
		wiki = $false
        psake = $true
    }
    'wcf' = @{
        project = 'PPWCode.Vernacular.Wcf'
		name = 'ppwcode-vernacular-wcf'
		folder = 'ppwcode-vernacular-wcf'
		git = 'net-ppwcode-vernacular-wcf'
        bookmarks = '01.Code.6'
		wiki = $false
        psake = $true
    }
    'test' = @{
        project = 'PPWCode.Util.Test'
		name = 'ppwcode-util-test'
		folder = 'ppwcode-util-test'
		git = 'net-ppwcode-util-test'
        bookmarks = '01.Code.7'
		wiki = $false
        psake = $true
    }
    'clr' = @{
        project = 'PPWCode.Clr.Utils'
		name = 'ppwcode-clr-utils'
		folder = 'ppwcode-clr-utils'
		git = 'net-ppwcode-clr-utils'
        bookmarks = '01.Code.8'
		wiki = $false
        psake = $false
    }
    'stylecop' = @{
        project = 'StyleCop.MSBuild.PPWCode'
		name = 'stylecop-msbuild-ppwcode'
		folder = 'stylecop-msbuild-ppwcode'
		git = 'stylecop-msbuild-ppwcode'
        bookmarks = '02.Tools.1'
		wiki = $false
        psake = $true
    }
    'tools' = @{
        project = 'PPWCode.Build.Tools'
		name = 'ppwcode-build-tools'
		folder = 'ppwcode-build-tools'
		git = 'net-ppwcode-build-tools'
        bookmarks = '02.Tools.2'
		wiki = $false
        psake = $false
    }
}

#endregion

#endregion


#region COMMANDS

###############################################################################
### COMMANDS                                                                ###
###############################################################################

#region Initialize-PPWCodeRepositories

###############################################################################
# Initialize-PPWCodeRepositories
#
function Initialize-PPWCodeRepositories {
<#
.SYNOPSIS
Initialize the git repositories for working on PPWCode code.
.DESCRIPTION
This will create a local git repository at a certain location
for all the components required for the PPWCode project.
The command is interactive: it will ask for credentials to be
able to clone the remote repository.
.PARAMETER protocol
The protocols to use for the remotes. For each given protocol,
a remote will be added. The first remote will become the default
'origin' remote. The second remote will be given the name 'ssh'
or 'https' depending on which protocol is used.
.EXAMPLE
Initialize-PPWCodeRepositories https,ssh

This command will clone all repositories.  It will add the 'https' remote
as the default remote 'origin'.  It will add the 'ssh' remote as a second
remote with the name 'ssh'.

.EXAMPLE
Initialize-PPWCodeRepositories

This command will clone all repositories.  It will add the 'https' remote
as the default remote 'origin'.

.EXAMPLE
Initialize-PPWCodeRepositories ssh

This command will clone all repositories.  It will add the 'ssh' remote
as the default remote 'origin'.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('https','ssh')]
        [string[]]
        $protocol = @('https')
    )

    # origin and naming
    $first = $protocol[0]
    $second = $protocol[1]
    
    # save current location
    Push-Location
    
    # do the thing
    try
    {
        # move to the source code folder
        Set-Location $($global:PPWCodeCfg).folders.code
    
        # cache passwords
        ConfigureGitCredentials

        # go one by one over all the repositories
        foreach ($repo in $PPWCodeRepositories.Keys) {
            Chatter "Initializing repo $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            # check whether folder already exists, if so, then skip
            if (Test-Path (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)) {
                Chatter "Skipping repo $repo, it already exists" 1
                continue
            }
            
            $httpsUri = "https://github.com/peopleware/$($repodata.git).git"
            $sshUri = "git@github.com:peopleware/$($repodata.git).git"
            
            Chatter "Https: $httpsUri" 3
            Chatter "SSH:   $sshUri" 3

            # determine clone uri
            $cloneUri = $httpsUri
            if ($first -eq 'ssh') {
                $cloneUri = $sshUri
            }
            
            # do the clone
            # clone the repo, and checkout the git-master branch
            # save the remote used for the clone as 'origin'
            Exec { & git.exe clone -b git-master -o origin $cloneUri $($repodata.folder) }
            
            # add second remote uri if asked
            if ($second -ne $null) {
                $remoteUri = $sshUri
                if ($second -eq 'https') {
                    $remoteUri = $httpsUri
                }
                
                # adding remote
                Set-Location $repo
                Exec { & git.exe remote add $second $remoteUri }
            }
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Initialize-PPWCodeBookmarks

###############################################################################
# Initialize-PPWCodeBookmarks
#
function Initialize-PPWCodeBookmarks {
<#
.SYNOPSIS
Generates a bookmarks.xml file for SourceTree configuration.
.DESCRIPTION
This will generate a bookmarks.xml file that can be used to update the
SourceTree configuration file located at:
C:\Users\xxxxx\AppData\Local\SourceTree\bookmarks.xml
.EXAMPLE
Initialize-PPWCodeBookmarks

This will generate a bookmarks.xml file in the root folder where the
source code is checked out.

#>
    [CmdletBinding()]
    param(
    )

    # save current location
    Push-Location
    
    # do the thing
    try
    {
        # move to the source code folder
        Set-Location $($global:PPWCodeCfg).folders.code
        
        # initialize the root xml
        [xml]$bookmarks = @'
<?xml version="1.0"?>
<ArrayOfTreeViewNode xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" />
'@

        # adding PPWCode root
        $PPWCode = $bookmarks.CreateElement('TreeViewNode')
        $PPWCodeType = $bookmarks.CreateAttribute('type', 'http://www.w3.org/2001/XMLSchema-instance')
        $PPWCodeType.Value = 'BookmarkFolderNode'
        $dummy = $PPWCode.SetAttributeNode($PPWCodeType)

        $level = $bookmarks.CreateElement('Level')
        $level.InnerText = '0'
        $dummy = $PPWCode.AppendChild($level)
        
        $isExpanded = $bookmarks.CreateElement('IsExpanded')
        $isExpanded.InnerText = 'true'
        $dummy = $PPWCode.AppendChild($isExpanded)
        
        $isLeaf = $bookmarks.CreateElement('IsLeaf')
        $isLeaf.InnerText = 'false'
        $dummy = $PPWCode.AppendChild($isLeaf)
        
        $name = $bookmarks.CreateElement('Name')
        $name.InnerText = 'PPWCode'
        $dummy = $PPWCode.AppendChild($name)

        # setting bookmarkgroup
        $PPWCodeRepositories.Keys | ForEach-Object { 
            $bm = $PPWCodeRepositories[$_].bookmarks
            $PPWCodeRepositories[$_].bookmarkgroup = $bm.SubString(0, $bm.Length -2)
        }

        # loops over the sections under PPWCode
        $PPWCodechildren = $bookmarks.CreateElement('Children')
        $bookmarkgroups = $PPWCodeRepositories.Values | ForEach-Object { $_.bookmarkgroup } | Sort-Object -Unique
        foreach ($bookmarkgroup in $bookmarkgroups) {
            $groupname = $bookmarkgroup.SubString(3)
            Chatter " Section $groupname" 1
            
            # adding group root
            $group = $bookmarks.CreateElement('TreeViewNode')
            $groupType = $bookmarks.CreateAttribute('type', 'http://www.w3.org/2001/XMLSchema-instance')
            $groupType.Value = 'BookmarkFolderNode'
            $dummy = $group.SetAttributeNode($groupType)

            $level = $bookmarks.CreateElement('Level')
            $level.InnerText = '1'
            $dummy = $group.AppendChild($level)
            
            $isExpanded = $bookmarks.CreateElement('IsExpanded')
            $isExpanded.InnerText = 'false'
            $dummy = $group.AppendChild($isExpanded)
            
            $isLeaf = $bookmarks.CreateElement('IsLeaf')
            $isLeaf.InnerText = 'false'
            $dummy = $group.AppendChild($isLeaf)
            
            $name = $bookmarks.CreateElement('Name')
            $name.InnerText = $groupname
            $dummy = $group.AppendChild($name)

            $groupchildren = $bookmarks.CreateElement('Children')
            $projects = $PPWCodeRepositories.Keys |
                            Where-Object { $bookmarkgroup -eq $PPWCodeRepositories[$_].bookmarkgroup } |
                            Sort-Object { $PPWCodeRepositories[$_].bookmarks }
            foreach ($repo in $projects) {
                Chatter "  Bookmarking repo $repo" 1
            
                # adding leaf
                $leaf = $bookmarks.CreateElement('TreeViewNode')
                $leafType = $bookmarks.CreateAttribute('type', 'http://www.w3.org/2001/XMLSchema-instance')
                $leafType.Value = 'BookmarkNode'
                $dummy = $leaf.SetAttributeNode($leafType)

                $level = $bookmarks.CreateElement('Level')
                $level.InnerText = '2'
                $dummy = $leaf.AppendChild($level)
                
                $isExpanded = $bookmarks.CreateElement('IsExpanded')
                $isExpanded.InnerText = 'true'
                $dummy = $leaf.AppendChild($isExpanded)
                
                $isLeaf = $bookmarks.CreateElement('IsLeaf')
                $isLeaf.InnerText = 'true'
                $dummy = $leaf.AppendChild($isLeaf)
                
                $name = $bookmarks.CreateElement('Name')
                $name.InnerText = $($PPWCodeRepositories[$repo].name)
                $dummy = $leaf.AppendChild($name)

                $children = $bookmarks.CreateElement('Children')
                $dummy = $leaf.AppendChild($children)

                $path = $bookmarks.CreateElement('Path')
                $path.InnerText = Join-Path $($global:PPWCodeCfg).folders.code $($PPWCodeRepositories[$repo].folder)
                $dummy = $leaf.AppendChild($path)

                $repotype = $bookmarks.CreateElement('RepoType')
                $repotype.InnerText = 'Git'
                $dummy = $leaf.AppendChild($repotype)

                $dummy = $groupchildren.AppendChild($leaf)
            }
            
            $dummy = $group.AppendChild($groupchildren)
            $dummy = $PPWCodechildren.AppendChild($group)
        }
        $dummy = $PPWCode.AppendChild($PPWCodechildren)
        
        # add PPWCode to bookmarks
        $dummy = $bookmarks.ArrayOfTreeViewNode.AppendChild($PPWCode)
        
        # writing out to xml file
        $filename = Join-Path $($global:PPWCodeCfg).folders.code '_bookmarks.xml'
        $bookmarks.Save($filename)
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Publish-PPWCodePackage

###############################################################################
# Publish-PPWCodePackage
#
function Publish-PPWCodePackage {
<#
.SYNOPSIS
Publishes the PPWCode packages for the given solution.
.DESCRIPTION
This find the nuget packages in the given solutions, build those nuget packages
and publish them using the given parameters.
.PARAMETER solution
The solution for which the packages will be built and published.
.PARAMETER mode
The mode in which the solution must be built.  This has an effect on the build
configuration and on the repositories that are selected for downloading the
dependent nuget packages.
.PARAMETER publishrepo
The name of the nuget package repository that will be used for publishing the
generated nuget packages.
.PARAMETER uselocal
This parameter indicates whether the local nuget package repository can be used
for downloading nuget package dependencies.
.EXAMPLE
Publish-PPWCodePackage oddsandends

Publishes the packages in the 'oddsandends', with the default values for
the remaining parameters.

.EXAMPLE
Publish-PPWCodePackage exceptions debug -uselocal

Uses the local nuget package repository for fetching the nuget package dependencies.
Builds the nuget packages in the 'exceptions' solution. Uses the build
configuration linked to the 'debug' mode. And uses the default parameter values for
the remaining parameters.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop'
            )]
        [string[]]
        $solution,

        [Parameter(Mandatory=$false)]
        [ValidateSet('debug','release')]
        [string]
        $mode = 'debug',

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [string]
        $publishrepo = $($global:PPWCodeCfg).localrepo,

        [switch]
        $uselocal
    )

    # save current location
    Push-Location
    
    # do the thing
    try
    {
        $repos = @()
        $repos = $solution

        foreach ($repo in $repos) {
            Chatter "Publishing packages for $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            # move to source code folder
            Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)
            
            # initialize repos
            $myrepos = $($global:PPWCodeCfg).repos[$mode]
            if ($uselocal) {
                $myrepos = @($($global:PPWCodeCfg).localrepo ) + $myrepos
            }
            
            # determining build configuration based on 
            $buildconfig = 'Debug'
            switch ($mode) {
                'debug' { $buildconfig = 'Debug' }
                'release' { $buildconfig = 'Release' }
            }
            
            # bootstrap psake
            Exec { .\init-psake.ps1 -repos $myrepos }
            
            # calling psake for creating the packages
            $myprops = @{ 
                buildconfig = $buildconfig
                repos = $myrepos
                publishrepo = $publishrepo
				usenugetcache = $($global:PPWCodeCfg).usenugetcache
            }
            Invoke-psake Package -properties $myprops
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Build-PPWCodeSolution

###############################################################################
# Build-PPWCodeSolution
#
function Build-PPWCodeSolution {
<#
.SYNOPSIS
Builds the given PPWCode solutions.
.DESCRIPTION
This builds the given PPWCode solutions using the given parameters.
.PARAMETER solution
The solution that will be built.
.PARAMETER mode
The mode in which the solution must be built.  This has an effect on the build
configuration and on the repositories that are selected for downloading the
dependent nuget packages.
.PARAMETER userconfig
The user configuration used for building the solution.
.PARAMETER uselocal
This parameter indicates whether the local nuget package repository can be used
for downloading nuget package dependencies.
.EXAMPLE
Build-PPWCodeSolution semantics

Builds the 'net-ppwcode-vernacular-semantics' solution, with the default values for
the remaining parameters.

.EXAMPLE
Build-PPWCodeSolution exceptions,semantics debug -uselocal

Uses the local nuget package repository for fetching the nuget package dependencies.
Builds the solutions 'net-ppwcode-vernacular-exceptions' and 'net-ppwcode-vernacular-semantics'.
Uses the build configuration linked to the 'debug' mode.
Uses the default parameter values for the remaining parameters.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop'
            )]
        [string[]]
        $solution,

        [Parameter(Mandatory=$false)]
        [ValidateSet('debug','release')]
        [string]
        $mode = 'debug',

        [switch]
        $uselocal
    )

    # save current location
    Push-Location
    
    # do the thing
    try
    {
        $repos = @()
        $repos = $solution

        foreach ($repo in $repos) {
            Chatter "Building solution $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            # move to source code folder
            Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)
            
            # initialize repos
            $myrepos = $($global:PPWCodeCfg).repos[$mode]
            if ($uselocal) {
                $myrepos = @($($global:PPWCodeCfg).localrepo ) + $myrepos
            }
            
            # determining build configuration based on 
            $buildconfig = 'Debug'
            switch ($mode) {
                'debug' { $buildconfig = 'Debug' }
                'release' { $buildconfig = 'Release' }
            }
            
            # bootstrap psake
            Exec { .\init-psake.ps1 -repos $myrepos }
            
            # calling psake for creating the packages
            $myprops = @{ 
                buildconfig = $buildconfig
                repos = $myrepos
                publishrepo= $publishrepo
				usenugetcache = $($global:PPWCodeCfg).usenugetcache
           }
            Invoke-psake FullBuild -properties $myprops
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Restore-PPWCodeSolution

###############################################################################
# Restore-PPWCodeSolution
#
function Restore-PPWCodeSolution {
<#
.SYNOPSIS
Cleans and restore the nuget packages for the given PPWCode solutions.
.DESCRIPTION
This cleans and restore the nuget packages in the given PPWCode solutions using the given parameters.
.PARAMETER solution
The solution that will be cleaned and restored.
.PARAMETER mode
The mode in which the solution must be built.  This has an effect on the build
configuration and on the repositories that are selected for downloading the
dependent nuget packages.
.PARAMETER userconfig
The user configuration used for building the solution.
.PARAMETER uselocal
This parameter indicates whether the local nuget package repository can be used
for downloading nuget package dependencies.
.EXAMPLE
Restore-PPWCodeSolution pensiob-affiliations-api

Cleans and restores the 'pensiob-affiliations-api' solution, with the default values for
the remaining parameters.

.EXAMPLE
Restore-PPWCodeSolution pensiob-memo-ntservicehost,pensiob-audit-ntserivcehost deploy hoefnix -uselocal

Uses the local nuget package repository for fetching the nuget package dependencies.
Cleans and restores the solutions 'pensiob-memo-ntservicehost' and 'pensiob-audit-ntservicehost'.
Uses the build configuration linked to the 'deploy' mode.
Uses the deploy configuration 'hoefnix' for the build.
Uses the default parameter values for the remaining parameters.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop'
            )]
        [string[]]
        $solution,

        [Parameter(Mandatory=$false)]
        [ValidateSet('debug','release')]
        [string]
        $mode = 'debug',

        [switch]
        $uselocal
    )

    # save current location
    Push-Location
    
    # do the thing
    try
    {
        $repos = @()
        $repos = $solution

        foreach ($repo in $repos) {
            Chatter "Restoring solution $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            # move to source code folder
            Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)
            
            # initialize repos
            $myrepos = $($global:PPWCodeCfg).repos[$mode]
            if ($uselocal) {
                $myrepos = @($($global:PPWCodeCfg).localrepo ) + $myrepos
            }
            
            # determining build configuration based on 
            $buildconfig = 'Debug'
            switch ($mode) {
                'debug' { $buildconfig = 'Debug' }
                'release' { $buildconfig = 'Release' }
            }
            
            # bootstrap psake
            Exec { .\init-psake.ps1 -repos $myrepos }
            
            # calling psake for creating the packages
            $myprops = @{ 
                buildconfig = $buildconfig
                repos = $myrepos
                publishrepo= $publishrepo
				usenugetcache = $($global:PPWCodeCfg).usenugetcache
            }
            Invoke-psake -taskList Clean,PackageRestore -properties $myprops
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Open-PPWCodeSolution

###############################################################################
# Open-PPWCodeSolution
#
function Open-PPWCodeSolution {
<#
.SYNOPSIS
Open the given PPWCode solutions.
.DESCRIPTION
This opens the given PPWCode solutions using the given parameters in Visual Studio.
.PARAMETER solution
The solution that will be opened.
.PARAMETER mode
The mode in which the solution must be built.  This has an effect on the build
configuration and on the repositories that are selected for downloading the
dependent nuget packages.
.PARAMETER userconfig
The user configuration used for building the solution.
.PARAMETER uselocal
This parameter indicates whether the local nuget package repository can be used
for downloading nuget package dependencies.
.PARAMETER restore
This switch indicates whether a Restore-PPWCodeSolution should be done prior
to opening the solution.
.EXAMPLE
Open-PPWCodeSolution pensiob-affiliations-api

Opens the 'pensiob-affiliations-api' solution, with the default values for
the remaining parameters.

.EXAMPLE
Open-PPWCodeSolution pensiob-memo-ntservicehost,pensiob-audit-ntserivcehost deploy hoefnix -uselocal

Uses the local nuget package repository for fetching the nuget package dependencies.
Opens the solutions 'pensiob-memo-ntservicehost' and 'pensiob-audit-ntservicehost'.
Uses the build configuration linked to the 'deploy' mode.
Uses the deploy configuration 'hoefnix' for the build.
Uses the default parameter values for the remaining parameters.

.EXAMPLE
Open-PPWCodeSolution pensiob-audit-ntservicehost release -uselocal -restore

Restores the packages on the solution before opening the solution in Visual Studio.
Adds the local nuget package repository to the repositories used for fetching the nuget
package dependencies. Uses the release version of the nuget package repositories.
Opens the PPWCode solution 'pensiob-audit-ntservicehost'.

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop'
            )]
        [string[]]
        $solution,

        [Parameter(Mandatory=$false)]
        [ValidateSet('debug','release')]
        [string]
        $mode = 'debug',

        [switch]
        $uselocal,
        
        [switch]
        $restore
    )

    # save current location
    Push-Location
    
    # do the thing
    try
    {
        $repos = @()
        $repos = $solution

        foreach ($repo in $repos) {
            Chatter "Open solution $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            if ($restore) {
                Restore-PPWCodeSolution $repo -uselocal:$uselocal
            }
            
            $s = Get-ChildItem -Filter '*.sln' -Path $(Join-Path (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder) 'src')
            & Start-Process $s.FullName
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
}

#endregion

#region Invoke-PPWCodePsake

###############################################################################
# Invoke-PPWCodePsake
#
function Invoke-PPWCodePsake {
<#
.SYNOPSIS
Invokes the given Psake task in the given solution.
.DESCRIPTION
This invokes the given Psake task in the given solution, using the given
properties. It also takes care of bootstrapping Psake.
.PARAMETER solution
The solution that will be opened.
.PARAMETER task
The task(s) that must be invoked using Psake.
.PARAMETER mode
The mode in which the solution must be built.  This has an effect on the build
configuration and on the repositories that are selected for downloading the
dependent nuget packages.
.PARAMETER userconfig
The user configuration used for building the solution.
.PARAMETER publishrepo
The name of the NuGet package repository that should used for publishing packages.
.PARAMETER chatter
The level of information that is printed out during task execution.
.PARAMETER usenugetcache
This parameter indicates whether the built-in NuGet cache can be used.
.PARAMETER uselocal
This parameter indicates whether the local nuget package repository can be used
for downloading nuget package dependencies.
.PARAMETER properties
A hashtable with properties that allows the user to override explicitly the properties
that are passed to the 'invoke-psake' command.
.EXAMPLE
Invoke-PPWCodePsake pensiob-affiliations-ntservicehost Test debug

This will execute the psake task 'Test' on the solution 'pensiob-affiliations-ntservicehost'.
The mode is 'debug' and will influence the build configuration and the nuget package
repositories used for fetching dependencies.  The 'local' nuget package repository will
not be used.

.EXAMPLE
Invoke-PPWCodePsake pensiob-affiliations-api Documentation debug -uselocal

This will execute the psake task 'Documentation' on the solution 'pensiob-affiliations-api'.
The mode is 'debug' and will influence the build configuration and the nuget package
repositories used for fetching dependencies.  The 'local' nuget package repository will
be used and takes precedence over the other nuget package repositories.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop'
                     )]
        [string[]]
        $solution,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('?',
                     'ReSharperClean',
                     'PackageClean',
                     'PackageRestore',
                     'Build',
                     'Clean',
                     'FullClean',
                     'FullBuild',
                     'Package',
                     'Test',
                     'Documentation')]
        [string[]]
        $task,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('debug', 'release')]
        [string]
        $mode = 'debug',
        
        [Parameter(Mandatory = $false)]
        [string]
        $publishrepo = $($($global:PPWCodeCfg).localrepo),

        [switch]
        $uselocal,
        
        [Parameter(Mandatory = $false)]
        [Hashtable]
        $properties = @{ }
    )
    
    # save current location
    Push-Location
    
    # do the thing
    try {
        foreach ($repo in $solution) {
            Chatter "Invoke-psake $([String]::Join(',', $task)) $repo" 1
            
			# initialize repodata
			$repodata = $PPWCodeRepositories[$repo]

            # move to source code folder
            Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)
            
            # initialize repos
            $myrepos = $($global:PPWCodeCfg).repos[$mode]
            if ($uselocal) {
                $myrepos = @($($global:PPWCodeCfg).localrepo) + $myrepos
            }
                
            # determining build configuration based on
            $buildconfig = 'Debug'
            switch ($mode) {
                'debug' { $buildconfig = 'Debug' }
                'release' { $buildconfig = 'Release' }
            }
                
            # finally combine into a properties
            $myprops = @{
                buildconfig = $buildconfig
                repos = $myrepos
                usenugetcache = $($global:PPWCodeCfg).usenugetcache
                chatter = $($global:PPWCodeCfg).verbosity
                publishrepo = $publishrepo
            }

            # check any overrides in $properties
			# overrides must use the psake property names
            if ($properties -ne $null) {
                if ($properties.buildconfig -ne $null)
                {
                    $myprops.buildconfig = $properties.buildconfig
                }
                if ($properties.repos -ne $null)
                {
                    $myprops.repos = $properties.repos
                }
                if ($properties.publishrepo -ne $null)
                {
                    $myprops.publishrepo = $properties.publishrepo
                }
                if ($properties.chatter -ne $null)
                {
                    $myprops.chatter = $properties.chatter
                }
                if ($properties.chattercolor -ne $null)
                {
                    $myprops.chattercolor = $properties.chattercolor
                }
                if ($properties.usenugetcache -ne $null)
                {
                    $myprops.usenugetcache = $properties.usenugetcache
                }
            }
            
            # bootstrap psake
            if ($myprops.repos -ne $null) {
                Exec { .\init-psake.ps1 -repos $myprops.repos }
            } else {
                Exec { .\init-psake.ps1 }
            }
            
            # calling psake with the given tasks
            Invoke-psake -taskList $task -properties $myprops
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
        
}

#endregion

#region Update-PPWCodeModule

###############################################################################
# Update-PPWCodeModule
#
function Update-PPWCodeModule {
<#
.SYNOPSIS
Installs the updated version of the PPWCode PowerShell module.
.DESCRIPTION
This command updates the 'PPWCode-tools' to the most recent version (branch
'git-master'), takes the PowerShell module and updates this module in the
default module location. After installation the command forces a reload of
the PPWCode module.
.PARAMETER noupdate
Do not update the source code for the PPWCode PowerShell module.
.PARAMETER noreload
Do not force a reload of the PPWCode PowerShell module after updating it.
.EXAMPLE
Update-PPWCodeModule

Updates 'PPWCode-tools' to the most recent version, updates the PowerShell
module, places this in the default location and forces a reload of the module.

#>
    [CmdletBinding()]
    param (
        [switch]
        $noupdate,

        [switch]
        $noreload
    )
    
    # save current location
    Push-Location
    
    # do the thing
    try {

		# initialize repo data
        $toolsdata = $PPWCodeRepositories['tools']

        # first, update PPWCode-tools to get most recent version
        Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $toolsdata.folder)

        # make sure repo is uptodate
        if (-not $noupdate) {
            Chatter 'Updating repo tools' 1
            Exec { & git.exe checkout git-master }
            Exec { & git.exe pull --ff-only origin }
        }

        # updating module
        $moduleSourcePath = Join-Path (Join-Path $($global:PPWCodeCfg).folders.code $toolsdata.folder) '.\BuildScripts\WindowsPowerShell\Modules\PPWCode'
        $moduleTargetPath = Join-Path $HOME 'Documents\WindowsPowerShell\Modules\PPWCode'
        Chatter 'Updating PPWCode PowerShell module' 1
        Chatter " Source path: $moduleSourcePath" 2
        Chatter " Target path: $moduleTargetPath" 2
        Exec {
            & Robocopy.exe $moduleSourcePath $moduleTargetPath /E /PURGE /NFL /NDL /NJH /NJS
            if ($global:lastexitcode -le 7) { $global:lastexitcode = 0 }
        }

        # forcing reload
        if (-not $noreload)
        {
            Chatter 'Force reload of PPWCode module' 1
            Import-Module -Name PPWCode -Force -Global
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
        
}

#endregion

#region Show-PPWCodeStatus

###############################################################################
# Show-PPWCodeStatus
#
function Show-PPWCodeStatus {
<#
.SYNOPSIS
Show the git status of the given PPWCode solutions.
.DESCRIPTION
This command prints out the git status of the given PPWCode solutions.
This lists the files that are changed and/or staged.
.PARAMETER solution
One or more PPWCode solutions
.PARAMETER  changedonly
Only lists those solutions that have changes in their working or staging area.
.EXAMPLE
Show-PPWCodeStatus 

Shows the Git status of all the PPWCode solutions.

.EXAMPLE
Show-PPWCodeStatus pensiob-affiliations-api,pensiob-affiliations-server,pensiob-affiliations-ntservicehost -changedonly

Lists only those repositories from the given solutions that contain changes in their
working or staging area.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop',
			'all'
            )]
        [string[]]
        $repo = @('all'),

        [switch]
        $changedonly
    )
    

    # determines services
    $repos = @()
    if ($repo.Contains('all')) {
        $repos = @(
            'oddsandends',
            'exceptions',
            'semantics',
            'persistence',
            'nhibernate',
            'wcf',
            'test',
            'clr',
            'stylecop',
            'tools')
    }
    else {
        $repos = $repo
    }

    # save current location
    Push-Location
    
    # do the thing
    try {
        foreach ($r in $repos) {
            # dummy status for creating the variable
            [string[]] $gitstatus = $null
            [string] $gitbranch = $null

			$repodata = $PPWCodeRepositories[$r]

            # move to source code folder
            Set-Location (Join-Path $($global:PPWCodeCfg).folders.code $repodata.folder)

            # get git status
            Exec { 
                $status = & git.exe status --porcelain
                # oh yeah... have to love the powershell dynamic scoping :)
                Set-Variable -Name 'gitstatus' -Value $status -Scope 2
            }

            # get git branch
            Exec { 
                $branch = & git.exe symbolic-ref --short -q HEAD
                # oh yeah... have to love the powershell dynamic scoping :)
                Set-Variable -Name 'gitbranch' -Value $branch -Scope 2
            }

            # show status
            if ((-not $changedonly) -or ($gitstatus -ne $null))
            {
                Write-Host "$r [$gitbranch]" -ForegroundColor Green
                if ($gitstatus -ne $null) {
                    $gitstatus | ForEach-Object {
                        Write-Host "   $_" -ForegroundColor Gray
                    }
                }
            }
        }
    }
    finally
    {
        # go back to original location
        Pop-Location
    }
        
}

#endregion

#endregion


Export-ModuleMember -Function @(
    'Initialize-PPWCodeRepositories',
    'Initialize-PPWCodeBookmarks',
    'Publish-PPWCodePackage',
    'Build-PPWCodeSolution',
    'Restore-PPWCodeSolution',
    'Open-PPWCodeSolution',
    'Invoke-PPWCodePsake',
    'Update-PPWCodeModule',
    'Show-PPWCodeStatus'
)
