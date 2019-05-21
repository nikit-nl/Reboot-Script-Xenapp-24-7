cls
Write-Host 'Push location to script dir'
Push-Location $PSScriptRoot
Write-Host "Current directory: $(Get-Location)"


##############################################################################
#
# Functions
#
##############################################################################

    function Write-Log
    {
        [CmdletBinding()]
        Param
        (
            [Parameter(Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [Alias("LogContent")]
            [string]$Message,

            [Parameter(Mandatory=$false)]
            [Alias('LogPath')]
            [string]$Path='.\Logs\RebootLog_' + $logdate + '.log',
            
            [Parameter(Mandatory=$false)]
            [ValidateSet("Error","Warn","Info")]
            [string]$Level="Info",
            
            [Parameter(Mandatory=$false)]
            [switch]$NoClobber
        )

        Begin
            {
                # Set VerbosePreference to Continue so that verbose messages are displayed.
                $VerbosePreference = 'Continue'
            }
        Process
            {
                # If the file already exists and NoClobber was specified, do not write to the log.
                if ((Test-Path $Path) -AND $NoClobber) {
                    Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
                    Return
                    }

                # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
                elseif (!(Test-Path $Path)) 
                    {
                        Write-Verbose "Creating $Path."
                        $NewLogFile = New-Item $Path -Force -ItemType File
                    }

                else 
                    {
                        # Nothing to see here yet.
                    }

                # Format Date for our Log File
                $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                # Write message to error, warning, or verbose pipeline and specify $LevelText
                switch ($Level) 
                    {
                        'Error' {
                            Write-Error $Message
                            $LevelText = 'ERROR:'
                            }
                        'Warn' {
                            Write-Warning $Message
                            $LevelText = 'WARN:'
                            }
                        'Info' {
                            Write-Verbose $Message
                            $LevelText = 'INFO:'
                            }
                    }
                
                # Write log entry to $Path
                "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
            }
        End
        {
        }
    }

    function IsOnline( [String] $server )
        {

            $IsOnline = Test-Connection -ComputerName $server -Count 1 -Quiet
            return $IsOnline
        }

    function IsRegistered( [String] $server)
        {
            $ServerInfo = Get-BrokerDesktop -Filter {DNSName -eq $server}
            $ServerState = $ServerInfo.RegistrationState
            

            If($ServerState -eq "Registered")
                {
                    $RegisteredState = $True
                }
            else 
                {
                    $RegisteredState = $False
                }
            return $RegisteredState
        }

    function LoadCitrixCmdlet
        {
            $CitrixCmdlets = Get-Command -Module Citrix.Broker.Admin.V2
            $CitrixCmdletsCount = $CitrixCmdlets.count
            If($CitrixCmdletsCount -gt "50")   
                {
                    Write-log -Level Info -Message "Citrix Cmdlets already Loaded"
                }
            else 
                {
                    Write-Log -Level Warn -Message "Citrix Cmdlets not loaded"
                    Write-Log -Level Warn -Message "Loading Cmdlets ...."
                    asnp Citrix* -ErrorVariable ErrorLoading
                    If ($ErrorLoading)
                        {
                            Write-Log -Level Error -Message "No Citrix Cmdlets found, stopping script"
                            Exit
                        }
                }
        }

    Function Sent-Message
        {
            param( [string]$VDA, [string]$Time)

                $Sessions = Get-BrokerSession -Filter {(DnsName -like $VDADNs)}
                
                foreach($session in $Sessions)
                    {
                        $SessionID = $session.Uid
                        Send-BrokerSessionMessage -InputObject @($SessionID) -MessageStyle "Exclamation" -Text "$UserWarningMessagePart1 $Time $UserWarningMessagePart2" -Title "Pink Elephant"
                    }
    
        }
 
    Function Count-Servers ( [string] $inbox )
        {
            $count = Get-ChildItem -path $inbox -filter "*.txt" | Measure-Object | %{$_.Count}
            return $Count
        }

    Function Get-Servers ( [string] $inbox )
        {
            $Servers = Get-ChildItem -path $inbox -filter "*.txt" | Select-object BaseName, Name
            return $Servers
        }

##############################################################################
#
# Loading Settings file
#
##############################################################################


    $SettingsPath = ".\0. Settings\RebootXenAppVDA.psd1"
    Write-Log -Level Info -Message "Path to settings file is: $SettingsPath"
    # Check if settings file exists. Else stop Script
    $SettingsPathCheck = Test-Path $SettingsPath
    If($SettingsPathCheck -eq $false)
        {
            Write-Log -Level Error -Message "Settings file does not exist. Stopping Script"
            Exit	# STOPPING MOMENT!
        }

    # Loading settings file based on swith			
    $Settings = Import-PowerShellDataFile -Path $SettingsPath
    Write-Log -Level Info -Message "Settings Loaded for $mode"

    
##############################################################################
#
# Define Infrastructure Dependent Variables
#
##############################################################################

    $DeliveryGroup = $settings.DeliveryGroup
    $EnableMaintenanceTime = $settings.MaintenanceTime

    $Tempdir = $settings.Tempdir

    $EvenDays = $settings.EvenDays
    $OddDays = $settings.OddDays
    $ExcludeDays = $settings.ExcludeDays
    
    $Notification_1 = $settings.Notification.1
    $Notification_2 = $settings.Notification.2
    $Notification_3 = $settings.Notification.3
    $Notification_4 = $settings.Notification.4

    $UserWarningMessagePart1 = $settings.UserWarningMessage.Part1
    $UserWarningMessagePart2 = $settings.UserWarningMessage.Part2

    $InboxReboot = $settings.Inbox.1
    $InboxPing = $settings.Inbox.2
    $InboxState = $settings.Inbox.3
    $InboxDone = $settings.Inbox.9

    $Domain = $settings.domain
	$DNSSuffix = $settings.DNS
    
    $Sleep_Fase_1 = $settings.Sleep.Fase_1
    $Sleep_Fase_2 = $settings.Sleep.Fase_2
    $Sleep_Fase_3 = $settings.Sleep.Fase_3

    $Throttle = $settings.Throttle
    $RebootCheckTimers = $settings.RebootCheckTimer
    $LoopTimer = $settings.LoopTimer

##############################################################################
#
# Define Script Variables
#
##############################################################################

    $ScriptStart = Get-Date
    $Date = Get-Date -format yyyyMMdd
    $DayofWeek = (get-date).dayofweek


# Clean-up before start

    # Remove Server.txt files in the process folder


# Determine based on the Day of the week even or odd servers are booted
##############################################################################
    If ($EvenDays -contains $DayofWeek)
        {
            $Reboot="Even"
            Log-Write -Level Info -Message "Day of the week is $DayofWeek, even servers need to be rebooted"
        }
    If ($OddDays -contains $DayofWeek)
        {
            $Reboot="Odd"
            Log-Write -Level Info -Message "Day of the week is $DayofWeek, odd servers need to be rebooted"
        }
    If ($ExcludeDays -contains $DayofWeek)
        {
            Log-Write -Level Info -Message "Day of the week is $DayofWeek, no servers need to be rebooted"
            Log-Write -Level Info -Message "Script ended"
            Exit
        }

    $VDAs = Get-BrokerMachine -DesktopGroupName "$DeliveryGroup" | Where-Object {($_.InMaintenanceMode -ne "True") -And ($_.RegistrationState -eq "Registered")} | select MachineName

    foreach ($VDA in $VDAs)
        { 
            $VdaName = $VDA.MachineName
            $DeviceName = $VdaName.replace('IKNL\',"")
            
            $DeviceLastNumber = [int]"$(($DeviceName)[-1])"
            
#dit nog aanpassen####
            $filename = ".\$DeviceName.txt"

            If([bool]!($DeviceLastNumber%2))
                {
                    $DeviceNumber="Even"
                }
            else
                {
                    $DeviceNumber="Odd"
                }
        
            If($Reboot -eq "Even" -And $DeviceNumber -eq "Even")
                {
                    New-Item $filename
                    Write-Host "$DeviceName is Even and added to the list of servers to reboot"
                }                  
            If($Reboot -eq "Odd" -And $DeviceNumber -eq "Odd")
                {
                    New-Item $filename
                    Write-Host "$DeviceName is Odd and added to the list of servers to reboot"
                }    
            $DeviceName=$null
        }

# Count number of files in first folder if 0 then stop script
##############################################################################
$Count = Count-Servers -inbox $InboxReboot
If( $Count -eq "0")
    {
        Write-log -Level Info -Message "No machines are added to list to reboot. Script will quit."
        Write-log -Level Info -Message "Script ended on $EndScript"
        exit
    }             


# Retrieving Servers from folder
##############################################################################
$VDAs = Get-Servers -inbox $InboxReboot

# Set servers in Maint modus
##############################################################################
foreach($vda in $Servers)
    {
        $FullName = "IKNL\" + $vda.BaseName
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
      
        Write-Log -Level Info -Message "Processing Server $ServerName"
        Write-Log -Level Info -Message "Putting $Servername in Maintenance Mode"
          
        Set-BrokerMachineMaintenanceMode -InputObject $FullName -MaintenanceMode $True
            
        Write-Log -Level Info -Message "$Servername set in Maintenance Mode"
    }

# Notify users 60
##############################################################################
Write-log -Level Info -Message "Starting notifing users, $Notification_1 Minutes before reboot "
foreach($vda in $Servers)
    {
        $FullName = $vda.BaseName + $DNSSuffix 
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
      
        Write-Log -Level Info -Message "Sending notification to users on $ServerName"
        Sent-Message -VDA $FullName -Time $Notification_1
    }    

Write-Log -Level Info -Message "Going to sleep for $Sleep_Fase_1"
    Start-Sleep -Seconds $Sleep_Fase_1
Write-log -Level Info -Message "I Have awoken! Starting Fase 2"

# Notify users 30
##############################################################################
Write-log -Level Info -Message "Starting notifing users, $Notification_2 Minutes before reboot "
foreach($vda in $Servers)
    {
        $FullName = $vda.BaseName + $DNSSuffix 
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
      
        Write-Log -Level Info -Message "Sending notification to users on $ServerName"
        Sent-Message -VDA $FullName -Time $Notification_2
    }    

Write-Log -Level Info -Message "Going to sleep for $Sleep_Fase_2"
    Start-Sleep -Seconds $Sleep_Fase_2
Write-log -Level Info -Message "I Have awoken! Starting Fase 3"

# Notify users 15
##############################################################################
Write-log -Level Info -Message "Starting notifing users, $Notification_3 Minutes before reboot "
foreach($vda in $Servers)
    {
        $FullName = $vda.BaseName + $DNSSuffix 
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
      
        Write-Log -Level Info -Message "Sending notification to users on $ServerName"
        Sent-Message -VDA $FullName -Time $Notification_3
    }    

Write-Log -Level Info -Message "Going to sleep for $Sleep_Fase_2"
    Start-Sleep -Seconds $Sleep_Fase_2
Write-log -Level Info -Message "I Have awoken! Starting Fase 3"


# Notify users 5
##############################################################################
Write-log -Level Info -Message "Starting notifing users, $Notification_4 Minutes before reboot "
foreach($vda in $Servers)
    {
        $FullName = $vda.BaseName + $DNSSuffix 
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
      
        Write-Log -Level Info -Message "Sending notification to users on $ServerName"
        Sent-Message -VDA $FullName -Time $Notification_4
    }    

Write-Log -Level Info -Message "Going to sleep for $Sleep_Fase_3"
    Start-Sleep -Seconds $Sleep_Fase_3
Write-log -Level Info -Message "I Have awoken! Starting Reboot Cycle"

# Restarting Servers
##############################################################################
foreach($vda in $servers)
    {
        $ServerName = $vda.BaseName
        $VDAFile = $vda.Name
        
        Write-Log -Level Info -Message "Sending Restart command to $Servername"
        #Restart-Computer -ComputerName $ServerName -Force
        Write-Log -Level Info -Message "Restart command Sent $Servername"
        Move-Item -Path $InboxReboot -Destination $InboxPing
        Start-Sleep -Seconds $Throttle
    }

$loopCounter = 0
do 
    { 
        Write-Host "Counter is $loopCounter" 
        $VDAs = Get-Servers -inbox $InboxReboot
        
        foreach($vda in $VDAs)
            {
                $FullName = $Domain + $vda.BaseName
                $ServerName = $vda.BaseName
                $VDAFile = $vda.Name
                Write-Host "Ping $Servername"
                $PingStatus = IsOnline -server $ServerName
        
                If($pingStatus -eq "True")
                    {
                        Move-Item -path "$Inbox.1$VDAFile" -Destination '.\2. Ping Test'
                    }
            }
        
        Start-Sleep -Seconds $RebootCheckTimer
        $PingNumber = Count-Servers -inbox '.\1. Reboot Servers'
        $loopCounter++

    } 
while (($PingNumber -gt 0) -and ($loopCounter -lt $LoopTimer))

