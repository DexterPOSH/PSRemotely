if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}

$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.IPv6Address.PSRemotely.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"
$RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)
# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force -ErrorAction SilentlyContinue # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}


Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Create a new User named PSRemotely for testing the PSSession
$UserCred = New-Object -TypeName PSCredential -ArgumentList @('PSRemotely',$(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
$userCredHashtable = @{"$Env:COMPUTERNAME"=$UserCred}
New-User -Credential $UserCred 
Add-LocalUserToLocalAdminGroup -UserName PSRemotely
Disable-LocalAccountTokenFilterPolicy # This is needed to establish PSSession using the local user, revert in the end
Start-Sleep -Seconds 4

try {

	Describe "PSRemotely IPv6Address usage, with PS V$($PSVersion)" -Tag Integration {
 		
		# Act, Invoke PSRemotely
		$Result = Invoke-PSRemotely -Script $RemotelyTestFile

		# Assert

		# Test if the PSSession was opened to the node using the supplied credential
		Context 'Validate that PSSession was created for the PSRemotely node using supplied CredentialHash' {
			$SessionHash = $Global:PSRemotely.SessionHashtable["::1"]

			It 'Should have opened a PSSession to the Node' {
				$SessionHash.Session | Should NOT BeNullOrEmpty	
			}

			It 'Should be in Opened state (live sessions maintained)' {
				$SessionHash.Session.State | Should Be 'Opened'
			}

            It 'Should use the Credentials in the Credential hash' {
                #$SessionHash.Credential | Should NOT BeNullOrEmpty
                $SessionHash.Credential.UserName | Should Be 'PSRemotely'
            }

			It 'Should use the IPAddress to connect for the PSRemoting session' {
                #$SessionHash.Credential | Should NOT BeNullOrEmpty
                $SessionHash.Session.ComputerName | Should Be '[::1]'
            }

			It 'Should have the valid Session name' {
				$SessionHash.Session.Name | SHould be 'PSRemotely-::1'
			}
		}


		Context 'Validate the Remote ops validation tests run on the node passed' {
			# Since the tests targeted were validating the $Node variable 
			# Assert that the tests passed
			$JsonObject = $Result | ConvertFrom-JSON 

			It "Should have passed all the tests for the Node" {
				$JsonObject.Status | Should Be $True
			}

			It "Should have targeted the correct Node" {
				$JsonObject.NodeName | Should Be '::1'
			}
		}

	}

}
finally {
	Clear-PSRemotelyNodePath
    Remove-User -UserName PSRemotely
    Clear-RemoteSession
	Enable-LocalAccountTokenFilterPolicy
	Reset-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
    Remove-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"
	Get-PSSession | Remove-PSSession

}
