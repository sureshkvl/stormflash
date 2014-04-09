forever=require('forever-monitor')

class processmgr
	instance = null
	uproxyprocess=null
	openvpnprocess=null
	strongswanprocess=null
	commtouchprocess=null

	@get:()->
		if not @instance?
			instance =  new @
		instance

	startuproxy:()->
		console.log 'processmgr: startuproxy is called'
		if uproxyprocess is null  
			uproxyprocess=forever.start(['/usr/local/bin/universal','--config_file=/home/suresh/uproxy.ini','-L','/var/log/uproxy','&'], max: 1000,silent: true, spawnWith: customFds: [-1,-1,-1],detached:false)
			console.log 'uproxy is started. pid is : ', uproxyprocess.child.pid
		else
			console.log 'uproxyprocess is already running.. hence no need to start'


	stopuproxy:()->
		console.log 'processmgr: stopuproxy is called'
		if uproxyprocess?
			uproxyprocess.stop()
		else
			console.log 'uproxy is not running... hence cannot be stopped'

	restartuproxy:()->
		console.log 'processmgr: restartuproxy is called'
		if uproxyprocess?
			uproxyprocess.restart()
			console.log 'uproxy restarted, pid : ',uproxyprocess.child.pid
		else
			@startuproxy()
			
module.exports= processmgr
