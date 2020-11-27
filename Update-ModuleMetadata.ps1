[CmdletBinding(SupportsShouldProcess = $true)]
param
(
    [Parameter(
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true    
    )]
    [Alias('Name')]
    [System.String[]]
    $ModuleName
)

begin
{
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $script:IsElevated = $principal.IsInRole('Administrator')

    if ($false -eq $script:IsElevated)
    {
        Write-Warning 'Only modules from the "CurrentUser" scope will be processed.'
    }
}

process
{
    # No module(s) specified?
    if ($null -eq $ModuleName)
    {
        Write-Verbose -Message 'No module(s) specified, getting all available modules.'
        $ModuleName = (Get-Module -List | Sort-Object -Property Name).Name
    }

    foreach ($module in $ModuleName)
    {
        Write-Output "Processing module [$module]"

        # Get all versions of the current module
        $moduleVersions = Get-Module -Name $module -ListAvailable

        foreach ($moduleVersion in $moduleVersions)
        {
            Write-Output "Processing version [$($moduleVersion.Version)]"
            Write-Verbose "Getting module location"
            $moduleRoot = $moduleVersion.ModuleBase

            Write-Verbose "Building path for installation data file."
            $moduleInfoPath = Join-Path -Path $moduleRoot -ChildPath 'PSGetModuleInfo.xml'
            
            Write-Verbose 'Testing whether module was installed with PSGet.'
            if (Test-Path -Path $moduleInfoPath -PathType Leaf)
            {
                # If the module is not in the current users's profile
                if ($moduleRoot -notmatch "^$([Regex]::Escape($env:USERPROFILE))")
                {
                    # Check whether the current session is elevated
                    if ($script:IsElevated -eq $false)
                    {
                        Write-Warning "Skipping $($moduleVersion.Name) ($($moduleVersion.Version)) due to module scope."
                        continue;
                    }
                }

                Write-Verbose "Found module manifest at '$moduleInfoPath'. Loading contents."
                $moduleInstallationInfo = Import-Clixml -Path $moduleInfoPath

                if ($moduleInstallationInfo.InstalledLocation -ne $moduleRoot)
                {
                    if ($PSCmdlet.ShouldProcess(
                        "Updating installation path for [$($moduleVersion.Name) ($($moduleVersion.Version))]", 
                        "Are you sure you want to update the installation path for [$($moduleVersion.Name) ($($moduleVersion.Version))]?",
                        'Confirm installation path update.'
                    ))
                    {
                        Write-Verbose "Updating installation location value."
                        $moduleInstallationInfo.InstalledLocation = $moduleRoot
                        
                        Write-Verbose "Unhiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Normal'

                        Write-Verbose 'Saving module manifest changes.'
                        $moduleInstallationInfo | Export-Clixml -Path $moduleInfoPath -Force

                        Write-Verbose "Hiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Hidden'
                    }
                }

                if ($true -eq ((Get-ItemProperty -Path $moduleInfoPath).Attributes -band 'Hidden') -ne 0)
                {
                    if ($PSCmdlet.ShouldProcess(
                        "Hide PowerShellGet module manifest file [$($moduleInfoPath)].",
                        "Are you sure you wan to hide the PowerShellGet module manifest file [$($moduleInfoPath)].",
                        'Confirm operation.'
                    ))
                    {
                        Write-Verbose "Hiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Hidden'
                    }
                }
            }
            else
            {
                Write-Warning "Module [$($moduleVersion.Name) ($($moduleVersion.Version))] was not installed with the built-in package manager!"
            }
        }
    }
}
