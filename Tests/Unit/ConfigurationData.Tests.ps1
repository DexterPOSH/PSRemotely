
if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope -ModuleName $ENV:BHProjectName {
    
    Describe "Test-ConfigData" -Tag UnitTest {
        
        Context "Wrong configuration data, does not follow DSC style syntax for it" {
            
            It 'Should fail if AllNodes key not present' {
                
                $ConfigData = @{
			                NodeName='*';
			                DomainFQDN='dexter.lab';
                }

                {Test-ConfigData -ConfigurationData $ConfigData } | 
                    Should Throw 'ConfigurationData parameter need to have property AllNodes.'

            }

            It 'Should fail if AllNodes is not an array' {
                $ConfigData = @{
			                AllNodes='*';
			                DomainFQDN='dexter.lab';
                }
                {Test-ConfigData -ConfigurationData $ConfigData } | 
                    Should Throw 'ConfigurationData parameter property AllNodes needs to be a collection.'
            }

            It 'Elements of the AllNodes need to be a hashtable and has to have a property named "NodeName"' {
                $ConfigData1 = @{
			                AllNodes=@('NodeName','NodeName1')
                }

                $ConfigData2 = @{
			                AllNodes=@(
                                		@{
                                            # Node name missing here
			                                DomainFQDN='dexter.lab';
		                                },
		                                @{
			                                NodeName="$env:ComputerName";
			                                ServiceName = 'bits';
			                                Type='Compute';

		                                }
                            )
            
                }
                {Test-ConfigData -ConfigurationData $ConfigData1 } | 
                    Should Throw "all elements of AllNodes need to be hashtable and has a property 'NodeName'."

                {Test-ConfigData -ConfigurationData $ConfigData2 } | 
                    Should Throw "all elements of AllNodes need to be hashtable and has a property 'NodeName'."

            }

            It 'Should fail id duplicate NodeName in the configuration data' {
                $ConfigData = @{
			                AllNodes=@(
                                		@{
                                            NodeName = 'AD';
			                                DomainFQDN='dexter.lab';
		                                },
		                                @{
			                                NodeName="AD";
			                                ServiceName = 'bits';
			                                Type='Compute';

		                                }
                            )
            
                }

                {Test-ConfigData -ConfigurationData $ConfigData } | 
                    Should Throw "There is a duplicate NodeName 'AD' in the configurationData passed in."
            }

        }
    
        Context "DSC Style Node specific configuration data supplied" {


            It 'Should not throw any error, if AllNodes key follows the syntax' {
                $ConfigData = @{
			                AllNodes=@(
                                		@{
                                            NodeName = '*';
			                                DomainFQDN='dexter.lab';
		                                },
		                                @{
			                                NodeName="AD";
			                                ServiceName = 'bits';
			                                Type='Compute';

		                                }
                            )
            
                }
                {Test-ConfigData -ConfigurationData $configData } |
                    Should NOT Throw
            }

            It 'Should not throw any error, if AllNodes is correct and other keys specified' {
                $ConfigData = @{
			                AllNodes=@(
                                		@{
                                            NodeName = '*';
			                                DomainFQDN='dexter.lab';
		                                },
		                                @{
			                                NodeName="AD";
			                                ServiceName = 'bits';
			                                Type='Compute';

		                                }
                            )
                            RandomKey = 'NotUsedByPSRemotely'
            
                }
                {Test-ConfigData -ConfigurationData $configData } |
                    Should NOT Throw
            }
        }
            

    }
    

    Describe "Update-ConfigData" -Tag UnitTest {
        
        Context "Generating Node specific configuration data" {
            
                $ConfigData = @{
			                AllNodes=@(
                                		@{
                                            NodeName = '*';
			                                DomainFQDN='dexter.lab';
		                                },
		                                @{
			                                NodeName="AD";
			                                ServiceName = 'bits';
			                                Type='Compute';

		                                }
                            )
                            AnotherKey = 'IgnoredByPSRemotely'
            
                }

                $UpdatedConfigData = Update-ConfigData -ConfigurationData $ConfigData

                It 'Should return a hashtable' {
                    $UpdatedConfigData.GetType().FullName | Should Be 'System.Collections.Hashtable'
                }

                It 'Should not change the numner of keys in the Configuration data' {
                    $UpdatedConfigData.Count | Should Be 2
                    $UpdatedConfigData.ContainsKey('AllNodes') | Should Be $True
                    $UpdatedConfigData.ContainsKey('AnotherKey') | Should Be $True
                }

                It 'Should update the AllNodes key only, hashtable with NodeName * is removed' {
                    ($UpdatedConfigData['AllNodes'] | Where-Object -PRoperty 'NodeName' -eq '*') |
                        Should BeNullOrEmpty
                }

                It 'Should update the AllNodes key only, NodeName * properties should be added to the other NodeName hashtable' {
                    $UpdatedConfigData['AllNodes'] |
                        Foreach-Object {
                            $PSItem.DomainFQDN | Should Be 'dexter.lab'
                        }
                }

                It 'Should update the AllNodes key only, NodeName hashtable should retain their original key-value' {
                    ($UpdatedConfigData['AllNodes'] | Where-Object -Property NodeName -eq 'AD')['Type'] |
                        Should Be 'Compute'
                        
                }
        }
    }
}