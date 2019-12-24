[CmdletBinding(SupportsShouldProcess)]
param()

Write-Verbose 'Find installed modules...'
$installedModules = Get-InstalledModule

Write-Verbose 'Begin processing modules'
foreach ($module in $installedModules)
{
    Write-Verbose "  > $($module.Name)"

    # Get all versions for the module
    $priorVersions = Get-Module -Name $module.Name -ListAvailable |
        Where-Object -Property Version -lt $module.Version

    $versionList = $priorVersions.Version -join '; '

    if ($PSCmdlet.ShouldProcess("$($module.Name) ($versionList)", 'Uninstall'))
    {
        # Uninstall the modules
        $priorVersions | Uninstall-Module -Force
    }
}

Write-Verbose 'Process complete!'