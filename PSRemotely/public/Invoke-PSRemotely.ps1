Function Invoke-PSRemotely {
<#
    .SYNOPSIS
        Invoke PSRemotely

    .DESCRIPTION
        Invoke PSRemotely

        Searches for .PSRemotely.ps1 files in the current and nested paths, and invokes the remote ops validation.
        By default PSRemotely would run all the 

    .PARAMETER Script
        Path to a specific .PSRemotely.ps1 file, or to a folder that is recursively search for *.PSRemotely.ps1 files
        You can also use the Script parameter to pass parameter names and values to a script that contains
        PSRemotely + Pester tests. The value of the Script parameter can be a string, a hash table, or a collection 
        of hash tables and strings. Wildcard characters are supported.

        The Script parameter is optional. If you omit it, Invoke-PSRemotely runs all 
        *.PSRemotely.ps1 files in the local directory and its subdirectories recursively. 
            
        To run tests in other files, such as .ps1 files, enter the path and file name of
        the file. (The file name is required. Name patterns that end in "*.ps1" run only
        *.PSRemotely.ps1 files.) 

        To run a PSRemotely file with parameter names and/or values, use a hash table as the 
        value of the script parameter. The keys in the hash table are:

        -- Path [string] (required): Specifies a test to run. The value is a path\file 
        name or name pattern. Wildcards are permitted. All hash tables in a Script 
        parameter value must have a Path key. 
            
        -- Parameters [hashtable]: Runs the script with the specified parameters. The 
        value is a nested hash table with parameter name and value pairs, such as 
        @{UserName = 'User01'; Id = '28'}. 
            
        -- Arguments [array]: An array or comma-separated list of parameter values 
        without names, such as 'User01', 28. Use this key to pass values to positional 
        parameters.
	
        Defaults to the current path.

    .PARAMETER JSONInput
        JSON String input which contains the nodename and testnames to run.
         Below is a sample JSON string, for invoking tests named TestDNSConnectivity & TestADConnectivity 
         on node BLRompute1 :-
         {
            "NodeName":  "BLRompute1",
            "Tests":  [
                            {
                                "Name":  "TestDNSConnectivity"
                            },
                            {
                                "Name" : "TestADConnectivity"
                            }
            ]
        }

    .PARAMETER PesterSplatHash
        Pass a hash table which is splatted to Invoke-Pester's execution on the PSRemotely node.
        This let's you pass arguments to Invoke-Pester such as -Tag, -ExcludeTag, -Strict etc.
        Note - PSRemotely automatically supplies the below arguments to Invoke-Pester. So if these are
        specified then it will be ignored.

        Script = <Based on the input this gets passed to Pester>
        PassThru = $True;
        Quiet = $True;
        OutputFormat = 'NunitXML';
        OutputFile = <NodeName>.xml;
         

    .EXAMPLE
        PS> Invoke-PSRemotely

        # Run remote ops validation from any file named *.PSRemotely.ps1 found under the current folder or any nested folders.
        # Prompts to confirm

    .EXAMPLE
        PS> Invoke-PSRemotely -Script C:\InfraTests\ComputeTests.PSRemotely.ps1

        # Run remote ops validation from mymodule.PSRemotely.ps1.
        # Don't prompt to confirm.

    .EXAMPLE
        PS> Invoke-PSRemotely -Script @{
                Path='C:\InfraTests\ComputeTests.PSRemotely.ps1';
                Parameters = @{Credential=$(Get-Credential)};
                Arguments = @(.\EnvironmentData.json)
            }

        # Run remote ops validation from file ComputeTests.PSRemotely.ps1.
        # This command runs C:\InfraTests\ComputeTests.PSRemotely.ps1 file. The PSRemotely file is expecting the path to
        # configuration data file (.json or .psd1) and Credential to be used to open PSSession to the nodes.
        # It  runs the tests in the ComputeTests.PSRemotely.ps1 file using the following parameters: 

        C:\InfraTests\ComputeTests.PSRemotely.ps1 .\EnvironmentData.json -Credential <CredentialObject> 
    
    .EXAMPLE
        If suppose you ran tests on a remote node like below :- 
        PS> Invoke-PSRemotely -Script C:\InfraTests\ComputeTests.PSRemotely.ps1

        And one of the tests named 'TestDNSConnectivity' (Describe Pester block) on the remote node failed. You fixed the issue and 
        want to just run the failed test, you could do something like below :

        PS> $TestsTobeRunObejct = [pscustomobject]@{NodeName='ComputeNode1';Tests=@(@{Name='TestDNSConnectivity'})}
        PS> Invoke-PSRemotely -JSONInput $($TestsTobeRunObejct | ConvertTo-Json) 

    .LINK
        PSRemotely

    .LINK
        https://github.com/DexterPOSH/PSRemotely

#>
    [CmdletBinding(DefaultParameterSetName='BootStrap',SupportsShouldProcess=$True)]
    param(
        [Parameter(Position=0,
                    Mandatory=$False,
                    ParameterSetName='BootStrap',
                    ValueFromPipeline=$true)]
        [Object[]]$Script='.',
        
        [Parameter(Position=0,
                    Mandatory=$true,
                    ParameterSetName='JSON')]
        [String]$JSONInput,

        [Parameter(Position=1,
                    Mandatory=$False)]
        [Alias('SplatHash')]
        [HashTable]$PesterSplatHash

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
                
                If (-not $Object.NodeName ) {
                    Throw "JSON Input must specify the NodeName property."
                }
                # Check if the node is already bootstrapped and session info maintained in the PSRemotely variable
                if (TestRemotelyNodeBootStrapped -ComputerName $Object.NodeName) {
                    # Node is bootstrapped, get the corresponding session object
                    $session = $PSRemotely['sessionHashTable'].GetEnumerator() | 
                                Where-Object -Property Name -like "*$($Object.NodeName)*" |
                                Select-Object -ExpandProperty Value | 
                                Select-Object -ExpandProperty Session
                    
                    # Check if the Pester splat hash was passed
                    if ($PesterSplatHash) {
                        Sanitize-PesterSplatHash -SplatHash $PesterSplatHash
                    }
                    # build the splat hashtable
                   $invokeTestParams = @{
                        Session = $session;
                        ArgumentList = $JSONInput, $Object.NodeName, $PesterSplatHash #@(,$Object.Tests.Name);
                        ScriptBlock = {
                            param(
                                [String]$JSONString,
                                [String]$NodeName,
                                [HashTable]$PesterSplatHash
                                )
                            $Object = ConvertFrom-Json -InputObject $JSONString
                            foreach ($test in @($Object.Tests.Name)) {
                                Write-Verbose -Message "Processing $test" -Verbose
                                if ($NodeName) {
                                    $testFileName = "{0}.{1}.Tests.ps1" -f $NodeName, $test.replace(' ','_')
                                    # Check that the filename does not contain invalid file characters e.g ::1 is the nodename in case of link local ipv6 address
                                    $IndexOfInvalidChar = $testFileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
                                    # IndexOfAny() returns the value -1 to indicate no such character was found
                                    if($IndexOfInvalidChar -ne -1){
                                        # if there is an invalid character in the filename, fall back to using the computername
                                        Write-Warning -Message "Invalid character found in the file name > $($testFileName). Switching to using env:computername for filename"
                                        $testFileName = "{0}.{1}.Tests.ps1" -f $Env:COMPUTERNAME, $test.replace(' ','_')
                                    }
                                }
                                else {
                                    $testFileName = "{0}.{1}.Tests.ps1" -f $env:COMPUTERNAME, $test.replace(' ','_')
                                }
                                
                                $testFile = "$($Global:PSRemotely.PSRemotelyNodePath)\$testFileName"
                                $outPutFile = "{0}\{1}.{2}.xml" -f 	 $PSRemotely.PSRemotelyNodePath, $nodeName, $test
                                $invokePesterParams = @{
                                    PassThru = $True;
                                    Quiet = $True;
                                    OutputFormat = 'NunitXML';
                                    OutputFile = $OutputFile
                                }

                                if ($PesterSplatHash) {
                                    $invokePesterParams += $PesterSplatHash
                                }
                                
                                if ($Node) {
                                    Invoke-Pester -Script @{Path=$($TestFile); Parameters=@{Node=$Node}} @invokePesterParams
                                }
                                else {
                                    Invoke-Pester -Script $testFile @invokePesterParams
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
                # Credits to Pester's Invoke-Pester for the below logic
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
                            Write-VerboseLog -Message "Invoking test script -> $($testscript.path)"
                            # TODO pass the PesterSplatHash if specified in the command line
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
            $results = @(ProcessRemotelyJob -InputObject $([System.Collections.DictionaryEntry]::New($Object.NodeName,$TestJob)))
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
                $IsPSRemotelyInName = [System.IO.Path]::GetFileNameWithoutExtension($unresolvedPath)
                $IsNameEndingwithPSRemotely = $IsPSRemotelyInName.EndsWith('PSRemotely',$true,[System.Globalization.CultureInfo]::InvariantCulture)
                if (($extension -ne '.ps1') -or ( -not $IsNameEndingwithPSRemotely)){
                    Write-Error "Script path '$unresolvedPath' is not a *.PSRemotely.ps1 file."
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
                    Get-ChildItem -Include *.PSRemotely.ps1 -Recurse |
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