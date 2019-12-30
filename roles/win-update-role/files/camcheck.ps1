function GetParentItemPath {
    param([string]$path)

    if ($path -match "(\w+\[[a-fA-F0-9\-]+\])(/\w+)?") {
        $Matches.1
    }
}

$initialPreference = $InformationPreference
$InformationPreference = [System.Management.Automation.ActionPreference]::Continue
try {
    $server = env:computername

    if ($null -ne ${MilestonePSTools.Connection}) {
       
    }
    Connect-ManagementServer $server -WarningAction Stop -ErrorAction Stop
    $ms = Get-ManagementServer
    $loginSettings = Get-LoginSettings
    $states = Get-ItemState -CamerasOnly
    $total = $states.Count
    $count = 0
    $results = New-Object System.Collections.ArrayList
    foreach ($record in $states) {
        $count++
        $cam = Get-ConfigurationItem -Path "Camera[$($record.FQID.ObjectId)]"
        $camId = $cam.Properties | Where-Object Key -eq "Id" | Select -First 1 -ExpandProperty Value
        $hw = Get-ConfigurationItem -Path (GetParentItemPath($cam.ParentPath))
        $hwUri = [Uri]($hw.Properties | Where-Object Key -eq "Address" | Select -ExpandProperty Value -First 1)
        $hwId = $hw.Properties | Where-Object Key -eq "Id" | Select -First 1 -ExpandProperty Value
        $rec = Get-ConfigurationItem -Path (GetParentItemPath($hw.ParentPath))
        $recHostName = $rec.Properties | Where-Object Key -eq "HostName" | Select -First 1 -ExpandProperty Value
        $row = [PSCustomObject]@{
            Camera = $cam.DisplayName
            Address = $hwUri
            State = $record.State
            PingSucceeded = "Untested"
            TcpTestSucceeded = "Untested"
            CameraEnabled = $cam.EnableProperty.Enabled
            HardwareEnabled = $hw.EnableProperty.Enabled
            Hardware = $hw.DisplayName
            CameraId = $camId
            HardwareId = $hwId
            Recorder = $rec.DisplayName
            RecorderAddress = $recHostName
            LastImage = "Unknown"
        }
        $info = Get-PlaybackInfo -CameraId $record.FQID.ObjectId -ErrorAction Ignore
        if ($null -ne $info) {
            $row.LastImage = $info.End
        } else {
        }

        $null = $results.Add($row)
    }

    foreach ($record in $results | Group-Object RecorderAddress) {
        $server = $record.Name
        $notRespondingDevices = @($record.Group | Where-Object State -ne "Responding")
        if ($null -eq $notRespondingDevices) { continue }        
        try {
            $session = New-PSSession -ComputerName $server -ErrorAction Stop
            $pingResults = @{}
            foreach ($device in $record.Group | Where-Object State -ne "Responding") {
                if ($null -eq $pingResults.($device.Address)) {
                    $pingResults.($device.Address) = Invoke-Command -Session $session -ScriptBlock {
                        Test-NetConnection -ComputerName ($using:device).Address.Host -Port ($using:device).Address.Port -InformationLevel Detailed -WarningAction SilentlyContinue
                    }
                }
                
                $device.TcpTestSucceeded = $pingResults.($device.Address).TcpTestSucceeded
                if (-not $device.TcpTestSucceeded) {
                    $device.PingSucceeded = $pingResults.($device.Address).PingSucceeded
                }
            }
        } catch {
            Write-Error $_.Exception.Message
        } finally {
            $session | Remove-PSSession
        }
    }

    $notResponding = $results | Where-Object State -ne "Responding"
    if ($null -ne $notResponding) {
        Write-Warning "The folling devices are not responding in Milestone"
        $notResponding | Format-Table Camera, Address, State, TcpTestSucceeded, PingSucceeded, LastImage
    } else {
        Write-Information "All cameras were reported as Responding in Milestone"
    }

    Write-Information 'Full details available in $results'
} catch {
    throw
} finally {
    Disconnect-ManagementServer
    $InformationPreference = $initialPreference
}