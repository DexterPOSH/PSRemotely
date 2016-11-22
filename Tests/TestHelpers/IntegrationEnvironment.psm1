<#
    .Synopsis
        Function which will Initialize the localhost for the PS Remotely integration testing.

    .DESCRIPTION
        The function does the below:
        - Call Remotely\Clear-RemoteSession to clear the existing remote session.
        - Restart the WinRM service, just in case.
#>

Function Clear-RemotelyNodePath {
    param()

    $RemotelyJSONFile = "$Env:BHPSModulePath\Remotely.json"
    $RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile)

    Remove-Item -Path $RemotelyConfig.RemotelyNodePath -Recurse -Force
}