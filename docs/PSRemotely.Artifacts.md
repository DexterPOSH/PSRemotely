# Copy Artifacts to PSRemotely Nodes

In some of the scenarios within our engineered solution scope, we had to copy a manifest file on all 
the nodes in order to read some environment specific details for the validation tests.

So we had to bake this capability within the framework, so that we always have the most recent manifest copied to the nodes.
At the moment, there is a global PSRemotely configuration which means that all the modules and artifacts marked as required in the 
PSRemotely.json file are copied to all the nodes being targeted.

So the first step for specifying to PSRemotely which artifacts to be copied to the remote nodes,
one has to mention the name of the artifacts (json list) in the PSRemotely.json file (located under the PSRemotely root folder).

See below, 'DeploymentManifest.xml' and 'Dummy.zip' are mentioned as required artifacts in the PSRemotely.json.

```json
{
    "PSRemotelyNodePath": "C:\\Temp\\PSRemotely",
    "modulesRequired": [
        {
            "Modulename": "Pester",
            "ModuleVersion": "3.3.14"
        }
    ],
    "ArtifactsRequired":[
       "DeploymentManifest.xml",
       "Dummy.zip"
    ]
}
```

Now the next step is to **copy these artifacts under the PSRemotely\Lib\Artifacts folder**, if the folder is not there create it.
You can place any number of items in the artifacts folder, but only the ones mentioned in the PSRemotely.json are copied.

Once done, you need to import the module again (PSRemotely.json) is read while the module is imported only. 
Invoke your PSRemotely tests now.