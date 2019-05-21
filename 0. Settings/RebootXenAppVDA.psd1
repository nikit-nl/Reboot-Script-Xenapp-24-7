@{
	DeliveryGroup = "Production Desktop"
	MaintenanceTime = 3600
	Tempdir = ".\Prod_temp"
	EvenDays = "Sunday","Tuesday","Thursday"
    OddDays = "Monday","Wednesday","Friday"
    ExcludeDays = "Saturday"
	
	Throttle = "10"
	RebootCheckTimer = "300"
	LoopTimer = 8
	
	Domain = "IKNL\"
	DNS = ".iknl.local"

	Notification = @{
		1 = 60
		2 = 30
		3 = 15
		4 = 5
	}

	Sleep = @{
		Fase_1 = 30
		Fase_2 = 15
		Fase_3 = 5
	}

	Inbox = @{
		1 = ".\1. Reboot Servers\"
		2 = ".\2. Ping Test\"
		3 = ".\3. Registered Test\"
		9 = ".\9. Done\"
	}
	
	UserWarningMessage= @{
		Part1 = "Beste IKNL Medewerker, De server waar u op werkt zal in"
    	Part2 = "minuten van een herstart voorzien worden. Om geen werk te verliezen, sla alstublieft uw werk op en meld uw sessie af. Vriendelijke groet, Pink Elephant"
	}
	
	SMTPMail = @{
		SMTPServer = "relay.iknl.nl"
		SMTPPort = "10025"
		EmailTo = "nik.heyligers@pinkelephant.nl"
		EmailFrom = "citrixadmin@iknl.nl"
		#EmailCC = "nik.heyligers@pinkelephant.nl"
		EmailSubject = "IKNL - Daily Reboot Schedule status Report"
    }
}
