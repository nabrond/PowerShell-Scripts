<#
    .SYNOPSIS
        Updates the local copy of Sysinternals tools from a central source.

    .PARAMETER LocalPath
        Path on the local computer where Sysinternals tools are installed.

    .PARAMETER UpdateSource
        Path to the remote Sysinternals source.
        Default: \\\live.sysinternals.com\tools
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [System.String]
    $LocalPath,

    [Parameter()]
    [System.String]
    $UpdateSource = '\\live.sysinternals.com\Tools'
)

$updateDriveName = 'SysInternals'

## establish connection to the update source
Write-Debug "Connecting to $updateSource"
$updateDrive = New-PSDrive -Name $updateDriveName -PSProvider FileSystem -Root $UpdateSource -ErrorAction Stop

## loop over our current toolset
Get-ChildItem -Path $LocalPath | ForEach-Object {
    $currentTool = $_

    Write-Debug "Checking: $($currentTool.Name)"
    
    $updatedTool = Get-Item (Join-Path -Path "$($updateDriveName):" -ChildPath $currentTool.Name)
    
    Write-Debug "Local --> $($currentTool.LastWriteTimeUtc)"
    Write-Debug "Remote --> $($updatedTool.LastWriteTimeUtc)"

    ## compare last modified time in UTC
    if ($updatedTool.LastWriteTimeUtc -gt $currentTool.LastWriteTimeUtc)
    {
        if ($PSCmdlet.ShouldProcess($currentTool.BaseName, "Update"))
        {
            Write-Debug "Begin copy process"

            ## copy the updated tool to the local system
            Copy-Item -Path $updatedTool.FullName -Destination $currentTool.FullName -Force | Out-Null
            Write-Debug "End copy process"
        }
    }
}

## disconnect from update source
Write-Debug "Closing connection to $updateSource"
$updateDrive | Remove-PSDrive
