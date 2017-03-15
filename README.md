[![Build status](https://ci.appveyor.com/api/projects/status/w22ytbuyjr7a10ia/branch/master?svg=true)](https://ci.appveyor.com/project/DexterPOSH/psremotely/branch/master) [![Documentation Status](https://readthedocs.org/projects/psremotely/badge/?version=latest)](https://readthedocs.org/projects/psremotely/badge/?version=latest)

PSRemotely
============

PSRemotely, started as a fork of the [Remotely project](https://github.com/PowerShell/Remotely) and over the time grew out of it.
In a nutshell it let's you execute Pester tests against a remote machine. PSRemotely can use PoshSpec style infrastucture validation tests too.

Note - In the code & documentation the term 'Remotely' and 'PSRemotely' refer to the same.

It supports copying of the modules and artifacts to the remote node before the Pester tests are run. 

Description
======================
PSRemotely exposes a DSL which makes it easy to run Pester tests on the remote nodes.
If you already have pester tests then you need to just wrap them inside the PSRemotely keyword and specify the node information using the Node keyword.

PSRemotely workflow is as under :

1. Read PSRemotely.json file to determine the path & modules to be used on the remote nodes.
2. Bootstrap the remote nodes, this involves 
    - Testing the remote node path exists.
    - All the modules required are copied from the Lib/ folder to the remote node.
3. Drop the Pester tests (Describe blocks) as individual tests file on the remote node. 
    Also copy the items defined in the PSRemotely.json, which are placed under Artifacts/ folder inside local PSRemotely folder.
4. Invoke the tests using background jobs on the remote nodes and wait for these jobs to complete, finally process and output a JSON object back.
5. It also exports a global variable named $PSRemotely to which the Node bootstrap map and PSSession information is stored.

## Remote Ops validation

Well this is a term coined by us for some of the infrastucture validation being done for Engineered solutions.
So taking liberty to use this here. 

Suppose, you already have below Pester test for some nodes in our environment:

```powershell
Describe 'Bits Service test' {
    
    $BitsService = Get-Service -Name Bits
    
    It "Should have a service named bits" {
        $BitsService | Should Not BeNullOrEmpty
    }
    
    it 'Should be running' {
        $BitsService.Status | Should be 'Running'
    }
}
```
If you want to target the very same tests on the remote node named say AD,WDS & DHCP from your current workstation (part of the same domain), you can use PSRemotely.


Usage with PSRemotely:

```powershell
PSRemotely {
	
    Node AD, WDS, DHCP {
		
        Describe 'Bits Service test' {
		
            $BitsService = Get-Service -Name Bits
            
            It "Should have a service named bits" {
                $BitsService | Should Not BeNullOrEmpty
            }
            
            It 'Should be running' {
                $BitsService.Status | Should be 'Running'
            }
        }		
	}
}
```
Once you have the tests file ready , save it with a <FileName>.PSRemotely.ps1 extension, below is how you invoke the PSRemotely framework to start the remote ops validation : 

```powershell
Invoke-PSRemotely -Script <FileName>.PSRemotely.ps1
```

Output of the above is a JSON object, if the tests pass then an empty JSON object array of *TestResult* is returned 
otherwise the Error record thrown by Pester is returned :

```json
{
    "Status":  true,
    "NodeName":  "WDS",
    "Tests":  [
                  {
                      "TestResult":  [

                                     ],
                      "Result":  true,
                      "Name":  "Bits Service test"
                  }
              ]
}
{
    "Status":  true,
    "NodeName":  "AD",
    "Tests":  [
                  {
                      "TestResult":  [

                                     ],
                      "Result":  true,
                      "Name":  "Bits Service test"
                  }
              ]
}
{
    "Status":  true,
    "NodeName":  "DHCP",
    "Tests":  [
                  {
                      "TestResult":  [

                                     ],
                      "Result":  true,
                      "Name":  "Bits Service test"
                  }
              ]
}
```


## Initial PSRemotely setup

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the PSRemotely folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

    #Simple alternative, if you have PowerShell 5, or the PowerShellGet module:
        Install-Module PSRemotely

# Import the module.
    Import-Module PSRemotely    # Alternatively, Import-Module \\Path\To\PSRemotely

# Get commands in the module
    Get-Command -Module PSRemotely

# Get help for the module and a command
    
    Get-Help Invoke-PSRemotely -full
```
## More Information

The [PSRemotely docs](http://psremotely.readthedocs.io/) will include more information, including :

* PSRemotely Basics
* PSRemotely Examples
* PSRemotely How Tos

## Notes

Thanks goes to :

- [Remotely project](https://github.com/PowerShell/Remotely) 
- [Ravikanth Chaganti](https://twitter.com/ravikanth) - For all the help with the ideas and motivation behind the scenes.
- Warren Frame's [PSDeploy module ](https://github.com/RamblingCookieMonster/PSDeploy) - have been following Warren's module & documentation structure to organize.
- [Pester module] (https://github.com/pester/pester), PSDesiredStateConfiguration module for borrowing some of the ideas.
- PowerShell community & fellow MVPs, who are fantastic at helping each other.

## TO DO 

PSRemotely in its current form works for our needs to validate some of the Engineered solutions.
But it has the potential to grow into something bigger, below are some of the items in the wishlist :

- Use PowerShell classes, and add support for providers for nodes running either On-prem or on Cloud (AWS or Azure).
- Integrate with JEA, since PSRemotely uses PSSession endpoints these can be locked down using JEA on the nodes.
- More unit tests, lacking far behind in this aspect. More focus on it once we start working with the classes implementation.
- Faster background processing of the remote node jobs, using runspaces.

Feel free to submit any ideas, bugs or pull requests.