if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}


$PSVersion = $PSVersionTable.PSVersion.Major
# PS Remotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artefacts\Localhost.CredentialHash.PSRemotely.tests.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\Remotely.json"
$RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)

# Create a new User named PSRemotely for testing the PSSession
$UserCred = New-Object -TypeName PSCredential -ArgumentList @('PSRemotely',$(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
$userCredHashtable = @{"$Env:COMPUTERNAME"=$UserCred}
New-User -Credential $UserCred 
Add-LocalUserToLocalAdminGroup -UserName PSRemotely
Disable-LocalAccountTokenFilterPolicy # This is needed to establish PSSession using the local user, revert in the end

try {
	Describe "PSRemotely CredentialHash usage, with PS V$($PSVersion)" -Tag Integration {
	
		# Act, Invoke Remotely
		$Result = Invoke-Remotely -Script @{
            Path=$RemotelyTestFile;
            Parameters= @{CredentialHash=$userCredHashtable}
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

	}

}
finally {
	Clear-RemotelyNodePath
    Remove-User -UserName PSRemotely
    Clear-RemoteSession
	Enable-LocalAccountTokenFilterPolicy
}
