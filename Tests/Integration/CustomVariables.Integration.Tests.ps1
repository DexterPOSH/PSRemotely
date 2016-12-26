if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
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
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFiles = @("$env:BHProjectPath\Tests\Integration\artifacts\Localhost.CustomVariable.PSRemotely.ps1",
                        "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.CustomVariableConfigData.PSRemotely.ps1")
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"

Foreach ($RemotelyTestFile in $RemotelyTestFiles) {

    try {

        Describe "PSRemotely $([System.IO.Path]::GetFileName($RemotelyTestFile)) usage, with PS V$($PSVersion)" -Tag Integration {
            
            # Arrange
            # use a dummy artifact with PSRemotely-
            Set-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
            Copy-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"
            # Create a argument hashtable 
            $ArgumentList = @{ServiceName='Bits';Environment='Dev'}

            # Act, Invoke PSRemotely
            $Result = Invoke-PSRemotely -Script @{
                Path=$RemotelyTestFile;
                Parameters=@{Arguments=$ArgumentList}
            }
            $RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)
            
            # Assert
            Context "Validate that PSSession was created for the PSRemotely node" {

                $Session = Get-PSSession -Name PSRemotely-Localhost -ErrorAction SilentlyContinue

                It 'Should have opened a PSSession to the Node' {
                    $Session | Should NOT BeNullOrEmpty	
                }

                It 'Should be in Opened state (live sessions maintained)' {
                    $Session.State | Should Be 'Opened'
                }
            }
            
            Context "Remote variable validation" {

                It 'Should have the remote variable created in the PSSession' {
                    Foreach ($VariableName in ($ArgumentList.Keys)) {
                        $variableValue = Invoke-Command -Session $Global:PSRemotely.SessionHashTable['localhost'].Session -ScriptBlock {
                            (Get-Variable -Name $using:VariableName).Value
                        }
                        $variableValue | Should Not BeNullOrEmpty
                        $variableValue | Should Be $($ArgumentList[$VariableName])
                    }
                }
            }
        }
    } # end try block
    finally {
        Clear-PSRemotelyNodePath
        #Clear-RemoteSession
        Reset-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
        Remove-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"
    } # end finally block
}