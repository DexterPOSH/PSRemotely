Synopsis
============
Executes a script block against a remote runspace. Remotely can be used with Pester for executing script blocks on a remote system.

Description
======================
The contents on the Remotely block are executed on a remote runspace. The connection information of the runspace is supplied using the -Nodes parameter or as the argument to the first positional parameter. By default, this assumes the local credentials have access to the remote session configuration on the target nodes. In case the credentials are different, you can use -CredentialHash to provide the node specific credentials.

To get access to the streams, use GetVerbose, GetDebugOutput, GetError, GetProgressOutput,
GetWarning on the resultant object.

Example
============
Usage in Pester:

```powershell
$CredHash = @{
	'VM1' = (Get-Credential)
}

Describe "Add-Numbers" {
    It "adds positive numbers on two remote systems" {
        Remotely 'VM1','VM2' { 2 + 3 } | Should Be 5
    }

    It "gets verbose message" {
        $sum = Remotely 'VM1','VM2' { Write-Verbose -Verbose "Test Message" }
        $sum.GetVerbose() | Should Be "Test Message"
    }

    It "can pass parameters to remote block with different credentials" {
        $num = 10
        $process = Remotely 'VM1' { param($number) $number + 1 } -ArgumentList $num -CredentialHash $CredHash
        $process | Should Be 11
    }
}
```

Links
============
* https://github.com/PowerShell/Remotely
* https://github.com/pester/Pester

Running Tests
=============
Pester-based tests are located in ```<branch>/Remotely.Tests.ps1```

* Ensure Pester is installed on the machine
* Run tests:
    .\Remotely.Tests.ps1
