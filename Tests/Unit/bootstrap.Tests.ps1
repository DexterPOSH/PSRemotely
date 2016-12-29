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


InModuleScope -ModuleName $ENV:BHProjectName {
    # Module Preamble - put initialization code here
    $ModuleRequired = @( # Array of the hashtables for FullyQualifedNames for modules
    @{
        ModuleName='Pester';
		RequiredVersion='3.3.5';
    },
	@{
		ModuleName='Pester';
		ModuleVersion='3.3.5';
	})
    Get-Service -Name WinRM | Restart-Service
    $Session = New-PSSession -ComputerName Localhost
    
Describe "BootStrapRemotelyNode $PSVersion" -Tags UnitTest {
        
    Context 'If the required module is present on the Remotely node' {
        # Arrange
        Mock -CommandName TestRemotelyNodeModule -MockWith {$True} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired 
        
        # Assert 
        
        It "Should call TestRemotelyNodeModule $($ModuleRequired.Count) times" {
            Assert-MockCalled -CommandName TestRemotelyNodeModule -Times $($ModuleRequired.Count) -Exactly  -Scope Context
        }
        
        It "Should NOT call CopyRemotelyNodeModule" {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times 0 -Exactly -Scope Context
        }
    }
    
    Context 'If the required module NOT present on the Remotely node, and it is bootstrapped (copied)' {
        # Arrange
        Mock -CommandName TestRemotelyNodeModule -MockWith {$False} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired 
        
        # Assert 
        
        It "Should call TestRemotelyNodeModule $($ModuleRequired.Count) times" {
            Assert-MockCalled -CommandName TestRemotelyNodeModule -Times $($ModuleRequired.Count) -Exactly -Scope Context 
        }
        
        It "Should call CopyRemotelyNodeModule $($ModuleRequired.Count) times" {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times $($ModuleRequired.Count) -Exactly -Scope Context
        }
    }

    Context 'If the required module NOT present on the Remotely node, and the bootstrapping (copy) fails' {
        # Arrange
        Mock -CommandName TestRemotelyNodeModule -MockWith {$False} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {throw 'Copy Failed'}
        
        # Act
		$Output =   TRY {
						 BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired  -ErrorVariable bootError
					}
					CATCH {
						$Psitem.Exception.Message	
					}
		# Assert 

        It "Should call TestRemotelyNodeModule 1 time" {
            Assert-MockCalled -CommandName TestRemotelyNodeModule -Times 1 -Exactly -Scope Context 
        }

        It "Should call CopyRemotelyNodeModule only 1 time" { # this would throw an error so next module is not processed
           Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times 1 -Exactly -Scope Context 
        }

		It 'Should write errors for each node the warning stream' {
			$bootError | Should Not BeNullOrEmpty
			$Output | Should be 'Copy Failed'
		}
    }
      
    }       


Describe "TestRemotelyNodeModule $PSVersion" -Tags  UnitTest {
    
    Context 'If the required module NOT present on the Remotely node' {
        # Arrange
        Mock -CommandName Invoke-Command -MockWith {} -ParameterFilter { $ScriptBlock.ToString().Equals('Get-Module -ListAvailable -Name $Using:FullyQualifiedName.Name')} -Verifiable
        
        # Act
        $Output = TestRemotelyNodeModule -Session $session -FullyQualifiedName $ModuleRequired[0]
        
        # Assert
        It 'Should call Invoke-Command to fetch if the module is installed' {
            Assert-MockCalled -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Equals('Get-Module -ListAvailable -Name $Using:FullyQualifiedName.Name')} -Times 1 -Exactly 
			Assert-VerifiableMocks
        }
        
        It 'Should return False' {
            $Output | Should Be $False
        }
    }
    
    Context 'If the required module is present on the Remotely node' {
        # Arrange
        Mock -CommandName Invoke-Command -MockWith {'DummyValue'}
        
        # Act
        $Output = TestRemotelyNodeModule -Session $session -FullyQualifiedName $ModuleRequired[0]
        
        # Assert
        
        It 'Should return True' {
            $Output | Should Be $True
        }
    }  
    
}

