Function BootstrapRemotelyNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]$FullyQualifiedName
    )
        
    foreach ($module in $FullyQualifiedName) {

        if ( -not (TestRemotelyNodeModule -session $Session -FullyQualifiedName $module)) {
            TRY {
                CopyRemotelyNodeModule -session $Session -FullyQualifiedName $module -ErrorAction Stop
            }
            CATCH {
                # log error
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
        }
    }
}

Function TestRemotelyNodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName
    )
    
    $moduleThere = Invoke-Command -Session $Session -ScriptBlock {Get-Module -ListAvailable -Name $Using:FullyQualifiedName.Name} 
    if (-Not $moduleThere) {
        $false # write False
    }
    else {
        $true # write True
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
    $pathPresent = Invoke-Command -Session $session -ScriptBlock {Test-Path -Path $using:Path}
    if (-not $pathPresent) {
        Invoke-Command -Session $session -ScriptBlock {$null = New-Item -Path $using:Path -ItemType Directory -Force}
    }
}

Function CopyRemotelyNodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$session,
        
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]$FullyQualifiedName)

    $moduleLocalInfo = Get-Module -ListAvailable -Name $FullyQualifiedName.Name
    $ModuleName = $FullyQualifiedName.Name
    
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
        CreateRemotelyNodePath -session $session -Path "$RemotelyNodePath\$ModuleName" -ErrorAction Stop
        # TO DO check if the zip already exists before copying
        #Copy-Item -Path $ZipLocalPath -Destination $RemotelyNodePath -ToSession $session -Force -ErrorAction Stop
        CopyModuleFolderToRemotelyNode -path "$modulePath\*" -Destination "$RemotelyNodePath\$ModuleName" -session $session -ErrorAction Stop
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
