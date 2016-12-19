
Function Invoke-PSRemotely {
    [CmdletBinding(DefaultParameterSetName='BootStrap')]
    param(

        # Path to the PSRemotely script file. First step.
        [Parameter(Mandatory,ParameterSetName='BootStrap',ValueFromPipeline=$true)]
        [Object[]]$Script,
        
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
        [String]$JSONInput

        

    )
    BEGIN {
        
        # verbose logging goes here
    }
    PROCESS {
        Switch -Exact ($PSCmdlet.ParameterSetName) {

            'JSON' {
                # provided the JSON input, run the required tests on the PSRemotely node
                Write-VerboseLog -Message 'ParameterSet - JSON'
                # construct the object from the input
                $Object = ConvertFrom-Json -InputObject $JSONInput
                
                # Check if the node is already bootstrapped and session info maintained in the PSRemotely variable
                if (TestRemotelyNodeBootStrapped -ComputerName $Object.NodeName) {
                    # Node is bootstrapped, get the corresponding session object
                    $session = $PSRemotely['sessionHashTable'].GetEnumerator() | 
                                where -Property Name -like "*$($Object.NodeName)*" |
                                select -ExpandProperty Value | 
                                select -ExpandProperty Session
                    
                    # build the splat hashtable
                   $invokeTestParams = @{
                        Session = $session;
                        ArgumentList = $JSONInput #@(,$Object.Tests.Name);
                        ScriptBlock = {
                            param(
                                [String]$JSONString
                                )
                            $Object = ConvertFrom-Json -InputObject $JSONString
                            foreach ($test in @($Object.Tests.Name)) {
                                Write-Verbose -Message "Processing $test" -Verbose
                                $testFileName = "{0}.{1}.Tests.ps1" -f $env:ComputerName, $test.replace(' ','_')
                                $testFile = "$($Global:PSRemotely.PSRemotelyNodePath)\$testFileName"
                                $outPutFile = "{0}\{1}.{2}.xml" -f 	 $PSRemotely.PSRemotelyNodePath, $nodeName, $testName
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
                # Path to a Script housing PSRemotely tests, it should run the script as it script
                Write-VerboseLog -Message 'ParameterSet - BootStrap'
                $invokeTestScript = {
                    param (
                        [Parameter(Position = 0)]
                        [string] $Path,

                        [object[]] $Arguments = @(),
                        [System.Collections.IDictionary] $Parameters = @{}
                    )

                    & $Path @Parameters @Arguments
                }
                
                $testScripts = ResolveTestScripts $Script

                foreach ($testScript in $testScripts){
                    try {
                        do{
                            & $invokeTestScript -Path $testScript.Path -Arguments $testScript.Arguments -Parameters $testScript.Parameters
                        } until ($true)
                    }
                    catch{
                        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | Select-Object -First 1
                        Write-VerboseLog -Message "Error occurred in test script '$($testScript.Path) -> $firstStackTraceLine"
                        
                    }
                }
            }
        }
    }
    END {
        if ($PSCmdlet.ParameterSetName -eq 'JSON') {
            $null = $testjob | Wait-Job
            $results = @(ProcessRemotelyJob -InputObject $TestJob)
            $testjob | Remove-Job -Force
            ProcessRemotelyOutputToJSON -InputObject $results
        }
        
    }
}



function ResolveTestScripts
{
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path)
        {
            if ($object -is [System.Collections.IDictionary])
            {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $arguments      = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters     = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S')
                {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary])
                {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else
            {
                $unresolvedPath = [string] $object
                $arguments      = @()
                $parameters     = @{}
            }

            if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                (Test-Path -LiteralPath $unresolvedPath -PathType Leaf) -and
                (Get-Item -LiteralPath $unresolvedPath) -is [System.IO.FileInfo]){
                
                $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                if ($extension -ne '.ps1'){
                    Write-Error "Script path '$unresolvedPath' is not a ps1 file."
                }
                else
                {
                    New-Object -TypeName psobject -Property @{
                        Path       = $unresolvedPath
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
            else
            {
                # World's longest pipeline?

                Resolve-Path -Path $unresolvedPath |
                    Where-Object { $_.Provider.Name -eq 'FileSystem' } |
                    Select-Object  -ExpandProperty ProviderPath |
                    Get-ChildItem -Include *.Tests.ps1 -Recurse |
                    Where-Object { -not $_.PSIsContainer } |
                    Select-Object -ExpandProperty FullName -Unique |
                    ForEach-Object {
                        New-Object  psobject -Property @{
                            Path       = $_
                            Arguments  = $arguments
                            Parameters = $parameters
                        }
                    }
            }
        }
    )

    # Here, we have the option of trying to weed out duplicate file paths that also contain identical
    # Parameters / Arguments.  However, we already make sure that each object in $Path didn't produce
    # any duplicate file paths, and if the caller happens to pass in a set of parameters that produce
    # dupes, maybe that's not our problem.  For now, just return what we found.

    $resolvedScriptInfo
}


function Get-DictionaryValueFromFirstKeyFound
{
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key)
    {
        if ($Dictionary.Contains($keyToTry)) { return $Dictionary[$keyToTry] }
    }
}