Describe "CreateRemotelyNodePath $PSVersion" -Tags UnitTest {

	Context "If the Path exists on the Remotely Node" {
		# Arrange
		Mock -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Equals('Test-Path -Path $using:Path')} -MockWith {$True} -Verifiable
		Mock -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Contains('New-Item')}  -MockWith {}

		# Act
		CreateRemotelyNodePath -Session $session -path 'C:\temp'

		# Assert
		It 'Should call Invoke-Command to check if the path on RemotelyNode exists' {
			Assert-MockCalled -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Equals('Test-Path -Path $using:Path')} -Times 1 -Exactly
			Assert-VerifiableMocks
		}

		It 'Should not create the path as it already exists' {
			Assert-MockCalled -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Contains('New-Item')}  -Times 0 -Exactly
		}
	}

	Context "If the Path does NOT exist on the Remotely Node, it gets created" {
		# Arrange
		Mock -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Equals('Test-Path -Path $using:Path')} -MockWith {$false} -Verifiable
		Mock -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Contains('New-Item')} -MockWith {} -Verifiable
		
		# Act
		CreateRemotelyNodePath -Session $session -path 'C:\temp'

		# Assert
		It 'Should  create the path.' {
			Assert-MockCalled -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Contains('New-Item')} -Times 1 -Exactly
			Assert-VerifiableMocks
		}
	}
}

