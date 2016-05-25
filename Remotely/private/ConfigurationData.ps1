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
			throw ("There are duplicated NodeNames '{0}' in the configurationData passed in." -f $node['NodeName'])
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

	if ($configurationData.AllNodes.Where({$PSitem.NodeName -eq '*'})) {
			$AllNodeSettings = $Node
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

	Write-Output -InputObject $ConfigurationData
}