$LocalAdminCreds = New-Object -Typename PSCredential -ArgumentList 'Administrator',$(ConvertTo-SecureString -String 'Dell1234' -AsPlainText  -Force)
$CredHash = @{
    'WDS' = $LocalAdminCreds
    'PXE' = $LocalAdminCreds
}

Describe "Add-Numbers" {
    It "adds positive numbers on two remote systems" {
        Remotely ($CredHash.Keys) { 2 + 3 } | Should Be 5
    }

    It "gets verbose message" {
        $sum = Remotely 'WDS','PXE' { Write-Verbose -Verbose "Test Message" }
        $sum.GetVerbose() | Should Be "Test Message"
    }

    It "can pass parameters to remote block with different credentials" {
        $num = 10
        $process = Remotely 'VM1' { param($number) $number + 1 } -ArgumentList $num -CredentialHash $CredHash
        $process | Should Be 11
    }
}