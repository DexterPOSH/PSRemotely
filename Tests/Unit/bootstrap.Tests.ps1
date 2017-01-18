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
		ModuleVersion='3.3.5';
    },
	@{
		ModuleName='PoshSpec';
		ModuleVersion='1.1.10';
	})
    Get-Service -Name WinRM | Restart-Service
    $Session = New-PSSession -ComputerName Localhost -EnableNetworkAccess
    
Describe "BootStrapRemotelyNode $PSVersion" -Tags UnitTest {
        
    Context 'If the required modules are present on the Remotely node and PSRemotely Path already present' {
        # Arrange
        Mock -CommandName TestRemotelyNode -MockWith {@{'Pester'=$true;'PoshSpec'=$true}; $true}
        Mock -CommandName UpdateRemotelyNodeMap -MockWith {} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {}
        Mock -CommandName CleanupPSRemotelyNodePath -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired -PSRemotelyNodePath 'C:\temp'
        
        # Assert 
        
        It "Should test if the Remotely Node for the modules and PSRemotely path" {
            Assert-MockCalled -CommandName TestRemotelyNode -Times 1 -Exactly  -Scope Context
        }

        It 'Should update the status of the Remotely Node in the beginning' {
            Assert-MockCalled -CommandName UpdateRemotelyNodeMap -Times 1 -Exactly  -Scope Context
        }
        
        It "Should archive the existing tests files on the PSRemotely path on the node" {
            Assert-MockCalled -CommandName CleanupPSRemotelyNodePath -Times 1 -Exactly -Scope Context
        }

        It 'Should not try to copy the modules, as already present on the Remote node' {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times 0 -Exactly -Scope Context
        }
    }
    
    Context 'If one of the required modules is NOT present on the Remotely node and PSRemotely path is present' {
        # Arrange
        Mock -CommandName TestRemotelyNode -MockWith {@{'Pester'=$true;'PoshSpec'=$false}; $true}
        Mock -CommandName UpdateRemotelyNodeMap -MockWith {} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {} #-ParameterFilter {$FullyQualifiedName.ModuleName -eq 'PoshSpec'}
        Mock -CommandName CleanupPSRemotelyNodePath -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired -PSRemotelyNodePath 'C:\temp'
        
        # Assert 
        
        It "Should test the Remotely Node for the modules and PSRemotely path at beginning and end" {
            Assert-MockCalled -CommandName TestRemotelyNode -Times 2 -Exactly -Scope Context 
        }
        
        It "Should only copy the missing module" {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times 1 -Exactly -Scope Context
        }

        It "Should archive the existing tests files on the PSRemotely path on the node" {
            Assert-MockCalled -CommandName CleanupPSRemotelyNodePath -Times 1 -Exactly -Scope Context

        }

        It 'Should update the PSRemotely variable at the beginning and end of the bootstrap function' {
            Assert-MockCalled -CommandName UpdateRemotelyNodeMap -Times 2 -Exactly -Scope Context
        }

    }

    Context 'If all the required modules NOT present on the Remotely node, and PSRemotely path is present' {
        # Arrange
        Mock -CommandName TestRemotelyNode -MockWith {@{'Pester'=$false;'PoshSpec'=$false}; $true}
        Mock -CommandName UpdateRemotelyNodeMap -MockWith {} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {} #-ParameterFilter {$FullyQualifiedName.ModuleName -eq 'PoshSpec'}
        Mock -CommandName CleanupPSRemotelyNodePath -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired -PSRemotelyNodePath 'C:\temp'
        
        
        It "Should test the Remotely Node for the modules and PSRemotely path at beginning and end" {
            Assert-MockCalled -CommandName TestRemotelyNode -Times 2 -Exactly -Scope Context 
        }
        
        It "Should copy all the missing module" {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times $ModuleRequired.Count -Exactly -Scope Context
        }

        It "Should archive the existing tests files on the PSRemotely path on the node" {
            Assert-MockCalled -CommandName CleanupPSRemotelyNodePath -Times 1 -Exactly -Scope Context
        }

        It 'Should update the PSRemotely variable at the beginning and end of the bootstrap function' {
            Assert-MockCalled -CommandName UpdateRemotelyNodeMap -Times 2 -Exactly -Scope Context
        }
    }       

    Context 'If all the required modules  present on the Remotely node, and PSRemotely path is NOT present' {
        # Arrange
        Mock -CommandName TestRemotelyNode -MockWith {@{'Pester'=$true;'PoshSpec'=$true}; $false}
        Mock -CommandName UpdateRemotelyNodeMap -MockWith {} 
        Mock -CommandName CopyRemotelyNodeModule -MockWith {} #-ParameterFilter {$FullyQualifiedName.ModuleName -eq 'PoshSpec'}
        Mock -CommandName CleanupPSRemotelyNodePath -MockWith {}
        Mock -CommandName CreatePSRemotelyNodePath -MockWith {}
        
        # Act
        BootStrapRemotelyNode -Session $Session -FullyQualifiedName $ModuleRequired -PSRemotelyNodePath 'C:\temp'
        
        
        It "Should test the Remotely Node for the modules and PSRemotely path at beginning and end" {
            Assert-MockCalled -CommandName TestRemotelyNode -Times 2 -Exactly -Scope Context 
        }

        It 'Should create the PSRemotelyNodePath on the remote node' {
            Assert-MockCalled -CommandName CreatePSRemotelyNodePath -Times 1 -Exactly -Scope Context
        }
        
        It "Should NOT copy modules , already present" {
            Assert-MockCalled -CommandName CopyRemotelyNodeModule -Times 0 -Exactly -Scope Context
        }

        It "Should NOT archive the existing tests files on the PSRemotely path on the node, since the folder is not present" {
            Assert-MockCalled -CommandName CleanupPSRemotelyNodePath -Times 0 -Exactly -Scope Context
        }

        It 'Should update the PSRemotely variable at the beginning and end of the bootstrap function' {
            Assert-MockCalled -CommandName UpdateRemotelyNodeMap -Times 2 -Exactly -Scope Context
        }
    }       

}

