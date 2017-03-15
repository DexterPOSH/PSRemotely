# PSRemotely Workflow

PSRemotely is a very simple module. Below is how it works.
It works in three stages :

 1. BootStrap
 2. CopyTests
 3. InvokeTests

If you have a test file say  Server1.PSRemotely.ps1, see below :

```powershell
Remotely {
	Node Server1, Server2, Server3 {
		
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

## BootStrap Stage 

PSRemotely starts by looking at the names of the servers supplied to it with the *Node* keyword or it looks at the DSC style configuration data.
In the background it does a bunch of stuff referred to as 'bootstrapping'. During the bootstrapping phase for a node, below happens in the background: 

1. Create a PSSession to the remote nodes (supplying credentials is supported). 
It will also store the Node's PSSession, Credential information in a hashtable.

2. Test & Create the RemotelyNodePath (local path on the  remote Node used by PSRemotely).

3. Test & Copy if the modules required are present inside the RemotelyNodePath\Lib folder on the nodes.

4. Maintain a NodeMap hashtable for each node with the information that above pre-requisites are taken care of.


## CopyTests Stage

After bootstrapping of the remote nodes is done, PSRemotely uses AST to parse the Pester Describe blocks inside the Node defintion.
Foreach Describe block PSRemotely finds, it will copy a file named in the format <RemoteNodeName>.<Describe_block_name>.Tests.ps1 
to the RemotelyNodePath on the remote node.

## InvokeTests Stage

After the tests are copied to the remote nodes, PSRemotely will invoke the tests using background jobs on the remote nodes.
It will sleep for five seconds and monitor if any of the jobs completed, once the job completes it will process the Pester output 
and give back a simplified JSON object

