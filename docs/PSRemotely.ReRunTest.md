# Re-run a failed test

This is one of those 'good to have' feature. Suppose you are using PSRemotely to orchestrate operations
validation across a number of nodes and on one or few of the nodes a specific test failed.

Now you applied a fix for that and want to quickly verify if the remediation method worked or not.
Ofcourse you can call *Invoke-PSRemotely* to run the entire operations validations tests suite again
on the nodes or you can pass a specifically constructued JSON object to instruct PSRemotely to run
specific tests. Well these Pester/PoshSpec tests are already copied from the previous run of PSRemotely and
also it will utilize already opened PSSession to the remote node for running these.

Construct the object in PowerShell

```powershell 
$InputObject = [PSCustomObject]@{
    "NodeName" = 'Node1';
    "Tests" = @( # Array of ke-value pairs of the test names to be run again
        @{
            "Name" = "Bits Service test" # Failed tests number 1 in previous run
        },
        @{
            "Name" = "Domain membership test" # Failed test Number 2 in previous run
        }
    )
}
```

Now you can invoke PSRemotely like below to only target specific tests on a node :-

```powershell
Invoke-PSRemotely -JSONInput ($InputObject | ConvertTo-Json)
```