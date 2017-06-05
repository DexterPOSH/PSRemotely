Function Get-ASTFromInput {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]$Content
	)
	$ast = [System.Management.Automation.Language.Parser]::ParseInput($Content,[ref]$null,[ref]$Null)
	return $ast
}

Function Get-TestNameAndTestBlock {
	[OutputType([String])]
	param(
		[Parameter()]
		[String]$Content
	)
	
	$ast = Get-ASTFromInput -Content $Content
	$commandAST = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst]}, $true)    
	$output = @()
	# fetch all the Describe blocks using AST
	$describeASTs = $commandAST | Where-Object -FilterScript {$PSItem.GetCommandName() -eq 'Describe'}
	if ($describeASTs) {
		# iterate over each Describe block, this means that PSRemotely allows usage of multiple Describe
		# block within a Node block.
		foreach ($describeAST in $describeASTs) {

            $ScriptBlock = [scriptblock]::create("$($describeAST.Extent.Text)") 
			#$TestNameElement = $describeAST.CommandElements | Select-Object -First 2 | Where-Object -FilterScript {$PSitem.Value -ne 'Describe'}
			$ParametersPassedToDescribe = Get-ParametersPassedToDSLKeyword -FunctionInfo $(Get-Command -Module Pester -Name Describe) -ScriptBlock $ScriptBlock
            # since there is a limitation while generating parameters from the proxy command
            # we need to explicitly check that the name and fixture are not empty here
            if (-not $ParametersPassedToDescribe['name'] -or (-not $ParametersPassedToDescribe['Fixture'])) {
                throw 'Name or Fixture missing in the Describe block'
            }
			$output += @{
				$ParametersPassedToDescribe['Name'] = $($describeAST.Extent.Text)
			}
			
		} # end foreach block
		Write-Output -InputObject $output
	}
	else {
		throw 'Describe block not found in the Test Body.'
	}
}

Function Get-ParametersPassedToDSLKeyword {
	<#
		This function is a magic function. Specify it a module's DSL keyword function metadata along
		with the actual usage of the DSL and it will return the PSBoundParameters being passed to the
		original DSL keyword.

		This was written in order to determine the test names of the Describe block wrapped inside 
		PSRemotely DSL. Since these test names are later used while dropping individual .Tests.ps1 
		files on the PSRemotely node(s).
	#>
	[cmdletbinding()]
    param(
        # Supply the script info object, output of Get-Command -Name <DeploymentScript>.ps1
        [Parameter(Mandatory)]
		[System.Management.Automation.FunctionInfo]$FunctionInfo,

		[Parameter(Mandatory)]
		[ScriptBlock]$ScriptBlock
	)

	TRY {
		$Metadata = [System.Management.Automation.CommandMetadata]::New($FunctionInfo)
		$CmdletBinding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($Metadata)
		$Parameters = [System.Management.Automation.ProxyCommand]::GetParamBlock($Metadata)

	# bad formatting due to usage of here-string
$FunctionBody = @"
	$CmdletBinding
	param(
		$Parameters
	)
	`$returnHashtable = `$PSBoundParameters    
	`$returnHashtable
"@
		$DummyFunction = [scriptblock]::Create($FunctionBody)
		$Null = New-Item -Path Function:\ -Name pSRemotelyDescribeOverride  -Value $DummyFunction -Force
		# create a temporary override for the Pester's Describe keyword
		$null = New-Alias -Name Describe -Value pSRemotelyDescribeOverride -Force

		# Now invoke the scriptblock
		$ParametersHash = & $ScriptBlock
        Write-Output -InputObject $ParametersHash
	}
	CATCH {
		Write-Warning -Message "$($PSItem.Exception)"
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
	FINALLY {
		# Clean up the alias
		Remove-Item -Path Alias:\Describe -Force -ErrorAction SilentlyContinue
	}
}