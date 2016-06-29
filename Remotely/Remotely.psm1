# read the Remotely.json file
$jsonObject = ConvertFrom-Json -InputObject $(Get-Content -Path "$PSScriptRoot\Remotely.Json" -Raw -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue
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
# read the remotely.json file 

$Remotely = ConvertPSObjectToHashTable -InputObject $jsonObject

# module variables
$Remotely.Add('NodeMap', @())
$Remotely.Add('sessionHashTable', @{})

Export-ModuleMember -Function $Public.Basename -Variable Remotely