# Using PoshSpec with PSRemotely

If you wish to use PoshSpec to write operations validation tests using PoshSpec then you can do
so but you will have to take care of the below :
- add the PoshSpec to the modulesrequired entry in the PSRemotely.json file 
- copy the module under the PSRemotelyRoot\lib folder.

## Add to the modulesrequired in PSRemotely.json

All the modules which are required on the remote node before invoking operations validation tests
are defined in the modulesrequired entry in the PSRemotely.json file.
So add the entry for PoshSpec like below :

```json
{
    "PSRemotelyNodePath": "C:\\Temp\\PSRemotely",
    "modulesRequired": [
        {
            "Modulename": "Pester",
            "ModuleVersion": "3.3.14"
        },
        {
            "Modulename": "PoshSpec",
            "ModuleVersion": "2.1.12"
        }
    ],
    "ArtifactsRequired":[
       "" 
    ]
}
```

Now notice that you need to copy the PoshSpec module with the very same version mentioned above under 
the PSRemotelyRoot\lib folder.

```powershell
Save-Module -name PoshSpec -RequiredVersion 2.1.12 -Path .\PSRemotely\Lib -Verbose
```

The above will create the folder structure like below, under the lib folder (which PSRemotely works with)

+ PSRemotely
    + lib
        + PoshSpec
            + 2.1.12

Now you can start authoring your tests using PoshSpec and target them for execution using PSRemotely.
Below is an example of using PSRemotely, Pester and PoshSpec in conjunction.

```powershell

PSRemotely -Verbose {
    Node ComputeNode1, ComputeNode2 {
        Describe 'BaselineServerTests' {
            Context 'Critical Services test' {
                Service winrm {Should be 'Running'}
                Service vmcompute { Should be 'Running'}
            }
        }
    }
}

```
Note - Using PoshSpec style tests to target operations validation against the localhost fails (remote nodes do work), haven't got around
to check why that is the case but that is something uncovered while writing this doc.
