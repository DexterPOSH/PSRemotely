if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}

$PSVersion = $PSVersionTable.PSVersion.Major

$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force  -ErrorAction SilentlyContinue # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}

Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

try {
    Describe "PSRemotely only accepts *.PSRemotely.ps1 extension files" {
        # PSRemotely Test file to be used for this Integration test.
        $RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.basic.ps1"
        $null = Invoke-PSRemotely -Script $RemotelyTestFile -ErrorVariable PSRemotelyError 2>&1

        It 'Should throw an error' {
            $PSRemotelyError | Should Not BeNullOrEmpty
        }

        It 'Should throw a custom error message' {
            ($PSRemotelyError -like '* is not a *.PSRemotely.ps1 file.') | Should NOT BeNullOrEmpty 
        }
    }

    Describe "PSRemotely - Fix parsing Describe blocks" {
        # Issue - https://github.com/DexterPOSH/PSRemotely/issues/27

        Context "Ops validation tests using possible usage combinations with Describe keyword" {
            $RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.basic.name.tag.PSRemotely.ps1"
            $null = Invoke-PSRemotely -Script $RemotelyTestFile -ErrorVariable PSRemotelyError 2>&1 

            It 'Should NOT throw an error' {
                $PSRemotelyError | Should BeNullOrEmpty
            }
            
            (1..7).foreach({
                It "Should have placed a localhost.Test$($PSItem).Tests.ps1 file in the PSRemotelyNodePath" {
                    $TestFileName = "localhost.Test{0}.Tests.ps1" -f $PSItem
                    $Global:PSRemotely.PSRemotelyNodePath\$TestFileName | Should Exist
                }  
            })
        }
    }

}
catch {
    Clear-PSRemotelyNodePath
    Clear-RemoteSession
}
