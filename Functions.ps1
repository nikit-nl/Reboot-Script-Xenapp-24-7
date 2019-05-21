#Just a mokup file for functions

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

    $InboxReboot = $settings.Inbox.1
    $InboxPing = $settings.Inbox.2
    $InboxState = $settings.Inbox.3
    $InboxDone = $settings.Inbox.9


    function IsOnline( [String] $server )
    {

        $IsOnline = Test-Connection -ComputerName $server -Count 1 -Quiet
        return $IsOnline
    }

    Function Count-Servers ( [string] $inbox )
        {
            $count = Get-ChildItem -path $inbox -filter "*.txt" | Measure-Object | %{$_.Count}
            return $Count
        }