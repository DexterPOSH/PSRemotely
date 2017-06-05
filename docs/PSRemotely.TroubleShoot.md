# TroubleShoot

So you have your tests in place in the .PSRemotely.ps1 files and you invoked them using Invoke-PSRemotely.
Now things do not always go the way you assumed. The most common issues seen with using PSRemotely to orchestrate the operations 
validation on the remote nodes is that the tests failed and you want to connect to the remote node and want to see for yourself.

So suppose you have below operations validations tests for few nodes in a .PSRemotely.ps1 file :

```powershell
# Configuration Data
$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="ComputeNode1";
			ServiceName = 'bits';
			Type='Compute';

		},
		@{
			NodeName='StorageNode1';
			ServiceName = 'winrm';
			Type='Storage';
		}
	)
}

# PSRemotely tests
PSRemotely -ConfigurationData $ConfigData {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $ServiceName # Typo here
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}

```

You invoked the tests using *Invoke-PSRemotely* and found out that some of the tests were failing on the *ComputeNode1*.
See below the snippet of the returned JSON object.

```json
{
    "Status":  false,
    "NodeName":  "ComputeNode1",
    "Tests":  [
                  {
                      "TestResult":  [
                                         {
                                             "Describe":  "Bits Service test",
                                             "Context":  "",
                                             "Name":  "Should be running",
                                             "Result":  "Failed",
                                             "ErrorRecord":  {
                                                                 "Exception":  {
                                                                                   "Message":  "Expected: {Running}\nBut was:  {Stopped}",
                                                                                   "Data":  {

                                                                                            },
                                                                                   "InnerException":  null,
                                                                                   "TargetSite":  null,
                                                                                   "StackTrace":  null,
                                                                                   "HelpLink":  null,
                                                                                   "Source":  null,
                                                                                   "HResult":  -2146233088
                                                                               },
---																			   
```

Now to troubleshoot what went wrong in the underlying PSSession where Pester was invoked, one might need to interactively connect and run Pester and see for himself..
You can drop into that PSRemoting session context by using the *Enter-PSRemotely* function which has a dynamic parameter nodename.

```powershell
Enter-PSRemotely -NodeName ComputeNode1
```

The above function call will drop you into the remote node(s) PSRemoting session and set the current location to the PSRemotelyNodePath.
Once you are connected to the remote PSSession then you can invoke the tests by calling the *Invoke-PSRemotely*.
The *Invoke-PSRemotely* function (for consistent experience in remote node) is injected into the remote PSSession and takes care of invoking Pester with necessary arguments for running the operations validation tests.

```powershell
PS C:\temp\remotely\PSRemotely\Tests\Integration> Enter-PSRemotely -NodeName ComputeNode1
[ComputeNode1]: PS C:\Temp\PSRemotely> Invoke-PSRemotely

Describing Bits Service test
 [+] Should have a service named bits 370ms
 [-] Should be running 20ms
   Expected: {Running}
   But was:  {Stopped}
   11:                          $Service.Status | Should be 'Running'
   at <ScriptBlock>, C:\Temp\PSRemotely\localhost.Bits_Service_test.Tests.ps1: line 11
Tests completed in 390ms
Passed: 1 Failed: 1 Skipped: 0 Pending: 0 Inconclusive: 0
```
The tests evidently will fail again. Now you can try seeing the status of the service for yourself.

```powershell
[ComputeNode1]: PS C:\Temp\PSRemotely> Get-Service bits

Status   Name               DisplayName
------   ----               -----------
Running  bits               Background Intelligent Transfer Ser...

[ComputeNode1]: PS C:\Temp\PSRemotely>
```

Interesting the service is running. Now it is time to inspect the tests file.

```powershell
[ComputeNode1]: PS C:\Temp\PSRemotely> Get-Content -Path .\localhost.Bits_Service_test.Tests.ps1
param($node)
Describe 'Bits Service test' {

                        $Service = Get-Service -Name $ServiceName # Typo here

                        It "Should have a service named bits" {
                                $Service | Should Not BeNullOrEmpty
                        }

                        it 'Should be running' {
                                $Service.Status | Should be 'Running'
                        }
                }
[ComputeNode1]: PS C:\Temp\PSRemotely>$ServiceName
[ComputeNode1]: PS C:\Temp\PSRemotely>

```
From a quick inspection, it is revealed that a variable **$ServiceName** is being referenced in the tests which is not defined in any scope of the remote PSSession.

So there you go, you just identified a bug in your validation code.
Now it is time for you to head back to the machine from where you ran PSRemotely, modify the validation code to replace **$ServiceName** with **$Node.ServiceName** and invoke PSRemotely again.