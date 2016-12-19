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
	$describeASTs = $commandAST | Where-Object -FilterScript {$PSItem.GetCommandName() -eq 'Describe'}
	if ($describeASTs) {
		foreach ($describeAST in $describeASTs) {
			$TestNameElement = $describeAST.CommandElements | Select-Object -First 2 | Where-Object -FilterScript {$PSitem.Value -ne 'Describe'}

			Switch -Exact ($TestNameElement.StringConstantType ) {
			
				'DoubleQuoted' {
					# if the test name is a double quoted string
					$output += @{
						#Add the test name as key and testBlock string as value 
						$($ExecutionContext.InvokeCommand.ExpandString($TestNameElement.Value)) = $($describeAST.Extent.Text)
					}
					break
				}
				'SingleQuoted' {
					# if the test name is a single quoted string
					$output += @{
						$($TestNameElement.Value) = $($describeAST.Extent.Text)
					}
					break
				}
				default {
					throw 'TestName passed to Describe block should be a string'
				}
			}
		} # end foreach block
		Write-Output -InputObject $output
	}
	else {
		throw 'Describe block not found in the Test Body.'
	}
	
}