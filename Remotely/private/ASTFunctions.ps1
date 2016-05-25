Function Get-TestName {
	[OutputType([String])]
	param(
		[Parameter()]
		[String]$Content
	)
	$AST = [System.Management.Automation.Language.Parser]::ParseInput($Content,[ref]$null,[ref]$Null)

	$CommandAST = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst]}, $true)    

	$DescribeAST = $CommandAST | Where-Object -FilterScript {$PSItem.GetCommandName() -eq 'Describe'}
	if ($DescribeAST) {
		$TestNameElement = $DescribeAST.CommandElements | Select-Object -First 2 | Where-Object -FilterScript {$PSitem.Value -ne 'Describe'}

		Switch -Exact ($TestNameElement.StringConstantType ) {
		
			'DoubleQuoted' {
				# if the test name is a double quoted string
				Write-Output -InputObject $ExecutionContext.InvokeCommand.ExpandString($TestNameElement.Value)
			}
			'SingleQuoted' {
				# if the test name is a single quoted string
				Write-Output -InputObject $TestNameElement.Value
			}
			default {
				throw 'TestName passed to Describe block should be a string'
			}
		}
	}
	else {
		throw 'Describe block not found in the Test Body.'
	}
	
}