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

