[CmdletBinding(SupportsShouldProcess = $true)]
param
(
    [Parameter()]
    [System.String[]]
    $ModuleName = (Get-InstalledModule | Sort-Object -Property Name).Name
)

begin
{
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $script:IsElevated = $principal.IsInRole('Administrator')
}

process
{
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
                        Write-Warning "Module [$($moduleVersion.Name) ($($moduleVersion.Version))] is not installed in the current user's profile. Please re-run this script from an elevated PowerShell session."
                        continue;
                    }
                }

                Write-Verbose "Found module manifest at '$moduleInfoPath'. Loading contents."
                $moduleInstallationInfo = Import-Clixml -Path $moduleInfoPath
                $moduleInstallationInfo.InstalledLocation = $moduleRoot

                if ($PSCmdlet.ShouldProcess(
                    "Update module installation information for [$($moduleVersion.Name) ($($moduleVersion.Version))]", 
                    "Should update module installation information for [$($moduleVersion.Name) ($($moduleVersion.Version))]", 'Confirm information update.'
                ))
                {
                    # Unhide the file
                    Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Normal'

                    # Export the updated settings
                    $moduleInstallationInfo | Export-Clixml -Path $moduleInfoPath -Force

                    # Hide the file
                    Set-ItemProperty -Path $moduleInfoPath -Name 'Attributes' -Value 'Hidden'
                }
            }
            else
            {
                Write-Warning "Module [$($moduleVersion.Name) ($($moduleVersion.Version))] was not installed with the built-in package manager!"
            }
        }
    }
}
