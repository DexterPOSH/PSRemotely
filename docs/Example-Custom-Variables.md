# PSRemotely example using custom variables

PSRemotely allows you to specify a variable which needs to be available on the remote nodes.

If you needed to make a variable available on the remote node during the invocation of the Pester 
tests then you can specify these as a hashtable to the paramter -ArgumentList.

```powershell
Remotely -ArgumentList @{ServiceName='bits'} {
    Node AD {

        Describe "$ServiceName running test" {
            $Service = Get-Service -Name $ServiceName

	        It 'Should be running' {
		        $Service.Status | Should be 'Running'
	        }

        }
    }
}
```