Describe "CopyRemotelyNodeModule $PSversion" -Tag UnitTest {
	
	Context "Required Module present locally, Copied successfully to the Remotely Node." {
		# Arrange
		Mock -CommandName Get-Module -ParameterFilter {$ListAvailable -and ($Name -eq 'Pester')} -MockWith {[pscustomobject]@{Path='C:\temp\Pester.psd1'}}
		Mock -CommandName Split-Path -ParameterFilter {$Path -eq 'C:\temp\Pester.psd1'}
		Mock -CommandName CreateRemotelyNodePath -MockWith {}
		Mock -CommandName CopyModuleFolderToRemotelyNode -MockWith {}
		# Act
		$OutPut = 	CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0]

		# Assert
		It 'Should not return anything when it succeeds' {
			$Output | Should BeNullOrEmpty
		}

		It 'Should call get-Module to verify that module is installed locally' {
			Assert-MockCalled -CommandName Get-Module -ParameterFilter {$ListAvailable -and ($Name -eq 'Pester')} -Times 1 -Exactly -Scope Context
		}

		It 'Should call Split-Path to get the parent path to the Module' {
			Assert-MockCalled -CommandName Split-Path -ParameterFilter {$Path -eq 'C:\temp\Pester.psd1'} -Times 1 -Exactly -Scope Context
		}

		It 'Should create the Folder for the module on the RemotelyNode' {
			Assert-MockCalled -CommandName CreateRemotelyNodePath -Times 1 -Exactly -Scope Context
		}

		It 'Should copy the local module folder to the remotely node' {
			Assert-MockCalled -CommandName CopyModuleFolderToRemotelyNode -Times 1 -Exactly -Scope Context
		}
	}

	Context "Required Module present locally, Copy failed to the Remotely Node." {
		# Arrange
		Mock -CommandName Get-Module -ParameterFilter {$ListAvailable -and ($Name -eq 'Pester')} -MockWith {[pscustomobject]@{Path='C:\temp\Pester.psd1'}}
		Mock -CommandName Split-Path -ParameterFilter {$Path.Equals('C:\temp\Pester.psd1')}
		Mock -CommandName CreateRemotelyNodePath -MockWith {}
		Mock -CommandName CopyModuleFolderToRemotelyNode -MockWith {throw 'Copy Failed'}
		# Act
		$OutPut =   TRY {
						CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0] -ErrorVariable copyError -ErrorAction Stop
					}
					CATCH {

					}

		# Assert
		It 'Should not return anything when it succeeds' {
			$Output | Should BeNullOrEmpty
		}

		It 'Should try to copy the local module folder to the remotely node' {
			Assert-MockCalled -CommandName CopyModuleFolderToRemotelyNode -Times 1 -Exactly -Scope Context
		}

		It 'Should throw an exception, if copy fails' {
			$copyError | Should Not BeNullOrEmpty
			# TO DO add test for the exception message
		}
	}

	Context "Required Module present locally, creating path failed on the Remotely Node." {
		# Arrange
		Mock -CommandName Get-Module -ParameterFilter {$ListAvailable -and ($Name -eq 'Pester')} -MockWith {[pscustomobject]@{Path='C:\temp\Pester.psd1'}}
		Mock -CommandName Split-Path -ParameterFilter {$Path.Equals('C:\temp\Pester.psd1')}
		Mock -CommandName CreateRemotelyNodePath -MockWith {throw 'Path creation failed'}
		Mock -CommandName CopyModuleFolderToRemotelyNode -MockWith {throw 'Copy Failed'}
		# Act
		$Output =   TRY {
						CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0] -ErrorVariable copyError -ErrorAction Stop
					}
					CATCH {
						$PSItem.Exception.Message
					}

		# Assert
		
		It 'Should try to create the module path on the remotely node' {
			Assert-MockCalled -CommandName CreateRemotelyNodePath -Times 1 -Exactly -Scope Context
		}

		It 'Should never reach the step to  copy the local module folder to the remotely node' {
			Assert-MockCalled -CommandName CopyModuleFolderToRemotelyNode -Times 0 -Exactly -Scope Context
		}

		It 'Should throw an exception, if path creation fails' {
			$copyError | Should Not BeNullOrEmpty
			$Output | Should be 'Path Creation Failed'
		}
	}

	Context "Required Module is not present locally, install it from PSGallery locally and then copy to remotely node" {
		# Arrange
		$Script:GetModuleCounter = 1
		Mock -CommandName Get-Module -MockWith {
			if ($Script:GetModuleCounter -eq 1) {
				$Script:GetModuleCounter++ 
				$null # return nothing first time
			}
			else{
				[pscustomobject]@{Path='C:\temp\Pester.psd1'}
			}
		} 
		Mock -CommandName Write-Warning -MockWith {}
		Mock -Commandname Import-Module -MockWith {} -ParameterFilter {$Name -eq 'PackageManagement'}
		Function Install-Module {param($name,$RequiredVersion)} # dummy install-module 
		Mock -CommandName Install-Module -ParameterFilter {$name -eq 'pester' -and $RequiredVersion -eq '3.3.5'} -MockWith {}
		Mock -CommandName Split-Path -ParameterFilter {}
		Mock -CommandName CreateRemotelyNodePath -MockWith {}
		Mock -CommandName CopyModuleFolderToRemotelyNode -MockWith {}

		# Act
		$Output =  CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0]

		# Assert
		It 'Should not find the module at first and throw a warning ' {
			Assert-MockCalled -CommandName Write-Warning -Scope Context -times 1 -Exactly
		}
		
		It 'Should call the Get-Module 2 times' {
			$Script:GetModuleCounter | Should be 2
			Assert-MockCalled -CommandName Get-Module -Times 2 -Exactly -Scope Context
		}

		It 'Should then import PackageManagement module to fetch the module' {
			Assert-MockCalled -CommandName Import-Module -ParameterFilter {$Name -eq 'PackageManagement'} -Scope Context -times 1 -Exactly
		}

		It 'Should call Install-Module to install the required version of the module'  {
			Assert-MockCalled -CommandName Install-Module -ParameterFilter {$name -eq 'pester' -and $RequiredVersion -eq '3.3.5'} -Times 1 -Exactly -Scope Context
		}

	}
}

}     