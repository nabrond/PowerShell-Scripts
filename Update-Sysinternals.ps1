[CmdletBinding()]
param
(
    # Path to the local copy of the Sysinternal tools
    [Parameter(Mandatory = $true)]
    [string]
    $LocalPath
)

if (!Test-Path -Path $LocalPath -PathType Container)
{
    throw "LocalPath must be a valid directory!"
}

## Sysinternals SMB share
$updateSource = "\\live.sysinternals.com\Tools"

## establish connection to the update source
Write-Verbose "Connecting to $updateSource"
net use $updateSource | Out-Null

## loop over our current toolset
Get-ChildItem -Path $LocalPath | ForEach-Object {
    $currentTool = $_

    Write-Verbose "Checking: $($currentTool.Name)"
    
    $updatedTool = Get-Item (Join-Path -Path $updateSource -ChildPath $currentTool.Name)
    
    ## compare last modified time in UTC
    if ($updatedTool.LastWriteTimeUtc -gt $currentTool.LastWriteTimeUtc)
    {
        Write-Host " Updating $($currentTool.BaseName)"
        Write-Verbose "  >> Begin copy process"
        Copy-Item -Path $updatedTool.FullName -Destination $currentTool.FullName -Force | Out-Null
        Write-Verbose "  >> End copy process"
    }
}

## disconnect from update source
Write-Verbose "Closing connection to $updateSource"
net use $updateSource /del | Out-Null