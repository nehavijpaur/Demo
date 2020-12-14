<#
     Azure Devops Build definition Management module.
        -   This module contains code to be used to manage Azure Devops Build definitions.
#>

#Import all the variables from variables.ps1 

$ModuleDir = Split-Path -parent $MyInvocation.MyCommand.Path
. $ModuleDir\..\Variables\Variables.ps1

function Update-AgentQueueForBuildDefs () {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$buildname,
        [Parameter(Mandatory = $true, Position=1)]
        [string]$project,
        [Parameter(Mandatory = $true, Position=2)]
        [string]$queueName,
        [Parameter(Mandatory = $true, Position=3)]
        [string]$path,
        [switch]$tfs
    )

    $buildIds = get-buildDefnIds -project $project -buildName $buildname -path $path -tfs $tfs

    foreach($buildId in $buildIds)
    {
        update-AgentqueueForBuildId -project $project -buildDefinitionID $buildId -queueName $queueName
    }

}

function Enable-build($project, $buildDefinitionID)
{
    $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"

    try {
        $buildDefinitionProperties =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        $buildDefinitionProperties.queueStatus = "enabled"
        $j = ConvertTo-Json -Depth 50 $buildDefinitionProperties
        return Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function Remove-Demands($project, $buildDefinitionID)
{
    $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"

    try {
        $buildDefinitionProperties =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        Remove-Demand -buildDefinitionProperties $buildDefinitionProperties
        Add-Comment -buildDefinitionProperties $buildDefinitionProperties -comment "Removed demands for the build"
        $j = ConvertTo-Json -Depth 50 $buildDefinitionProperties
        return Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function Add-Demands($project, $buildDefinitionID,$demand)
{
    $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"

    try {
        $buildDefinitionProperties =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        Add-Demand -buildDefinitionProperties $buildDefinitionProperties -demand $demand
        Add-Comment -buildDefinitionProperties $buildDefinitionProperties -comment "Added demand - $demand  for the build"
        $j = ConvertTo-Json -Depth 50 $buildDefinitionProperties
        return Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function Disable-build($project, $buildDefinitionID)
{
    $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"

    try {
        $buildDefinitionProperties =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        $buildDefinitionProperties.queueStatus = "disabled"
        $j = ConvertTo-Json -Depth 50 $buildDefinitionProperties
        return Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function Add-Comment($buildDefinitionProperties,$comment)
{
    if([bool]($buildDefinitionProperties.PSobject.Properties.name -match "comment"))
        {
            $buildDefinitionProperties.comment = $comment
        }
        else {
            Add-Member -InputObject $buildDefinitionProperties -MemberType NoteProperty -Name "comment" -Value $comment 
        }
}

function Add-Demand($buildDefinitionProperties,$demand)
{
    if([bool]($buildDefinitionProperties.PSobject.Properties.name -match "demands"))
        {
            $buildDefinitionProperties.demands = $demand
        }
        else {
            Add-Member -InputObject $buildDefinitionProperties -MemberType NoteProperty -Name "demands" -Value $demand 
        }
}

function Remove-Demand($buildDefinitionProperties,$demand)
{
    if([bool]($buildDefinitionProperties.PSobject.Properties.name -match "demands"))
        {
            $buildDefinitionProperties.demands = ""
        }
}
function update-AgentqueueForBuildId($project, $buildDefinitionID,$queueName)
{
    $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"

    try {
        # check if already exists
        $buildDefinitionProperties =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        if([bool]($buildDefinitionProperties.PSobject.Properties.name -match "comment"))
        {
            $buildDefinitionProperties.comment = "Updating pool for the build definition"
        }
        else {
            Add-Member -InputObject $buildDefinitionProperties -MemberType NoteProperty -Name "comment" -Value "Updating pool for the build definition" 
        }
        $buildDefinitionProperties.queue.id = get-AgentQueueId -queueName $queueName -project $project
        #$buildDefinitionProperties.queue.name = $queueName 

        if([bool]($buildDefinitionProperties.queue -match "name"))
        {
            $buildDefinitionProperties.queue.name = $queueName
        }
        else {
            Add-Member -InputObject $buildDefinitionProperties.queue -MemberType NoteProperty -Name "name" -Value $queueName 
        }

        $j = ConvertTo-Json -Depth 50 $buildDefinitionProperties 
        
        # create new
        return Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

function Get-BuildDefinitions()
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$project,

        [Parameter(Mandatory = $true, Position=1)]
        [string]$path,
        [Parameter(Mandatory = $true, Position=2)]
        [bool]$tfs
    )
    if($tfs)
    {
        $apiVersion = $tfsApiVersion
        $apiUrl = $tfsapiUrl
        $headers=Get-HeaderForTFS
    }
    $uri = "$apiUrl/$project/_apis/build/definitions?api-version=$apiVersion"

    $buildDefinitions =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers

    $defs = @($buildDefinitions.value | Where-Object {$_.path -eq $path})

    return $defs
}

function get-AgentQueueId()
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$queueName,

        [Parameter(Mandatory = $true, Position=1)]
        [string]$project
    )
    
    #ToDo: find out why this API is not present in the latest version
    $apiVersion = "5.0-preview.1"

    $uri = "$apiUrl/$project/_apis/distributedtask/queues?api-version=$apiVersion"

    $agentQueues =  Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers

    foreach ($agentqueue in $agentQueues.value)
    {
        if($agentqueue.name -eq $queueName)
        {
            return $agentqueue.id
        }
    }

}

function get-buildDefnIds()
{

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$project,

        [Parameter(Mandatory = $true, Position=1)]
        [string]$buildName,

        [Parameter(Mandatory = $true, Position=2)]
        [string]$path,
        [Parameter(Mandatory = $true, Position=3)]
        [bool]$tfs
    )

    $buildDefs = Get-BuildDefinitions -project $project -path $path -tfs $tfs

     $buildIds = @()

    foreach($buildDefn in $buildDefs)
    {
        if($buildDefn.name -like $buildName)
        {
            $buildIds += $buildDefn.id
        }
    }
    return $buildIds

}

function Update-BuildTriggers () {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$buildname,
        [Parameter(Mandatory = $true, Position=1)]
        [string]$project,
        [Parameter(Mandatory = $false, Position=2)]
        $AddTriggers=@(),
        [Parameter(Mandatory = $false, Position=3)]
        $removeTriggers=@(),
        [Parameter(Mandatory=$false, Position=4)]
        [string]$comment="Updated build triggers from Adom",
        [Parameter(Mandatory = $false, Position=5)]
        [string]$path,
        [switch]$tfs
    )

    $buildDefinitionIDs = get-buildDefnIds -project $project -buildName $buildname -path $path -tfs $tfs
    
    if($tfs)
    {
        $apiVersion = $tfsApiVersion
        $apiUrl = $tfsapiUrl
        $headers=Get-HeaderForTFS
    }

    foreach($buildDefinitionID in $buildDefinitionIDs)
    {
        $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"
        try {
            # check if already exists
            $BuildDefinition = Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers

            $request=$BuildDefinition
            $revision=$request.revision
            $id=$BuildDefinition.id
            $buildDefinitionName=$BuildDefinition.name

            $tr=$request.triggers
            $ci=$tr | Where-Object {$_.triggertype -eq "continuousIntegration" }
            $sh=$tr | Where-Object {$_.triggertype -eq "schedule" }
            if (!$ci) {
                [string[]]$curTriggers=@()
                $ci=@(
                        @{
                            branchFilters = $curTriggers;
                            pathFilters = @();
                            batchChanges = $true;
                            maxConcurrentBuildsPerBranch = 1;
                            triggerType = "continuousIntegration";
                        }
                     )
            }

            [string[]]$curTriggers=$ci[0].branchFilters

            if ($removeTriggers) {
                $newTriggers= @($curTriggers | Where-Object { $removeTriggers -notcontains $_ })
            }
            else {
                $newTriggers=@(($curTriggers + $AddTriggers | Sort-Object -Unique))
            }

            $ci[0].branchFilters=$newTriggers
            if (!$newTriggers) { $ci=@() }
            
            Write-Host ("Definition id=$id rev=$revision name=$buildDefinitionName")
            Write-Host ("current=[" + $curTriggers + "]")
            Write-Host ("new=    [" + $newTriggers + "]")

            Add-Comment -buildDefinitionProperties $request -comment $comment

            $uri = "$apiUrl/$project/_apis/build/definitions/$($id)?api-version=$apiVersion"

            $j = ConvertTo-Json -Depth 50 $request 

            $result = Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers
            Write-Host "$result`r`n"

        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "Repository Exists Error : " + $ErrorMessage
        }
    }
}

# Gets average build time for all builds under a specific project
function Get-BuildTimeForAll(){

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$serverUrl,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$organization,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$project,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$resultFilePath,
        [switch]$tfs
    )

    $apiUrl = "$serverUrl/$organization"
    if($tfs){
        $apiUrl = $tfsapiUrl
        $headers=Get-HeaderForTFS
    }
    $uri = "$apiUrl/$project/_apis/build/definitions"
    if(!(Test-Path -Path $resultFilePath))
    {
        New-Item -Path $resultFilePath -Type file
    }
    else {
        Remove-Item -Path $resultFilePath
        New-Item -Path $resultFilePath -Type file
    }
    Add-Content -Path $resultFilePath -Value "DefId  BuildName      AverageTime"
    try {
        $buildList = Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers
        foreach($item in $buildList.value)
        {
          $defid= $item.id
          $keyval = [string]$item.id+'  '+$item.name
          Write-Host $keyval
          $buildUri="$apiUrl/$project/_apis/build/builds?definitions=$defid&`$top=20&resultFilter=succeeded"
          $totalTime=0
          try {
            $buildDetails = Invoke-RestMethod -Uri $buildUri -Method Get -ContentType $contentType -Headers $headers
            if($buildDetails.count -eq 0)
            {
                $val = $keyval +" "+0
                Add-Content -Path $resultFilePath -Value $val
            }
           else
           {
                foreach($details in $buildDetails.value)
                {
                    $x = [bool]($details.startTime -as [datetime])
                    $y = [bool]($details.finishTime -as [datetime])
                    if($x -and $y)
                    {
                        $buildRunTime=$details.finishTime- $details.startTime
                    }
                    else
                    {
                        $buildRunTime = [datetime]::Parse($details.finishTime)-[datetime]::Parse($details.startTime)
                    }
                    $totalTime+= [int]$buildRunTime.minutes
                }
                $avgTime = [math]::Round([int] $totalTime/[int] $buildDetails.count,2)
                $val = $keyval + "  "+ $avgTime
                Add-Content -Path $resultFilePath -Value $val
            }
        }
            catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
            }
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}

# Gets average build time for builds specified in a text file under a specific project
function Get-BuildsAverageTime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$filePath,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$serverUrl,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$organization,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$project,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$resultFilePath,
        [switch]$tfs
    )

    $apiUrl = "$serverUrl/$organization"
    if($tfs){
      $headers=Get-HeaderForTFS
    }
    if(!(Test-Path -Path $resultFilePath))
    {
        New-Item -Path $resultFilePath -Type file
    }
    else {
        Remove-Item -Path $resultFilePath
        New-Item -Path $resultFilePath -Type file
    }
    Add-Content -Path $resultFilePath -Value "DefId  BuildName      AverageTime"
    try{
        if($filePath -ne "")
        {
            foreach($line in [System.IO.File]::ReadLines($filePath))
            {
                $defids = get-buildDefnIds -buildName $line -project $project -tfs $tfs
                foreach($defid in $defids){
                    $keyval= [string]$defid +'  '+$line
                    $buildUri="$apiUrl/$project/_apis/build/builds?definitions=$defid&`$top=20&resultFilter=succeeded"
                    $totalTime=0
                    try {
                        $buildDetails = Invoke-RestMethod -Uri $buildUri -Method Get -ContentType $contentType -Headers $headers
                        if($buildDetails.count -eq 0)
                        {
                            $val = $keyval +" "+0
                            Add-Content -Path $resultFilePath -Value $val
                        }
                        else
                        {
                            foreach($details in $buildDetails.value)
                            {
                                $x = [bool]($details.startTime -as [datetime])
                                $y = [bool]($details.finishTime -as [datetime])
                                if($x -and $y)
                                {
                                    $buildRunTime=$details.finishTime- $details.startTime
                                }
                                else
                                {
                                    $buildRunTime = [datetime]::Parse($details.finishTime)-[datetime]::Parse($details.startTime)
                                }
                                $totalTime+= [int]$buildRunTime.minutes
                            }
                            $avgTime = [math]::Round([int] $totalTime/[int] $buildDetails.count,2)
                            $val = $keyval + "  "+ $avgTime
                            Add-Content -Path $resultFilePath -Value $val
                        }
                    }
                    catch {
                    $ErrorMessage = $_.Exception.Message
                    $FailedItem = $_.Exception.ItemName
                    Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
                    }
                }
            }
        }
    }
    catch{
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "Repository Exists Error : " + $ErrorMessage + " iTEM : " + $FailedItem
    }
}


<# Updates the build variables in the build definition. Adds them to build definition if they dont already exists #>
function Update-Variables($project,$buildname,$path,$tfs,$variables)
{
    $buildDefinitionIDs = get-buildDefnIds -project $project -buildName $buildname -path $path -tfs $tfs

    if($tfs)
    {
        $apiVersion = $tfsApiVersion
        $apiUrl = $tfsapiUrl
        $headers=Get-HeaderForTFS
    }

    foreach($buildDefinitionID in $buildDefinitionIDs)
    {
        $uri = "$apiUrl/$project/_apis/build/definitions/$($buildDefinitionID)?api-version=$apiVersion"
        try {
            # check if already exists
            $BuildDefinition = Invoke-RestMethod -Uri $uri -Method Get -ContentType $contentType -Headers $headers

            $BuildDefinition = Update-Vars -BuildDefinition $BuildDefinition -variables $variables

            Add-Comment -buildDefinitionProperties $BuildDefinition -comment "Updated the variables "

            $j = ConvertTo-Json -Depth 50 $BuildDefinition

            $result = Invoke-RestMethod -Uri $uri -Method Put -ContentType $contentType -Body $j -Headers $headers

            Write-Host "$result`r`n"
            }

        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "Repository Exists Error : " + $ErrorMessage
        }
    }
}

function Update-Vars($BuildDefinition,$variables)
{
        foreach ($vars in $variables)
        {
            $varName = $vars.Split("=")[0]
            $varValue = $vars.Split("=")[1]
            $buildDefnName = $BuildDefinition.name

            if($BuildDefinition.variables.PSobject.Properties.name -match $varName)
            {
                Write-Host "Updating the variable $varName with value $varValue for build definition $buildDefnName"
                $BuildDefinition.variables.$varName.value = $varValue
            }
            else {
                Write-Host "The variable $varName doesnt exist.. adding $varname to build definition $buildDefnName with value $varValue"
                $hash = @{
                    value = $varValue
                }

                $Object = New-Object PSObject -Property $hash
                $BuildDefinition.variables | Add-Member -Name $varName -Value $Object -MemberType NoteProperty
            }
        }

        return $BuildDefinition
}

Export-ModuleMember -Function * -Alias * -Variable *
