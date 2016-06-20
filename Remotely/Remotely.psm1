# module variables
$Remotely = @{
    remotelyNodePath = 'C:\temp\Remotely';
    modulesRequired = @(
        @{ModuleName="Pester";ModuleVersion="3.3.14"},
        @{ModuleName='PoshSpec';ModuleVersion='2.1.6'}
    )
    NodeMap = @()
    sessionHashTable = @{}
}
#Get public and private function definition files.
    $public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
    Foreach($import in @($public + $private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

# Here I might...
    # Read in or create an initial config file and variable
    # Export Public functions ($Public.BaseName) for WIP modules
    # Set variables visible to the module and its functions only

Export-ModuleMember -Function $Public.Basename -Variable Remotely