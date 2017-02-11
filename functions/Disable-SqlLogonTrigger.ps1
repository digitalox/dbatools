Function Disable-SqlLogonTrigger
{
<#
.SYNOPSIS
This command will disable SQL Server logon triggers.

.DESCRIPTION
SQL Logon triggers are fired in response to a LOGON event and execute a stored procedure between the authentication and final establishment of the session. They can be used for auditing and/or control of specific logons.
Care must be taken login triggers as they can prevent all logins to the box; in that case the DAC or starting SQL from the cmd line in single user mode should be used to connect and shut off the rogue trigger.
	
.PARAMETER SqlServer
The SQL Server instance. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter. 

Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. To connect as a different Windows user, run PowerShell as that user.

.PARAMETER TriggerName
The name of a specific logon trigger to disable.

.PARAMETER DisableAll
Disable all logon triggers not shipped by Microsoft.

.NOTES 
Original Author: Scott Dubose (@dansqldba)
Further reading: SQL Logon Triggers         - https://msdn.microsoft.com/en-us/library/bb326598.aspx
                 Dedicated Admin Connection - https://msdn.microsoft.com/en-us/library/ms189595.aspx

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Disable-SqlLogonTrigger

.EXAMPLE   (Try to have at least 3 for more advanced commands)
Disable-SqlLogonTrigger -SqlServer sqlserver2014a -TriggerName sometrigger

Disables the specified trigger

.EXAMPLE   
Disable-SqlLogonTrigger -SqlServer sqlserver2014a -DisableAll

Disables all user logon triggers, Microsoft shipped triggers are untouched.

#>
	
	# This is a sample. Please continue to use aliases for discoverability. Also keep the [object] type for sqlserver.
	[CmdletBinding( SupportsShouldProcess = $true )]
	Param (
		[parameter( Mandatory = $true, ValueFromPipeline = $true ) ]
		[Alias( "ServerInstance", "SqlInstance" ) ]
		[object]$SqlServer,
		[parameter( ParameterSetName = 'SpecificLogonTriggers', ValueFromPipeline = $true ) ]
		[object[]] $LogonTriggers,
		[System.Management.Automation.PSCredential] $SqlCredential,
		[parameter( ParameterSetName = 'setAll' ) ]
        [switch] $setAll,
		[parameter( ParameterSetName = 'SpecificLogonTriggers', ValueFromPipeline = $true ) ]
		[parameter( ParameterSetName = 'setAll', ValueFromPipeline = $true ) ]
        [Parameter( ParameterSetName=’EnableLogin’ )]
        [switch] $enable,
		[parameter( ParameterSetName = 'SpecificLogonTriggers', ValueFromPipeline = $true ) ]
		[parameter( ParameterSetName = 'setAll', ValueFromPipeline = $true ) ]
        [Parameter(ParameterSetName=’DisableLogin’)]
        [switch] $disable
	)
    
    # todo: this returns all server triggers not just logon triggers
	#DynamicParam { if ($sqlserver) { return (Get-ParamSqlServerTriggers -SqlServer $sqlserver -SqlCredential $SourceSqlCredential) } }
		
	BEGIN
	{
        Write-Verbose "SqlServer: $SqlServer"
        Write-Verbose "Parameter Set: $PSCmdlet.ParameterSetName"
		if ( ( $PSCmdlet.ParameterSetName -eq "SpecificLogonTriggers" -and ( $LogonTriggers -eq $null -or $LogonTriggers.Count -eq 0 ) ) -and $setAll -eq $false )
		{
			Write-Error "You must specify -LogonTriggers or -DisableAll"
			return
		}

		Write-Output "Attempting to connect to SQL Server.."
		
		$sourceserver = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
		$source = $sourceserver.DomainInstanceName
		
		if ($sourceserver.versionMajor -lt 10 )
		{
			throw "SQL Logon Triggers are only supported in SQL Server 2008 and above. Quitting."
		}
		
	}
	
	PROCESS
	{
		
        if ( $setAll ) { $triggers = $sourceserver.Triggers } else { $triggers = $LogonTriggers }

	    foreach ( $trigger in $triggers )  { 
		    If ( $Pscmdlet.ShouldProcess( "${trigger}", "Disabling Logon Trigger: ${trigger}") )
		    {
                $_.IsEnabled = $enable
                $_.Alter()
            }
        } 

        # $sourceserver.Alter()
 		
	}
	
	# END is to disconnect from servers and finish up the script. When using the pipeline, things in here will be executed last and only once.
	END
	{
		If ($Pscmdlet.ShouldProcess("console", "Showing final message"))
		{
			Write-Output "SQL Logon Trigger(s) disabled"
		}
		
		$sourceserver.ConnectionContext.Disconnect()
	}
}