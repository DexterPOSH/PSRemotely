if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force




InModuleScope -ModuleName $ENV:BHProjectName {
    
    Get-Service -Name WinRM | Restart-Service
    $Session = New-PSSession -ComputerName Localhost -EnableNetworkAccess

    Describe 'Node' {

        Context "Already opened PSRemotely session to nodes present" {
            
            It 'TO DO - add more tests' {
                # leaving it empty
            }
        }	
    }
}