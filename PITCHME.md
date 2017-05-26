## Operations Validation

### Why Operations Validation?
- <span style="font-size:0.9em; color:gray">Validating your Infrastructure as Code.</span>
- <span style="font-size:0.9em; color:gray">Tests if the infrastructure components are functional.</span>

+++

<span style="font-size:1.0em; color:gray">Fits into the DevOps ecosystem.</span> |
<span style="font-size:1.0em; color:gray"></span>

---
## PowerShell Scripts ?

- <span style="font-size:0.9em; color:gray">Can be used.</span>
- <span style="font-size:0.9em; color:gray">Maintenance nightmare.</span>

+++

<span style="font-size:1.0em; color:red">Tip - Avoid writing scripts for validating your infrastructure.</span>

---

## Pester and PoshSpec

Pester is a Unit testing framework.
Only the code logic is tested.

```powershell
Function Get-ServerInfo {
    Get-CIMInstance -Class Win32_ComputerSystem | 
        Select-Object -Property *
}

Describe 'Get-ServerInfo Unit tests' {
    # Arrange
    Mock -Command Get-CimInstance -FilterParameter {$Class -eq 'Win32_ComputerSystem' }
    # Act
    Get-ServerInfo 
    # Assert
    It "Should query the Win32_ComputerSystem class" {
        Assert-MockCalled -Command Get-CimInstance -Times 1 -Exactly -Scope Describe
    }
}
```

+++
### Pester for Ops validation

But Pester can be extended to validate/test Infrastructure as well.

```powershell
Describe "TestIPConfiguration" {
    It "Should have a valid IP address on the Management NIC" {
        (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'vEthernet(Management)' | Select-Object -ExpandProperty IPAddress) |
            Should be '10.10.10.1' 
    }
}
```

+++

### PoshSpec fits in

PoshSpec adds yet another layer of abstraction on our infrastructure tests.
The tests look concise and easy to maintain.

```powershell
Describe "TestIPConfiguration" {
    Context "Validate the Management NIC " {
        # Custom public type added to PoshSpec for our use.
        IPv4Address 'vEthernet(Management)' {Should be '10.10.10.1'} 
    }
}
```

---

## Challenges for Solution stack Ops validation
- <span style="font-size:0.9em; color:gray">Targeting remote nodes for ops validation is still an overhead.</span>
- <span style="font-size:0.9em; color:gray">Remote nodes need to bootstrapped before invoking the ops validation.</span>
- <span style="font-size:0.9em; color:gray">Challenge in specifying node and solution configuration data.</span>


---

## Enter Remote operations validation

![alt](PSRemotely.png)

PSRemotely was engineered with solution stack operations validation in mind. Few of its features:-
- <span style="font-size:0.6em; color:gray">Target Pester/PoshSpec based operations validation tests on the remote nodes.</span>
- <span style="font-size:0.6em; color:gray">Decouples node and solution configuration data using DSC config data syntax.</span>
- <span style="font-size:0.6em; color:gray">Self-contained framework, bootstraps remote node(s) for running the ops validation.</span>
- <span style="font-size:0.6em; color:gray">Allows re-running failed tests.</span>
- <span style="font-size:0.6em; color:gray">Easier debugging.</span>
---

## Demo Validating a S2D cluster using PSRemotely