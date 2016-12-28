if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}

$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.basic.tests.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Import-Module -Name $PSItem -verbose -Force
	}

Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

Describe "PSRemotely only accepts *.PSRemotely.ps1 extension files" {

    It 'Should throw an error' {
        {Invoke-PSRemotely -Script $RemotelyTestFile} | Should Throw
    }
}
