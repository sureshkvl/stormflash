forever = require('forever-monitor')

class ManagedService

    @name = ''
    # array of { id: uuid, process: foreverinstance }
    @processes = []

    add: (proc, id) ->
        @processes.push
            id: id
            process: proc

class ServiceManager
	instance = null
	uproxyprocess=null
	openvpnprocess=null
	strongswanprocess=null
	commtouchprocess=null

    @services = []

	# @get:()->
	# 	if not @instance?
	# 		instance =  new @
	# 	instance
    add: (service) ->
        # validate service JSON object
        #
        # check if service.name already inside?
        ms = new ManagedService service
        @services.push ms if ms

    get: (name) ->
        # lookup inside @services
        return someservice

    list: ->
        # list of all ManagedService objects

    start: (name, uuid) ->
        # lookup the service object

        fproc = forever.start([ms.prog,ms.args,...
        ms.add fproc, uuid

    stop: (name, uuid) ->

    restart: (name, uuid) ->

    reload: (name, uuid) ->


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

module.exports = processmgr
