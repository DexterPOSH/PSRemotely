### PSRemotely Installation

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the PSRemotely folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

    #Simple alternative, if you have PowerShell 5, or the PowerShellGet module:
        Install-Module PSRemotely

# Import the module.
    Import-Module PSRemotely    #Alternatively, Import-Module \\Path\To\PSRemotely

# Get commands in the module
    Get-Command -Module PSRemotely

# Get help for the module and a command
    Get-Help about_PSRemotely
    Get-Help Invoke-PSRemotely -full       # *.tests.ps1 based operation validation
```

### PSRemotely Example

All you need is a *.Tests.ps1 file that tell PSRemotely about your remote operation validation. Here's a quick example.

Here are some source files I want to deploy:

[![Source](images/DirFrom.png)](images/DirFrom.png)

Here's my *.tests.ps1 file

```powershell
Remotely {
	Node localhost {
		Describe 'Bits Service test' {
			
			$BitsService = Get-Service -Name Bits
			
			It "Should have a service named bits" {
				$BitsService | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$BitsService.Status | Should be 'Running'
			}
		}		
	}
}


```

We invoke the PSRemotely similar to Invoke-Pester:

```powershell
PS C:\PSRemotely> Invoke-PSRemotely
```

Your Remote operation validations are parsed and carried out:

[![GCI Output](images/QuickStart.AfterInvoke.png)](images/QuickStart.AfterInvoke.png)

