# PSRemotely example with Configuration data

PSRemotely lets you specify DSC style Configuration data for the Nodes.
It only looks for the AllNodes key in the Configuration data hashtable, since the framework is about Remote ops validation.
In future, the ability to pass non node data can be implemented.
There are three ways at the moment to specify configuration data to PSRemotely :

- PSRemotely file - Using the PSRemotely file, tests along with configuration data live in the same .PSRemotely.ps1 file.
- .PSD1 file - Separating configuration data into a .PSD1 file and using it.
- JSON file - Separating configuration data into a .JSON file and using it.

## Example - Specify Configuration data in the PSRemotely file

One can specify the configuration data to PSRemotely file by placing it in the same file where the remote ops tests are placed.
Below are the contents of a file named ConfigData.PSRemotely.ps1 file :-

```powershell
# Configuration data
$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="Compute-11";
			ServiceName = 'vmms';
			Type='Compute';

		},
		@{
			NodeName='Storage-12';
			ServiceName = 'bits';
			Type='Storage';
		}
	)
}

# PSRemotely tests
PSRemotely -ConfigurationData $ConfigData {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $node.ServiceName # See the use of $node variable here
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
```

In order to invoke the PSRemotely , just specify the path to the PSRemotely file :-

```powershell
Invoke-PSRemotely -Script <Path to ConfigData.PSRemotely.ps1>
```

## Example - Specify Configuration data from a .PSD1 file

One can also maintain the environment data in a .psd1 file and maintain it separately.
The path to the .psd1 file can be specified to PSRemotely.

Note - The contents of the .PSD1 file have to follow the DSC style configuration data rules. 

Contents of the dev_environment.psd1 file :-

```powershell
@{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="Compute-11";
			ServiceName = 'vmms';
			Type='Compute';

		},
		@{
			NodeName='Storage-12';
			ServiceName = 'winrm';
			Type='Storage';
		}
	)
```
Now the path can be passed to the PSRemotely file as a parameter. Below are the contents of ConfigData_with_psd1.PSRemotely.ps1 :-

```powershell
param($PSD1ConfigDataPath)

PSRemotely -Path $PSD1ConfigDataPath  {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $node.ServiceName # See the use of $node variable here
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
``` 

And in order to invoke PSRemotely along with specifying the .psd1 file, use the below format :

```powershell
Invoke-PSRemotely -Script @{
    Path="<Path to the ConfigData_with_psd1.PSRemotely.ps1>";
    Parameters=@{PSD1ConfigDataPath="<Path to the dev_environment.psd1>"}
}
```


## Example - Specify Configuration data from a .json file

One can also maintain the environment data in a .json file and maintain it separately.
The path to the .json file can be specified to PSRemotely later.

Note - The contents of the .JSON file have to follow the DSC style configuration data rules.

Contents of the dev_environment.json file :-

```json
{
    "AllNodes" : [
        {
            "NodeName" : "*",
            "DomainFQDN" : "dexter.lab"
        },
        {
            "NodeName" : "Compute-11",
            "ServiceName" : "vmms",
            "Type" : "Compute"
        },
        {
            "NodeName" : "Storage-12",
            "ServiceName" : "bits",
            "Type" : "Compute"
        }
    ]
}
```

Now the path can be passed to the PSRemotely file as a parameter. Below are the contents of ConfigData_with_psd1.PSRemotely.ps1 :-

```powershell
param($JSONConfigDataPath)

PSRemotely -Path $JSONConfigDataPath  {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $node.ServiceName # See the use of $node variable here
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
``` 

And in order to invoke PSRemotely along with specifying the .json file, use the below format :

```powershell
Invoke-PSRemotely -Script @{
    Path="<Path to the ConfigData_with_psd1.PSRemotely.ps1>";
    Parameters=@{PSD1ConfigDataPath="<Path to the dev_environment.json>"}
}
```

