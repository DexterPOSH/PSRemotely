
Function Invoke-Remotely {
    [CmdletBinding(DefaultParameterSetName='JSON')]
    param(
        <#
         JSON String input which contains the nodename and testnames to run.
         Below is a sample JSON string, for invoking tests named TestDNSConnectivity & TestADConnectivity on node DellBlr2C2A 
         {
            "NodeName":  "DellBlr2C2A",
            "Tests":  [
                            {
                                "Name":  "TestDNSConnectivity"
                            },
                            {
                                "Name" : "TestADConnectivity"
                            }
            ]
        }
         #>

        [Parameter(Mandatory, ParameterSetName='JSON')]
        [String]$JSONInput,

        # Path to the Remotely script file. First step.
        [Parameter(Mandatory,ParameterSetName='BootStrap')]
        [String]$Script

    )
    BEGIN {
        
        # verbose logging goes here
    }
    PROCESS {
        Switch -Exact ($PSCmdlet.ParameterSetName) {

            'JSON' {
                # provided the JSON input, run the required tests on the remotely node
                
                # construct the object from the input
                $Object = ConvertFrom-Json -InputObject $JSONInput
                
                # Check if the node is already bootstrapped and session info maintained in the Remotely variable
                if (TestRemotelyNodeBootStrapped -ComputerName $Object.NodeName) {
                    # Node is bootstrapped, get the corresponding session object
                    $session = $Remotely['sessionHashTable'].GetEnumerator() | 
                                where -Property Name -eq $Object.NodeName |
                                select -ExpandProperty Value | 
                                select -ExpandProperty Session
                    
                    # build the splat hashtable
                    $invokeTestParams = @{
                        Session = $session;
                        ArgumentList = $($Object.Tests.Name), $Object.NodeName;
                        ScriptBlock = {
                            param(
                                [String[]]$testName,
                                [String]$nodeName
                                )

                            foreach ($test in $testName) {
                                $testFileName = "{0}.{1}.Tests.ps1" -f $nodeName, $testName.replace(' ','_')
                                $testFile = "$($Global:Remotely.remotelyNodePath)\$testFileName"
                                $outPutFile = "{0}\{1}.{2}.xml" -f 	 $Remotely.remotelyNodePath, $nodeName, $testName
                                if ($Node) {
                                    Invoke-Pester -Script @{Path=$($TestFile); Parameters=@{Node=$Node}} -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $outPutFile
                                }
                                else {
                                    Invoke-Pester -Script $testFile  -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $outPutFile
                                }
                            }
                        }; # end scriptBlock
                    }

                    # invoke the tests
                    $testJob = Invoke-Command @invokeTestParams -AsJob

                }
                else {
                    # Node is not bootstrapped. Throw an error
                    throw "$($object.NodeName) is not bootstrapped"
                }
                break
            }
            'BootStrap' {
                # Path to a Script housing Remotely tests, it should run the script as it script
                & $Script
            }
        }
    }
    END {
        $null = $testjob | Wait-Job
		$results = @(ProcessRemotelyJobs -InputObject $TestJob)
        $testjob | Remove-Job -Force
	    ProcessRemotelyOutputToJSON -InputObject $results
    }
}