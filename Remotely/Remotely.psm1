# module variables
# Path on the remotely nodes where the module are dropped along with tests files.
$Script:remotelyNodePath = 'C:\temp\Remotely' 
# FullyQualified list of module names which are copied over to remotely nodes.
$Script:modulesRequired = @(
    @{ModuleName="Pester";RequiredVersion="3.3.5"},
    @{ModuleName='PoshSpec';RequiredVersion='1.2.2'}
)

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

Export-ModuleMember -Function $Public.Basename