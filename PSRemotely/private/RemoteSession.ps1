function CopyStreams
{
    param
    (
        [Parameter(Position=0, Mandatory=$true)] 
        $inputStream
    ) 

    $outStream = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'

    foreach($item in $inputStream)
    {
        $outStream.Add($item)
    }

    $outStream.Complete()

    ,$outStream
}

function AddArgumentListtoSessionVars {
	[CmdletBinding()]
	param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()] $session
    )
	$InvokeCommandParams= @{
		Scriptblock={
						if ($PSSenderInfo.ApplicationArguments.Keys -ne 'PSVersionTable')  {
							# there are arguments passed to the session other than PSversionTable, add them to the current session
							$PSSenderInfo.ApplicationArguments.Keys -ne 'PSversionTable' |
								Foreach-Object -Process {
									New-Variable -Name $PSitem -Value  $PSSenderInfo.ApplicationArguments[$PSitem] -Force
								}
						}
					};
		Session = $session;
		ErrorAction = 'Stop';
	}
	Invoke-Command 	@InvokeCommandParams
}

function CreateSessions
{
	[CmdletBinding(DefaultParameterSetName='Computername')]
    param
    (
        [Parameter(Mandatory, ParameterSetName='ComputerName')]
        [string[]] $Nodes,

        [Parameter()]
        $CredentialHash,

		[Parameter()]
		[hashtable]$ArgumentList,

		[Parameter(ParameterSetName='ConfigurationData')]
		[HashTable]$ConfigData
    )

	# try to see if there are already open PSSessions, which are available
	$existingPSSessions = @(Get-PSSession -Name PSRemotely* | Where-Object -FilterScript { ($PSitem.State -eq 'Opened') -and ($PSitem.Availability -eq 'available')})
	Switch -Exact ($PSCmdlet.ParameterSetName) {
		'ComputerName' {
			
			foreach($Node in $Nodes)
			{ 
				if(-not $PSRemotely.SessionHashTable.ContainsKey($Node))
				{                                   
					$sessionName = "PSRemotely-" + $Node 
					$existingPSSession = $existingPSSessions | Where-Object -Property Name -eq $SessionName  | select-Object -First 1                        
					if ($existingPSSession) {
						$sessionInfo = CreateSessionInfo -Session $existingPSSession	
					}
					else {
						if ($CredentialHash -and $CredentialHash[$Node]) {
							$sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName -Credential $CredentialHash[$node] -SessionOption $PSSessionOption) -Credential $CredentialHash[$node]
						}
						else {
							$sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName -SessionOption $PSSessionOption)  
						}
					}
					$PSRemotely.SessionHashTable.Add($node, $sessionInfo)
				}
				# set the variables in the remote pssession
				ReinitializeSession -SessionInfo $PSRemotely.sessionHashTable[$node] -ArgumentList $argumentList
			}
			break
		}
		'ConfigurationData' {
			# since this is Configuration data parameter set, which means it was supplied.
			# Call Clear-RemoteSession
			foreach ($node in $ConfigData.AllNodes) {
				$argumentList = $Script:argumentList.clone()
				$argumentList.Add('Node',$node) # Add this as an argument list, so that it is availabe as $Node in remote session
				
                if( -not $PSRemotely.SessionHashTable.ContainsKey($Node.NodeName)) {
				    # SessionHashtable does not have an entry                              
					$sessionName = "PSRemotely-" + $Node.NodeName
					$existingPSSession = $existingPSSessions | Where-Object -Property Name -eq $SessionName  | select-Object -First 1                     
					if ($existingPSSession) {
                        # if there is an open PSSession to the node then use it to create Session info object
						$sessionInfo = CreateSessionInfo -Session $existingPSSession
					}
                    else {
						$PSSessionParams = @{
							ComputerName = $Node.NodeName
							Name = $("PSRemotely-{0}" -f $Node.NodeName)
						}

					    if ($node.Credential) {
						    # if the node has a key called credential set then use it to create the pssession, First priroity
							# Remove the Credential attribute from the Node data, it is not serializable to be sent using argument list
							$Credential = $node.Credential
							$PSSessionParams.Add('Credential',$Credential)
							#$node.Remove('Credential')
							$ArgumentList.Node.Remove('Credential')
							
					    }
					    elseif ($CredentialHash -and $CredentialHash[$Node.NodeName]) {
                            $Credential = $CredentialHash[$node.NodeName]
							$PSSessionParams.Add('Credential',$Credential)
							
					    }
					    else {
						    #$sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node.NodeName -Name $sessionName -SessionOption $PSSessionOption)
					    }
						$PSSessionOption = New-PSSessionOption -ApplicationArguments $argumentList  -NoMachineProfile
						[ValidateNotNullOrEmpty()]$session = New-PSSession @PSSessionParams -SessionOption $PSSessionOption
						[ValidateNotNullOrEmpty()]$sessionInfo = CreateSessionInfo -Session $session -Credential $credential
                    }
					# Add the information to the session hashtable in $PSRemotel
					$PSRemotely.SessionHashTable.Add($($node.NodeName), $sessionInfo)
				}
				# set the variables in the remote pssession
				ReinitializeSession -SessionInfo $PSRemotely.sessionHashTable[$node] -ArgumentList $argumentList
			} # end foreach 
			break
		}
	}
}

function CreateLocalSession
{    
    param(
        [Parameter(Position=0)] $Node = 'localhost'
    )

    if(-not $PSRemotely.SessionHashTable.ContainsKey($Node))
    {
        $sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName)
        $PSRemotely.SessionHashTable.Add($Node, $sessionInfo)
    } 
}

function CreateSessionInfo
{
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.PSSession] $Session,

        [Parameter(Position=1)]
        [pscredential] $Credential
    )
    return [PSCustomObject] @{ Session = $Session; Credential = $Credential}
}

function CheckAndReconnect
{
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()] $sessionInfo
    )

    if($sessionInfo.Session.State -ne [System.Management.Automation.Runspaces.RunspaceState]::Opened)
    {
        Write-Verbose "Unexpected session state: $sessionInfo.Session.State for machine $($sessionInfo.Session.ComputerName). Re-creating session" 
        if($sessionInfo.Session.ComputerName -ne 'localhost')
        {
            if ($sessionInfo.Credential)
            {
                $sessionInfo.Session = New-PSSession -ComputerName $sessionInfo.Session.ComputerName -Credential $sessionInfo.Credential
            }
            else
            {
                $sessionInfo.Session = New-PSSession -ComputerName $sessionInfo.Session.ComputerName
            }
        }
        else
        {
            $sessionInfo.Session = New-PSSession -ComputerName 'localhost'
        }
    }
}

# add this function to re-initialize the entire argument list (along with $node var) in the remote session
Function ReinitializeSession {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()] $sessionInfo,

		[Parameter(Position=1, Mandatory=$true)]
		[ValidateNotNullOrEmpty()] 
		[HashTable]$ArgumentList
	)
	TRY {
		$sessionInfo.Session.Runspace.ResetRunspaceState() # reset the runspace state
	}
	CATCH {
		# TO DO : above fails some time. Check why.
	}
	Invoke-Command -Session $sessionInfo.Session -ArgumentList $argumentList -ScriptBlock {
		param($arglist)
		foreach ($enum in $arglist.GetEnumerator()) {
			New-Variable -Name $enum.Key -Value $enum.Value -Force
		}
	}
}
 