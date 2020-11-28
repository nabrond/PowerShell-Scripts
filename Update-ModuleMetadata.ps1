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

    if ($DebugPreference -eq 'Inquire')
    {
        # No need to confirm every action here
        $DebugPreference = 'Continue'
    }
}

process
{
    Write-Output $DebugPreference

    # No module(s) specified?
    if ($null -eq $ModuleName)
    {
        Write-Verbose -Message 'No module(s) specified, getting all available modules.'
        $ModuleName = (Get-Module -List | Sort-Object -Property Name).Name
    }

    foreach ($module in $ModuleName)
    {
        Write-Verbose "Processing module [$module]"

        # Get all versions of the current module
        $moduleVersions = Get-Module -Name $module -ListAvailable

        foreach ($moduleVersion in $moduleVersions)
        {
            Write-Verbose "Processing version [$($moduleVersion.Version)]"
            Write-Debug "Getting module location"
            $moduleRoot = $moduleVersion.ModuleBase

            Write-Debug "Building path for installation data file."
            $moduleInfoPath = Join-Path -Path $moduleRoot -ChildPath 'PSGetModuleInfo.xml'
            
            Write-Debug 'Testing whether module was installed with PSGet.'
            if (Test-Path -Path $moduleInfoPath -PathType Leaf)
            {
                # If the module is not in the current users's profile
                if ($moduleRoot -notmatch "^$([Regex]::Escape($env:USERPROFILE))")
                {
                    # Check whether the current session is elevated
                    if ($script:IsElevated -eq $false)
                    {
                        Write-Debug "Skipping $($moduleVersion.Name) ($($moduleVersion.Version)) due to module scope."
                        continue;
                    }
                }

                Write-Debug "Found module manifest at '$moduleInfoPath'. Loading contents."
                $moduleInstallationInfo = Import-Clixml -Path $moduleInfoPath

                if ($moduleInstallationInfo.InstalledLocation -ne $moduleRoot)
                {
                    if ($PSCmdlet.ShouldProcess(
                        "Updating installation path for [$($moduleVersion.Name) ($($moduleVersion.Version))]", 
                        "Are you sure you want to update the installation path for [$($moduleVersion.Name) ($($moduleVersion.Version))]?",
                        'Confirm installation path update.'
                    ))
                    {
                        Write-Debug "Updating installation location value."
                        $moduleInstallationInfo.InstalledLocation = $moduleRoot
                        
                        Write-Debug "Unhiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Normal' -Confirm:$false

                        Write-Debug 'Saving module manifest changes.'
                        $moduleInstallationInfo | Export-Clixml -Path $moduleInfoPath -Force

                        Write-Debug "Hiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Hidden' -Confirm:$false
                    }
                }

                if (((Get-ItemProperty -Path $moduleInfoPath).Attributes -band 'Hidden') -ne 'Hidden')
                {
                    if ($PSCmdlet.ShouldProcess(
                        "Hide PowerShellGet module manifest file [$($moduleInfoPath)].",
                        "Are you sure you wan to hide the PowerShellGet module manifest file [$($moduleInfoPath)].",
                        'Confirm operation.'
                    ))
                    {
                        Write-Debug "Hiding module manifest '$moduleInfoPath'."
                        Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Hidden' -Confirm:$false
                    }
                }
            }
        }
    }
}
