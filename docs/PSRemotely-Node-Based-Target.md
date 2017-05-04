# Using Node keyword to target different types of Nodes in a solution.

This is a most common pattern while writing remote operations validation tests for a solution nowadays.
For example take a converged infrastructure solution, this solution comprises of both compute and storage nodes deployed as part of the solution. You could have two separate files with the validations for the two types of servers in the solution, but there is a cleaner way to handle this.
PSRemotely let's you organize the tests targeted to an entire solution together in one file by making use of the Node keyword.

Node keyword is used to target and organize your tests based on some environment specific data, it is very similar to the Node keyword in the DSC.
Please see below environment configuration data where in the node configuration data there is an attribute called **type** which defines whether the node is a compute or storage node. 

```powershell
# Configuration data for a Converged Infrastructure solution. There are both compute and storage nodes here.
$ConfigData = @{
    AllNodes = @(
        @{
            # common node information hashtable
            NodeName = '*'; # do not edit
            Domain = 'dexter.lab'
        },
        @{ 
            # Individual node information hashtable for storage node
            NodeName = 'StorageNode1'
            Type = 'Storage'
        },
        @{
            NodeName = 'StorageNode2' 
            Type = 'Storage'
        },
        @{
            NodeName = 'ComputeNode2' 
            Type = 'Compute'
        },
        @{
            NodeName = 'ComputeNode2' 
            Type = 'Compute'
        },
        @{
            NodeName = 'ComputeNode3' 
            Type = 'Compute'
        },
        @{
            NodeName = 'ComputeNode4' 
            Type = 'Compute'
        }
    )
}
```

We can use two different Node blocks to organize tests targeted to the compute and storage nodes in a single file.

```powershell
# Using the PSRemotely DSL to organize tests in a single file for the CI solution. See that configuration data hashtable can be specified to PSRemotely directly here.
PSRemotely -ConfigurationData $ConfigData {

    Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
        # Houses Ops validation for the compute nodes
        Describe 'Compute node tests' {
            # place tests here
        }
    }

    Node $AllNodes.Where({$PSItem.Type -eq 'Storage'}).NodeName {
        # Houses Ops validation for the compute nodes
        Describe 'Storage node tests' {
            # place tests here
        }
    }
}

```

Save the above code snippets in a file with a .PSRemotely.ps1 extension and you are all set.