if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}
$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.ConfigDataCredential.PSRemotely.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"
# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force  -ErrorAction SilentlyContinue # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}


# use a dummy artifact with PSRemotely-
Set-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
Copy-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"   

Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force


$UserCred = New-Object -TypeName PSCredential -ArgumentList @('PSRemotely',$(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
New-User -Credential $UserCred 
Add-LocalUserToLocalAdminGroup -UserName PSRemotely
Disable-LocalAccountTokenFilterPolicy 


try {
    Describe "PSRemotely ConfigData with Credential usage, with PS V$($PSVersion)" -Tag Integration {

        # Act, Invoke PSRemotely
        $Result = Invoke-PSRemotely -Script @{
            Path=$RemotelyTestFile;
            Parameters= @{Credential=$UserCred}
        }
        # Assert
        # Test if the PSSession was opened to the node using the supplied credential
		Context 'Validate that PSSession was created for the PSRemotely node using supplied CredentialHash' {
			$SessionHash = $Global:PSRemotely.SessionHashtable["$env:COMPUTERNAME"]

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
            $NodePSSession =  $Global:PSRemotely.SessionHashtable["$env:COMPUTERNAME"].session
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
finally {
    Clear-PSRemotelyNodePath
    Remove-User -UserName PSRemotely
    Clear-RemoteSession
	Enable-LocalAccountTokenFilterPolicy
    Reset-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
    Remove-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"
}
