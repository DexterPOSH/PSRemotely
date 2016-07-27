Function UpdateRemotelyNodeMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [HashTable]$ModuleStatus,

        [Parameter(Mandatory)]
        [bool]$PathStatus,

        [Parameter(Mandatory)]
        [String]$NodeName
    )
    $nodeName = $NodeName.Replace('[','')
    $nodeName = $nodeName.Replace(']','')
    $nodeExists = $Remotely.NodeMap | Where-Object -Property NodeName -eq $NodeName
    if ($nodeExists) {
        $nodeExists.PathStatus = $PathStatus
        $nodeExists.ModuleStatus = $ModuleStatus    
    }
    else {
        $Remotely.NodeMap += @{
            NodeName = $NodeName;
            PathStatus = $PathStatus;
            ModuleStatus = $ModuleStatus;
        }
    }
    
}

Function TestRemotelyNodeBootStrapped {
    [CmdletBinding(DefaultParameterSetName='SessionInfo')]
    param(
        [Parameter(Mandatory, ParameterSetName='SessionInfo')]
        $SessionInfo,

        [Parameter(Mandatory, ParameterSetName='ComputerName')]
        [String]$ComputerName

    )
    if ($Remotely.NodeMap.Count -gt 0) {
        Switch -Exact ($PSCmdlet.ParameterSetName) {
            'SessionInfo' {
                $node = $Remotely.NodeMap | Where -Property NodeName -eq $($SessionInfo.Session.ComputerName)
                break
            }
            'ComputerName' {
                $node = $Remotely.NodeMap | Where -Property NodeName -eq $ComputerName
                break
            }
        }
        
        if($node) {
            if($node.pathStatus -and $($node.moduleStatus.Values -notcontains $False)) {
                $True
            }
            else {
                $false  # node is either missing the path or module bootstrapping
            }
        }
        else {
            $false
        }
    }
    else {
        $False
    }
}

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
    # at the beginning read the status of the node
	$ModuleStatus, $pathStatus = TestRemotelyNode @PSBoundParameters
    # Add the above information to the Remotely var
    UpdateRemotelyNodeMap -ModuleStatus $ModuleStatus -PathStatus $PathStatus -NodeName $session.ComputerName

    if ($pathStatus -and $($moduleStatus.Values -notcontains $False)) {
        # Node is already bootstrapped, no need to take action
    }
    else {
        # Node is missing some of the configs, bootstrap it
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

        # at the end update the status of the node
        $ModuleStatus, $pathStatus = TestRemotelyNode @PSBoundParameters
        # Add the above information to the Remotely var
        UpdateRemotelyNodeMap -ModuleStatus $ModuleStatus -PathStatus $PathStatus -NodeName $session.ComputerName
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
		$FullyQualifiedName | Foreach-Object -Process {$outputHash.Add($PSItem.Name, $false)	}

        if (Test-Path -path "$remotelyNodePath\Lib\Artefacts" -PathType Container) {
		    foreach($module in $FullyQualifiedName) {
                $moduleName=$module.Name
                $moduleVersion=$module.version
                if(Test-Path -Path "$remotelyNodePath\lib\$moduleName\$moduleVersion") {
                    # module present
                    $outputHash[$($module.Name)] = $true
                }
                else {
                   $outputHash[$($module.Name)] =  $false	
                }
            }	
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
    Invoke-Command -Session $session -ScriptBlock {
        $null = New-Item -Path "$using:Path\lib\artefacts" -ItemType Directory -Force
    }
}

Function TestModulePresentInLib {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName
    )
    $LibPath  = Resolve-Path -Path $PSScriptRoot\..\lib | Select-Object -ExpandProperty Path
    $ModulePath = '{0}\{1}' -f  $FullyQualifiedName.Name, $FullyQualifiedName.Version
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
            CopyModuleFolderToRemotelyNode -path "$LibPath\$moduleName\$moduleVersion" -Destination "$($Remotely.remotelyNodePath)\lib\$moduleName" -session $session -ErrorAction Stop
        }
        else {
            throw "Lib folder does not have a folder named $($moduleName)\$($moduleVersion), so it can't be copied to the remotely node."
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
   Invoke-Command -Session $Session -ScriptBlock {$null = New-Item -Path $Using:Destination -ItemType Directory} -ErrorAction SilentlyContinue
   #$folderName = Split-Path -Path $Path -Leaf
   Copy-Item -Path "$Path" -Destination $Destination -Recurse -ToSession $session  -Force
}


Function CopyTestsFileToRemotelyNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,


        [Parameter(Mandatory)]
        [String]$TestName,

        [Parameter(Mandatory)]
        [String]$TestBlock
    )

    
    $copyTestsFileParams = @{
        'Session' = $session;
        'ArgumentList' = @($Remotely, $testName, $testBlock)
        'Scriptblock' = {
            param(
                [HashTable]$Remotely,
                [String]$testName,
                [String]$testBlock
            )
            # generate the test file name..naming convention -> NodeName.TestName.Tests.ps1
            $testFileName = "{0}.{1}.Tests.ps1" -f $Env:COMPUTERNAME, $testName.replace(' ','_')
            $testFile = "$($Remotely.remotelyNodePath)\$testFileName"
            if ($Node) { 
                # Check if the $Node var was populated in the remote session, then add param node to the test block
                $testBlock = $testBlock.Insert(0,"param(`$node)`n")
            }
            Set-Content -Path $testFile -Value $testBlock -Force
        };
    }
    Invoke-Command @copyTestsFileParams 
}

Function CleanupRemotelyNodePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,

        [Parameter(Mandatory)]
        [String]$RemotelyNodePath
    )
    $cleanupParams = @{
        'Session' = $session;
        'ArgumentList' = $RemotelyNodePath
        'ScriptBlock' = {
            param([String]$path)

            if ( -not (Test-Path -Path $Path\archive -PathType Container)) {
                $null = New-Item -Path "$Path\archive" -ItemType Directory
            }
            Get-ChildItem -Path $Path -File |
                Move-Item -Destination "$path\archive" -Force
        }
    }
    Invoke-Command @cleanupParams

}