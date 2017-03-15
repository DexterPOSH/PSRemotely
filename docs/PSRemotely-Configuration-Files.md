PSRemotely at the moment have only one configuration file to work with:

## PSRemotely configuration file - PSRemotely.json (placed under PSRemotely Root folder)

Below is how the PSRemotely.json file looks like.
```json
{
    "RemotelyNodePath": "C:\\Temp\\Remotely",
    "modulesRequired": [
        {
            "Modulename": "Pester",
            "ModuleVersion": "3.3.14"
        }
    ],
    "artifactsRequired":[
       "DeploymentManifest.xml" 
    ]
}
```

Each property in the PSRemotely.json file is a configuration used by the PSRemotely framework.
Below is the explanation on how these fields are used :

* RemotelyNodePath - Specfies the path used on the remote node to dump the tests file and store Pester Nunit test results.

* modulesRequired - An array of modules required on the remote node (stored locally under the /lib folder), 
copied to the RemotelyNodePath location. These modules are copied and imported on the PSSession before the tests are invoked.

* artifactsRequired - An array of files which are copied each time to the remote nodes (stored locally under the /lib/artifacts folder),
after PS Remotely is invoked.