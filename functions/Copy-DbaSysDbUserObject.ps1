function Copy-DbaSysDbUserObject {
    <#
        .SYNOPSIS
            Imports all user objects found in source SQL Server's master, msdb and model databases to the destination.

        .DESCRIPTION
            Imports all user objects found in source SQL Server's master, msdb and model databases to the destination. This is useful because many DBAs store backup/maintenance procs/tables/triggers/etc (among other things) in master or msdb.

            It is also useful for migrating objects within the model database.

        .PARAMETER Source
            Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

        .PARAMETER SourceSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Destination
            Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2000 or higher.

        .PARAMETER DestinationSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Migration, SystemDatabase, UserObject

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Copy-DbaSysDbUserObject

        .EXAMPLE
            Copy-DbaSysDbUserObject $sourceServer $destserver

            Copies user objects from source to destination
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [DbaInstanceParameter]$Source,
        [PSCredential]$SourceSqlCredential,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [DbaInstanceParameter[]]$Destination,
        [PSCredential]$DestinationSqlCredential,
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        try {
            Write-Message -Level Verbose -Message "Connecting to $Source"
            $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $Source
            return
        }
        
        if (!(Test-SqlSa -SqlInstance $sourceServer -SqlCredential $SourceSqlCredential)) {
            Stop-Function -Message "Not a sysadmin on $source. Quitting."
            return
        }
        
        if (Test-FunctionInterrupt) { return }
        foreach ($destinstance in $Destination) {
            try {
                Write-Message -Level Verbose -Message "Connecting to $destinstance"
                $destServer = Connect-SqlInstance -SqlInstance $destinstance -SqlCredential $DestinationSqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $destinstance -Continue
            }
            
            if (!(Test-SqlSa -SqlInstance $destServer -SqlCredential $DestinationSqlCredential)) {
                Stop-Function -Message "Not a sysadmin on $destinstance. Quitting."
                return
            }
            
            $systemDbs = "master", "model", "msdb"
            
            foreach ($systemDb in $systemDbs) {
                $sysdb = $sourceServer.databases[$systemDb]
                $transfer = New-Object Microsoft.SqlServer.Management.Smo.Transfer $sysdb
                $transfer.CopyAllObjects = $false
                $transfer.CopyAllDatabaseTriggers = $true
                $transfer.CopyAllDefaults = $true
                $transfer.CopyAllRoles = $true
                $transfer.CopyAllRules = $true
                $transfer.CopyAllSchemas = $true
                $transfer.CopyAllSequences = $true
                $transfer.CopyAllSqlAssemblies = $true
                $transfer.CopyAllSynonyms = $true
                $transfer.CopyAllTables = $true
                $transfer.CopyAllViews = $true
                $transfer.CopyAllStoredProcedures = $true
                $transfer.CopyAllUserDefinedAggregates = $true
                $transfer.CopyAllUserDefinedDataTypes = $true
                $transfer.CopyAllUserDefinedTableTypes = $true
                $transfer.CopyAllUserDefinedTypes = $true
                $transfer.CopyAllUserDefinedFunctions = $true
                $transfer.CopyAllUsers = $true
                $transfer.PreserveDbo = $true
                $transfer.Options.AllowSystemObjects = $false
                $transfer.Options.ContinueScriptingOnError = $true
                $transfer.Options.IncludeDatabaseRoleMemberships = $true
                $transfer.Options.Indexes = $true
                $transfer.Options.Permissions = $true
                $transfer.Options.WithDependencies = $false
                
                Write-Message -Level Output -Message "Copying from $systemDb."
                try {
                    $sqlQueries = $transfer.ScriptTransfer()
                    
                    foreach ($sql in $sqlQueries) {
                        Write-Message -Level Debug -Message $sql
                        if ($PSCmdlet.ShouldProcess($destServer, $sql)) {
                            try {
                                $destServer.Query($sql, $systemDb)
                            }
                            catch {
                                # Don't care - long story having to do with duplicate stuff
                            }
                        }
                    }
                }
                catch {
                    # Don't care - long story having to do with duplicate stuff
                }
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlSysDbUserObjects
    }
}