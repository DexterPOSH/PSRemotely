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
    
    Invoke-Command -Session $session -ArgumentList $FullyQualifiedName, $session -ScriptBlock {
		param(
			$FullyQualifiedName,
			$remotelyNodePath
		)
		$outputHash = @{}
		foreach($module in $FullyQualifiedName) {
			if(Get-Module -FullyQualifiedName $module -ListAvailable) {
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

Function CopyRemotelyNodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName)

    $moduleLocalInfo = Get-Module -ListAvailable -FullyQualifiedName $FullyQualifiedName
    $moduleName = $FullyQualifiedName.Name
	$moduleVersion = $FullyQualifiedName.RequiredVersion.ToString()
    
    if (-Not $moduleLocalInfo) {
        Write-Warning -Message "$FullyQualifiedName not found locally. Trying to download it from PowerShell gallery."
        # TODO Add a Confirm dialog here ?
        TRY {
            # try to fetch it from PowerShell gallery
            Import-Module -Name PackageManagement -ErrorAction Stop
            if ($FullyQualifiedName.RequiredVersion) {
                Install-Module -Name $FullyQualifiedName.Name -RequiredVersion $FullyQualifiedName.RequiredVersion -ErrorAction Stop
            }
            else {
                Install-Module -Name $FullyQualifiedName.Name -RequiredVersion $FullyQualifiedName.Version -ErrorAction Stop
            }
            $moduleLocalInfo = Get-Module -ListAvailable -Name $ModuleName
            if (-not $moduleLocalInfo) {
                throw "$FullyQualifiedName is not installed."
            }
        }
        CATCH {
            Write-Warning -Message $PSItem.Exception
            throw "$FullyQualifiedName is not installed."
        }
    }
    # now copy the module to the remote node
    TRY {
        $modulePath  = Split-Path -Path $moduleLocalInfo.path  -Parent
        CopyModuleFolderToRemotelyNode -path "$modulePath\*" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\$moduleVersion" -session $session -ErrorAction Stop
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
