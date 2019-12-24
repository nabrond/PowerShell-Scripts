[CmdletBinding()]
param()

Write-Verbose 'Checking installed modules...'

Get-InstalledModule | ForEach-Object { 
    $Latest = $_

    Write-Verbose "  > $($_.Name)"

    Get-InstalledModule $Latest.Name -AllVersions | 
        Where-Object { $_.Version -ne $Latest.Version } | 
        Uninstall-Module -Force -Verbose:$VerbosePreference
}

Write-Verbose 'Process complete!'