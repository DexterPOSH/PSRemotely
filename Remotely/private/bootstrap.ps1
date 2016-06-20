Function BootstrapRemotelyNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]$FullyQualifiedName,

		[Parameter()]
		[String]$remotelyNodePath
    )
        
	$ModuleStatus, $pathStatus = TestRemotelyNode @PSBoundParameters
    foreach ($hash in $moduleStatus.GetEnumerator()) {

		if ($hash.Value) {
			# module present on the remote node
		}
		else {
			# module not present on the remote node
			CopyRemotelyNodeModule -Session $session -FullyQualifiedName $($FullyQualifiedName | Where -Property Name -EQ $hash.Name)
		}
	}
	
	if ($pathStatus) {
		# remotely node path created
	}
	else {
		CreateRemotelyNodePath	-session $session -Path $remotelyNodePath
	}
}

Function TestRemotelyNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]$FullyQualifiedName,

		[Parameter()]
		[String]$remotelyNodePath
    )
    
    Invoke-Command -Session $session -ArgumentList $FullyQualifiedName,$remotelyNodePath -ScriptBlock {
		param(
			$FullyQualifiedName,
			$remotelyNodePath
		)
		$outputHash = @{}
		foreach($module in $FullyQualifiedName) {
			if(Get-Module -FullyQualifiedName @{ModuleName=$module.Name; ModuleVersion=$module.version} -ListAvailable) {
				# module present
				$outputHash.Add($module.Name, $true)
			}
			else {
				$outputHash.Add($module.Name, $false)	
			}
		}
						
		if (Test-Path -path $remotelyNodePath -PathType Container) {
			$outputHash,$true
		}
		else {
			$outputHash, $false
		}
	} 
}

Function CreateRemotelyNodePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,

        [Parameter()]
        [String]$Path
    )
    Invoke-Command -Session $session -ScriptBlock {$null = New-Item -Path $using:Path -ItemType Directory -Force}
}

Function TestModulePresentInLib {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName
    )
    $LibPath  = Resolve-Path -Path $PSScriptRoot\..\lib | Select-Object -ExpandProperty Path
    $ModulePath = '{1}_{2}' -f $PSScriptRoot, $FullyQualifiedName.Name, $FullyQualifiedName.Version
    Test-Path -Path "$libPath\$modulePath" -ErrorAction Stop 
}

Function CopyRemotelyNodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName)

    # copy the modules from the lib directory
    $moduleName = $FullyQualifiedName.Name
    $moduleVersion = $FullyQualifiedName.Version
    
    # now copy the module to the remote node
    TRY {
        if (testModulePresentInLib -FullyQualifiedName $FullyQualifiedName) {
            $LibPath  = Resolve-Path -Path $PSScriptRoot\..\lib | Select-Object -ExpandProperty Path
            CopyModuleFolderToRemotelyNode -path "$LibPath\$moduleName*\*" -Destination "$Script:remotelyNodePath\$moduleName" -session $session -ErrorAction Stop
        }
        else {
            throw "Lib folder does not have a folder named $($moduleName)_$($moduleVersion), so it can't be copied to the remotely node."
        }
        
    }
    CATCH {
        $PSCmdlet.ThrowTerminatingError($PSitem)
    }
}

Function CopyModuleFolderToRemotelyNode {
   [CmdletBinding()]
   param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,

        # Source folder to copy.
        [Parameter(Mandatory)]
        [String]$Path,

        # Destination where the copy is created.
        [Parameter(Mandatory)]
        [String]$Destination
   )
   #$folderName = Split-Path -Path $Path -Leaf
   Copy-Item -Path "$Path\*" -Destination $Destination -ToSession $session  -Force
}
