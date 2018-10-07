[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
param
(
    # Path to the local copy of the Sysinternal tools
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [System.String]
    $LocalPath,

    [System.String]
    $UpdateSource = '\\live.sysinternals.com\Tools'
)

$updateDriveName = 'SysInternals'

## establish connection to the update source
Write-Verbose "Connecting to $updateSource"
$updateDrive = New-PSDrive -Name $updateDriveName -PSProvider FileSystem -Root $UpdateSource -ErrorAction Stop

## loop over our current toolset
Get-ChildItem -Path $LocalPath | ForEach-Object {
    $currentTool = $_

    Write-Verbose "Checking: $($currentTool.Name)"
    
    $updatedTool = Get-Item (Join-Path -Path "$($updateDriveName):" -ChildPath $currentTool.Name)
    
    Write-Verbose " Local = $($currentTool.LastWriteTimeUtc); Remote = $($updatedTool.LastWriteTimeUtc)"

    ## compare last modified time in UTC
    if ($updatedTool.LastWriteTimeUtc -gt $currentTool.LastWriteTimeUtc)
    {
        if ($PSCmdlet.ShouldProcess($currentTool.BaseName, "Update"))
        {
            Write-Output " Updating $($currentTool.BaseName)"
            Write-Verbose "  >> Begin copy process"

            ## copy the updated tool to the local system
            Copy-Item -Path $updatedTool.FullName -Destination $currentTool.FullName -Force | Out-Null
            Write-Verbose "  >> End copy process"
        }
    }
}

## disconnect from update source
Write-Verbose "Closing connection to $updateSource"
$updateDrive | Remove-PSDrive