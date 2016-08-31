[CmdletBinding()]
param()

## Local path for Sysinternals tools
$toolPath = ""

## Sysinternals SMB share
$updateSource = "\\live.sysinternals.com\Tools"

## establish connection to the update source
Write-Verbose "Connecting to $updateSource"
net use $updateSource | Out-Null

## loop over our current toolset
Get-ChildItem -Path $toolPath | ForEach-Object {
    $currentTool = $_

    Write-Verbose "Checking: $($currentTool.Name)"
    
    $updatedTool = Get-Item (Join-Path -Path $updateSource -ChildPath $currentTool.Name)
    
    if ($updatedTool.LastWriteTimeUtc -gt $currentTool.LastWriteTimeUtc)
    {
        Write-Host " Updating $($currentTool.BaseName)"
        Write-Verbose "  >> Out of Date"
        Copy-Item -Path $updatedTool.FullName -Destination $currentTool.FullName -Force | Out-Null
        Write-Verbose "  >> Update complete"
    }
}

## disconnect from update source
Write-Verbose "Closing connection to $updateSource"
net use $updateSource /del | Out-Null