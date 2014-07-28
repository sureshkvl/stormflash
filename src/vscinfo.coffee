request = require('request-json')
stormflashurl = 'http://localhost:5000'

#query the status
client = request.newClient(stormflashurl)
client.get "/status", (err, res, body) =>
	console.log "err" + JSON.stringify err if err?
	#console.log "http response " + res.statusCode if res? and res.statusCode?
	#console.log "body " + JSON.stringify body if body?
	return null if err?
	return null unless res.statusCode == 200
	@status = body
	
	console.log "Activated                 :  " + @status.activated if @status?.activated?
	console.log "Running                   :  " + @status.running   if @status?.running?
	console.log "endianness                :  " + @status.os.endianness  if @status?.os?.endianness?
	console.log "hostname                  :  " + @status.os.hostname if @status?.os?.hostname?
	console.log "platform                  :  " + @status.os.platform if @status?.os?.platform?
	console.log "release                   :  " + @status.os.release if @status?.os?.release?
	console.log "arch                      :  " + @status.os.arch if @status?.os?.arch?
	console.log "uptime                    :  " + @status.os.uptime if @status?.os?.uptime?
	console.log "loadavg                   :  " + @status.os.loadavg if @status?.os?.loadavg?
	console.log "totalmem                  :  " + @status.os.totalmem if @status?.os?.totalmem?
	console.log "freemem                   :  " + @status.os.freemem if @status?.os?.freemem?
	console.log "Interfaces                :  " 
	console.log "wan0                      :  " + @status.os.networkInterfaces.wan0[0].address if @status?.os?.networkInterfaces?.wan0?[0]?.address?
	for pkg in @status.packages
		pkgs = pkgs + " , " + pkg.name
	console.log "packages installed        :  " +  pkgs if pkgs?
	console.log "Services                  :  "
	for service in @status.services
		console.log "Name :                  :  " + service.invocation.name if service?.invocation?.name?
		console.log "Running :               :  " + service.invocation.running if service?.invocation?.running?


