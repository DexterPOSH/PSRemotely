$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}
if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

Describe 'Node' {

	BeforeEach {
		# claen up the Remotely temp path
		Remove-Item -Path C:\temp\Remotely\* -Force -Recurse
		# clearn any lingering PSSessions
		Get-PSSession | Remove-PSSession
		# create dummy Remotely variable
	
	}

	Context 'Node is localhost' {
		# Happy path test
		# Arrange
		$jsonObject = ConvertFrom-Json -InputObject $(Get-Content -Path "$PSScriptRoot\..\Remotely\Remotely.Json" -Raw -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue
		$Global:Remotely = ConvertPSObjectToHashTable -InputObject $jsonObject
		$Global:Remotely.Add('NodeMap', @())
		$Global:Remotely.Add('sessionHashTable', @{})

		# Act 
		Node localhost { 
			Describe Service {
				Service w32time Status { Should Be Running }
			}
		} -ErrorVariable nodeError -WarningVariable nodeWarning
			
		# Assert 		
		It 'Should open a PSSession to the node' {
					
		}

		It 'Shoould bootstrap the node' {

		}

		It 'Should add the AllNodes variable to the remotely node session' {

		}

		it 'Should'
	}
}