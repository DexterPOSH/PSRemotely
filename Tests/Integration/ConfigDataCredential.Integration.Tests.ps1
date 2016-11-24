if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force


$PSVersion = $PSVersionTable.PSVersion.Major
# PS Remotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artefacts\Localhost.ConfigDataCredential.PSRemotely.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\Remotely.json"

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}

$UserCred = New-Object -TypeName PSCredential -ArgumentList @('PSRemotely',$(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
New-User -Credential $UserCred 
Add-LocalUserToLocalAdminGroup -UserName PSRemotely
Disable-LocalAccountTokenFilterPolicy 


try {
    Describe "PSRemotely ConfigData with Credential usage, with PS V$($PSVersion)" -Tag Integration {
        
        # Act, Invoke Remotely
        $Result = Invoke-Remotely -Script @{
            Path=$RemotelyTestFile;
            Parameters= @{Credential=$UserCred}
        }
        # Assert
        # Test if the PSSession was opened to the node using the supplied credential
		Context 'Validate that PSSession was created for the Remotely node using supplied CredentialHash' {
			$SessionHash = $Global:Remotely.SessionHashtable["$env:COMPUTERNAME"]

			It 'Should have opened a PSSession to the Node' {
				$SessionHash.Session | Should NOT BeNullOrEmpty	
			}

			It 'Should be in Opened state (live sessions maintained)' {
				$SessionHash.Session.State | Should Be 'Opened'
			}

            It 'Should use the Credentials in the Credential hash' {
                $SessionHash.Credential | Should NOT BeNullOrEmpty
                $SessionHash.Credential.UserName | Should Be 'PSRemotely'
            }
		}

        Context 'Node data should Be populated in the Node PSSession' {
            $NodePSSession =  $Global:Remotely.SessionHashtable["$env:COMPUTERNAME"].session
            $NodeResult = Invoke-Command -Session $NodePSSession -ScriptBlock {return $Node}
            
            It "Should have `$Node variable defined in the Remote PSSession" {
                $NodeResult | Should NOT BeNullOrEmpty
            }

            It "Should have the common properties from ConfigData" {
                $NodeResult.DomainFQDN | Should Be 'Dexter.lab'
            }

            It 'Should have Node specific properties' {
                $NodeResult.ServiceName | Should Be 'bits'
                $NodeResult.Type | Should Be 'Compute'
                $NodeResult.NodeName | Should Be "$env:COMPUTERNAME"
            }
        } 
    }
}
catch {
    Clear-RemotelyNodePath
    Remove-User -UserName PSRemotely
    Clear-RemoteSession
	Enable-LocalAccountTokenFilterPolicy
}
