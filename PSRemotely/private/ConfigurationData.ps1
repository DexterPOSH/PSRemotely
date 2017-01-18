# TO DO - Rename the below to Assert-ConfigData
Function Test-ConfigData {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[HashTable]$ConfigurationData
	)
	
	# Configuration Data should contain 'AllNodes' key
	if ( -not $ConfigurationData.ContainsKey('AllNodes')) {
		Throw 'ConfigurationData parameter need to have property AllNodes.'
	}

	# Configuration Data AllNodes should be an array
	if ($ConfigurationData['AllNodes'] -isnot [Array]) {
		throw 'ConfigurationData parameter property AllNodes needs to be a collection.'
	}

	$NodeNames = New-Object -TypeName 'System.Collections.Generic.HashSet[String]' -ArgumentList  ([System.StringComparer]::CurrentCultureIgnoreCase)
	foreach ($node in $ConfigurationData['AllNodes']) {
		if ($node -isnot [hashtable] -or -not $node['NodeName']) { # each element in the AllNodes need to be a hashtable & nodeName key should be present
			throw "all elements of AllNodes need to be hashtable and has a property 'NodeName'."	
		}

		# Check for the duplicate nodeName Values
		if ($NodeNames.Contains($node['NodeName'])) {
			# Duplicate node in the list
			throw $("There is a duplicate NodeName '{0}' in the configurationData passed in." -f $node['NodeName'])
		}

		$null = $NodeNames.Add($node['NodeName'])
	}
}


Function Update-ConfigData {
	[OutputType([Hashtable])]
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[Hashtable]$ConfigurationData
	)

	if ($configurationData.AllNodes | Where-Object -Property NodeName -eq '*') {
			$AllNodeSettings = $configurationData.AllNodes | Where-Object -Property NodeName -eq '*'
	}

	# Copy all the settings for the nodes
	If ($AllNodeSettings) {
		foreach ($node in $ConfigurationData['AllNodes']) {

			if ($node['NodeName'] -ne '*') {
				foreach ($nodekey in $AllNodeSettings.Keys) {
					
					if (-not $node.ContainsKey($nodeKey)) {
						$node.Add($nodeKey, $AllNodeSettings[$nodeKey])
					}
				}
			}
		}
	}

	# Remove the node named *
	$ConfigurationData['AllNodes'] = $ConfigurationData['AllNodes'] | Where-Object -Property 'NodeName' -ne '*'

	# is the below needed, the changes are directly done by reference to the input
	Write-Output -InputObject $ConfigurationData
}

# http://powershell.org/forums/topic/configuration-data-for-dsc-not-in-json/
Function LoadConfigDataFromFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True)]
		[String]$Path
	)

	Switch -Exact ([System.IO.Path]::GetExtension($Path)) {
		'.json' {
			$object = ConvertFrom-Json -InputObject $(Get-Content -Raw -Path $Path) 
			$hashTable = ConvertPSObjectToHashtable -InputObject $Object 
			Write-Output -InputObject $hashTable
			break
		}
		'.psd1' {
			Import-LocalizedData -BindingVariable hashTable -BaseDirectory $([System.IO.Path]::GetDirectoryName($Path)) -FileName $([System.IO.Path]::GetFileName($Path)) 
			Write-Output -InputObject $hashTable
		}
		default {
			throw 'specifying only a .json or .psd1 file for configdata supported'			
		}
	}
}

# Credits : Dave Wyatt's function here -> http://powershell.org/forums/topic/configuration-data-for-dsc-not-in-json/
function ConvertPSObjectToHashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}
