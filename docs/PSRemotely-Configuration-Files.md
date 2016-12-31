PSRemotely at the moment have only one configuration file to work with:

* PSRemotely configurations: Remotely.json file

```json
{
    "RemotelyNodePath": "C:\\Temp\\Remotely",
    "modulesRequired": [
        {
            "Modulename": "Pester",
            "ModuleVersion": "3.3.14"
        }
    ],
    "ArtefactsRequired":[
       "DeploymentManifest.xml" 
    ]
}
```

* RemotelyNodePath - Specfies the path used on the Remotely node to dump the tests file and store Pester Nunit test results.

* modulesRequired - An array of modules required on the Remotely node (stored locally under the /lib folder), 
copied to the RemotelyNodePath location. These modules are copied and imported on the PSSession before the tests are invoked.

* ArtefactsRequired - An array of files which are copied each time to the Remotely nodes (stored locally under the /lib/artefacts folder),
after PS Remotely is invoked.