Describe "TestRemotelyNode $PSVersion" -Tags  UnitTest {
    
    Context 'check if the required arguments are passed to the Invoke-Command' {
        # Arrange
        Mock -CommandName Invoke-Command -MockWith {} 
        
        # Act
        $Output = TestRemotelyNode -Session $session -FullyQualifiedName $ModuleRequired -PSRemotelyNodePath 'C:\temp'
        
        # Assert
        It 'Should call Invoke-Command to fetch if the module is installed' {
            Assert-MockCalled -CommandName Invoke-Command -ParameterFilter { 
                ($ArgumentList -contains 'C:\temp') -and
                ($ArgumentList.Count -eq 2) -and
                ($Session -ne $null)
            } -Times 1 -Exactly 
        }

    }
}

Describe "CreatePSRemotelyNodePath $PSVersion" -Tags UnitTest {

	Context "Check if the correct path argument gets passed to the Invoke-Command" {
		# Arrange
		Mock -CommandName Invoke-Command -ParameterFilter { 
            $ScriptBlock.ToString().Trim().Equals('$null = New-Item -Path "$using:Path\lib\Artifacts" -ItemType Directory -Force') -and
            ($null -ne $Session)
        }

		# Act
		CreatePSRemotelyNodePath -Session $session -path 'C:\temp'

		# Assert
		It 'Should call Invoke-Command to create the path on RemotelyNode' {
			Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope Context
		}

	}
}

Describe "CopyRemotelyNodeModule $PSversion" -Tag UnitTest {
    	
    Context 'Required module defined is not present in the PSRemotely lib folder' {
        # Arrange
        Mock -CommandName TestModulePresentInLib -MockWith {$false}
        # Act        
        # Assert
        It 'Should throw a customized error, saying module not present in lib folder' {
            {CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0] } |
                Should Throw "Lib folder does not have a folder named $($ModuleRequired[0].ModuleName)\$($ModuleRequired[0].ModuleVersion), so it can't be copied to the PSRemotely node."

            Assert-MockCalled -CommandName TestModulePresentInLib -Times 1 -Exactly -Scope Context
        }
    }

    Context 'Required modules present locally, it should copy them to the Remotely node' {
        # Arrange
        Mock -CommandName TestModulePresentInLib -MockWith {$True}
        Mock -CommandName CopyModuleFolderToRemotelyNode -ParameterFilter {
            ($null -ne $Path) -and 
            ($null -ne $Destination) -and
            ($null -ne $Session)
        }

        # Act
        CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0] 
        # Assert
        It 'Should first test if the module is present in the local lib folder' {
            Assert-MockCalled -CommandName TestModulePresentInLib -TImes 1 -Exactly -Scope Context
        }

        It 'Should copy the module to the Remotely node' {
            Assert-MockCalled -CommandName CopyModuleFolderToRemotelyNode -Times 1 -Exactly -Scope Context
        }
    }

    Context 'While copying the modules to Remotely node, an error is thrown' {
        # Arrange
        Mock -CommandName TestModulePresentInLib -MockWith {$True}
        Mock -CommandName CopyModuleFolderToRemotelyNode -MockWith {throw 'Copy failed'}
        
        # Act and Assert 
        It 'Should throw the underlying error back' {
            {CopyRemotelyNodeModule -Session $Session -FullyQualifiedName $ModuleRequired[0]} |
                Should Throw 'Copy failed'
        }
    }
}


Describe "CopyModuleFolderToRemotelyNode $PSVersion" -Tag UnitTest {
    
    Context 'Creates and copies the required module folders recursively to the Remotely node' {
        # Arrange
		Mock -CommandName Invoke-Command -ParameterFilter { $ScriptBlock.ToString().Equals('$null = New-Item -Path $Using:Destination -ItemType Directory')}
        Mock -CommandName Copy-Item -MockWith {$null}
		# Act
		CopyModuleFolderToRemotelyNode -Session $session -path 'C:\temp' -Destination 'C:\'

		# Assert
		It 'Should call Invoke-Command to create the Destination directory for the module on Remotely Node' {
			Assert-MockCalled -CommandName Invoke-Command -Times 1 -Exactly -Scope Context
		}

        It 'Should copy the required folder and its content over PSRemoting Session' {
            Assert-MockCalled -CommandName Copy-Item -Times 1 -Exactly -Scope Context
        }   
    }
}

}     