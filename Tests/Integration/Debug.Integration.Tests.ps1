if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}

$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.ConfigDataPreferNodeProperty.PSRemotely.ps1"
$RemotelyJSONFile = "$ENV:BHModulePath\PSRemotely.json"
$ArtifactsPath = "$ENV:BHModulePath\lib\Artifacts"

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force  -ErrorAction SilentlyContinue # reload the module, the script module might have changes
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
    Describe "Debugging using Enter-PSRemotely function" {
        # Act, Invoke PSRemotely
		$Result = Invoke-PSRemotely -Script $RemotelyTestFile

        Context "Connecting to the remotely node's debug PSSession" {

            # fetch the session object and the function info
            $Session = Enter-PSRemotely -NodeName Node1 -PassThru
            $FunctionInfo = Invoke-Command -Session $Session -ScriptBlock {
                Get-Command -Name Invoke-PSRemotely 
            }
            # Case where the underlying PSSession to the remotely node is open
            It "Should have connected to the PSRemotely-Node1 named PSSession" {
                $Session.Name | Should Be 'PSRemotely-Node1'
            }

            It "Should have the PSSession state as opened" {
                $Session.State | Should Be 'Opened'
            }

            It "Should have `$Node & `$PSRemotely variable defined in the remote PSSession" {
                # This would confirm that we connected to the correct PSSession
                Invoke-Command -Session $Session -ScriptBlock {
                    @(Test-Path -Path Variable:\Node, Variable:PSRemotely) -notContains $False
                } | Should Be $True
            }

            It "Should inject the correct Invoke-PSRemotely function into the remote PSSession for debugging purpose" {
                $FunctionInfo.Parameters.ContainsKey('Node') | Should Be $True
            }
        }
        
        Context "Connecting to the remotely node's broken/disconnected/closed PSSession" {
            # Case where the underlying PSSession to the remotely node is broken
            # Enter-PSRemotely function should be able to re-connect to the remotely node with a gotcha
            # Gotcha is that the $node variable is lost when reconnecting

            # First disconnect the session
            $OldSession = Enter-PSRemotely -NodeName Node1 -PassThru
            $OldFunctionInfo = Invoke-Command -Session $OldSession -ScriptBlock {
                Get-Command -Name Invoke-PSRemotely 
            }
            Disconnect-PSSession -Session $OldSession

            # Now invoke the Enter-PSRemotely again, it should create a new pssession to the node
            $NewSession = Enter-PSRemotely -NodeName Node1 -PassThru
            $NewFunctionInfo = Invoke-Command -Session $NewSession -ScriptBlock {
                Get-Command -Name Invoke-PSRemotely 
            }

            It "Should have created a new PSSession in place of the disconnected/broken/closed PSSession" {
                $OldSession.State | Should Be 'Disconnected'
                $NewSession.State | Should Be 'Opened'
            }


            It "Should NOT have `$Node variable defined in new PSSession" {
                # Since a new PSSession is created it will not have $Node populated anymore
                Invoke-Command -Session $NewSession -ScriptBlock {
                    Test-Path -Path Variable:\Node
                } | Should Be $False
            }

            It "Should populate the `$PSRemoltey variable after reconnecting to the Remote node" {
                Invoke-Command -Session $NewSession -ScriptBlock {
                    Test-Path -Path Variable:\PSRemotely
                } | Should Be $True
            }

            It "Should inject the new Invoke-PSRemotely function into the remote PSSession for debugging purpose" {
                $OldFunctionInfo.Parameters.ContainsKey('Node') | Should Be $True
                $NewFunctionInfo.Parameters.ContainsKey('Node') | Should Be $False
            }
             
        }
    }

}
Finally {
	Clear-PSRemotelyNodePath
    Remove-User -UserName PSRemotely
    Clear-RemoteSession
	Enable-LocalAccountTokenFilterPolicy
	Get-PSSession | Remove-PSSession
}