Function Enter-PSRemotely {
    [CmdletBinding()]
    param (
        # Specify this switch to get the PSSession object
        [Switch]$PassThru
    )

    DynamicParam {
        # Add a dynamic parameter 'NodeName' which discovers the PSRemotely nodes by looking at
        # the $PSRemotely global variable
        if ($Global:PSRemotely) {
                # only add this dynamic parameter if the $PSRemotely global var exists
                #create a new ParameterAttribute Object
                $NodeNameAttribute = New-Object System.Management.Automation.ParameterAttribute
                $NodeNameAttribute.Position = 1
                $NodeNameAttribute.Mandatory = $true
                $NodeNameAttribute.ParameterSetName = '__AllParameterSets'
                $NodeNameAttribute.HelpMessage = "Enter the remotely node name to connect to"
    
                #create an attributecollection object for the attribute we just created.
                $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
                $AvailablePSRemotelyNodeNames = @($Global:PSRemotely.SessionHashTable.Keys)
                # add the PSRemotely node names to the attributecollection
                $attributeCollection.Add(
                    (New-Object -TypeName System.Management.Automation.ValidateSetAttribute(
                        $AvailablePSRemotelyNodeNames)
                    )
                )
                #add our custom attribute
                $attributeCollection.Add($NodeNameAttribute)
    
                #add our paramater specifying the attribute collection
                $NodeNameParam = New-Object System.Management.Automation.RuntimeDefinedParameter('NodeName', [String], $attributeCollection)
    
                #expose the name of our parameter
                $NodeNameDic  = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $NodeNameDic.Add('NodeName', $NodeNameParam)
                return $NodeNameDic 
        }
    }
    Process {
        
        $SessionInfo = $Global:PSRemotely.SessionHashTable[$($PSBoundParameters.NodeName)]
        
        $Session = $Global:PSRemotely.SessionHashTable[$($PSBoundParameters.NodeName)].Session
        if ($Session){

            if ($Session.State -ne 'Opened'){
                # Re-connect to the node. Note the $Node variable populated earlier is now lost.
                CheckAndReconnect -SessionInfo $SessionInfo
                # since the session is re-connected, set the value back in the $session variable to use.
                $Session = $Global:PSRemotely.SessionHashTable[$($PSBoundParameters.NodeName)].Session
                # Reinitialize Session with the PSRemotely variable
                ReinitializeSession -SessionInfo $SessionInfo -ArgumentList @{PSRemotely=$PSRemotely}
            }
             
            $IsConfigurationDataUsed = Invoke-Command -Session $Session -ScriptBlock {return $Node} -ErrorAction SilentlyContinue
            if ($IsConfigurationDataUsed) {
                $PSRemotelyParameterSet= 'ConfigurationData'
            }
            else {
                $PSRemotelyParameterSet = 'NodeName'    
            }
            Switch ($PSRemotelyParameterSet) {
                'ConfigurationData' {
                    $ScriptBlock = {
                        param(
                            [Parameter()]
                            $Node=$Node, # point this by default to $Node populated in remote session

                            [Parameter()]
                            $Path,

                            [Parameter()]
                            $PSRemotely= $Global:PSRemotely
                        )
                        try {
                        if (-not $Path){ 
                            $Path = "$($Global:PSRemotely.PSRemotelyNodePath)\*.ps1"
                        }
                            Set-Location -Path $PSRemotely.PSRemotelyNodePath
                            Invoke-Pester -Script @{Path=$Path;Parameters=@{Node=$Node}}
                        }
                        catch {
                            Write-Warning -Message "[Warning] $($PSItem.Exception.Message)"
                        }
                    }
                }
                'NodeName' {
                    $ScriptBlock = {
                        param()
                        try {
                            Invoke-Pester -Path $PSRemotely.PSRemotelyNodePath
                        }
                        catch {
                            Write-Warning -Message "[Warning] $($PSItem.Exception.Message)"
                        }
                    }
                }
            }
            # Inject the Invoke-PSRemotely function, based on whether the environment config data was specified or not.
            Invoke-Command -Session $Session -ScriptBlock { 
                $null = New-Item -Path Function:\ -Name Invoke-PSRemotely -Value $Using:ScriptBlock -Force
                $null = Set-Location -Path $PSRemotely.PSRemotelyNodePath -ErrorAction SilentlyContinue
            }
            
            if ($PassThru.IsPresent) {
                Write-Output -InputObject $Session
            }
            else {

                # Enter the PSSession interactively
                Enter-PSSession -Session $Session
            }
        }
        
    }
}
