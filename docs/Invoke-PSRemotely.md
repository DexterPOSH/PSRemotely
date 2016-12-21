# Invoking PSRemotely

Invoking PSRemotely to run remote ops validation, is very similar to Pester's Invoke-Pester.


## Run all the PSRemotely tests placed in a folder

```powershell
Invoke-PSRemotely C:\EnvironmentValidation
```

## Run a specific PSRemotely test

```powershell
Invoke-PSRemotely -Script C:\EnvironmentValidation\ComputeNodeTests.PSRemotely.ps1
```

## Run a specific PSRemotely test and supply parameters & arguments to the PSRemotely file.

```powershell
Invoke-PSRemotely -Script @{
    Path='C:\EnvironmentValidation\StorageNodeTests.PSRemotely.ps1';
    Parameters = @{Credential=$(Get-Credential)};
    Arguments = @(.\EnvironmentData.json)
}
```

This command runs C:\EnvironmentValidation\StorageNodeTests.PSRemotely.ps1 file. The PSRemotely file is expecting the path to
configuration data file (.json or .psd1) and Credential to be used to open PSSession to the nodes.
It  runs the tests in the StorageNodeTests.PSRemotely.ps1 file using the following parameters: 

```powershell
C:\EnvironmentValidation\StorageNodeTests.PSRemotely.ps1 .\EnvironmentData.json -Credential <CredentialObject> 
````

## Run failed tests on the Remote nodes

Now while working with ops validation, you might have scripts or DSC configuration in place which fix the issue.
So suppose, you ran the tests like below to begin with against your compute nodes in the Environment :-

```powershell
Invoke-PSRemotely -Script C:\EnvironmentValidation\ComputeNodeTests.PSRemotely.ps1
```

And suppose the ops validation tests named "TestDNSConnectivity" failed on the remote node named 'ComputeNode1'.
You have fixed the issue and want to only run the failed test on the node, you can use the below method :-

```powershell
$TestsTobeRunObejct = [pscustomobject]@{NodeName='ComputeNode1';Tests=@(@{Name='TestDNSConnectivity'})}
Invoke-PSRemotely -JSONInput $($TestsTobeRunObejct | ConvertTo-Json) 
```
The above JSON input object instructs PSRemotely to use the earlier created PSSession to connect to the node and
run the required tests on the remote node.

