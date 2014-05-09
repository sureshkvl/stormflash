forever = require('forever-monitor')
validate = require('json-schema').validate
util = require('util')
fs = require('fs')

schema =
    name : "service"
    type : "object"
    required: true
    properties:
         name : { type: "string", "required": true }
         binpath : { type: "string", "required": true }
         binname : { type: "string", "required": true }
         startargs:
                type : "array"
                required : true
                items :
                    type : "string"
                    required: true
                 

#service =
#       uuid : 'uuid'
#	name : 'uproxy'
#	binpath: '/usr/sbin'
#	binary:  'universal'
#	start-args : ['-c','&']
#	reload : yes

#Managed Service class holds the information of the services (the service JSON structure, forever object handler )
class ManagedService

    constructor:(config)->
        @name = config.name
        @binpath = config.binpath
        @binary = config.binname
        @startargs = config.startargs
        @reload = config.reload

        # array of { id: uuid, fproc: foreverinstance }
        @processes = []

    add: (proc, uuid) ->
        util.log 'uuid id' + uuid
        @processes.push
            id: uuid
            fproc: proc


#Manager class ( APIs - to add the service , control(start/stop/restart/reload) the service)
class ServiceManager
    constructor:()->
        @services = []
        util.log "Service Manager constructor called"


    validateServiceData: (data) ->
        result = validate data,schema
        if result.valid is true
            util.log 'valid JSON data'
            return true 
        else
            util.log result
            return false

    getManagedService: (name) ->
        # lookup inside @services
        for service in @services
            if service.name  is  name
                return service 
        #error case
        util.log "managed service object for #{name} is not available in the array"
        return new Error "service not available"

   
    addService: (service)=>
        # validate service JSON object
        return new Error "Invalid input data" unless @validateServiceData service

        #check whether the service already exists. If exists return error
        instance = @getManagedService(service.name)
        unless instance  instanceof Error
            util.log "service already exists in the array"
            return new Error "Service already exists"

        #create a new service
        ms = new ManagedService service
        @services.push ms if ms


    list: ()->
        util.log 'inside list'
        for service in @services
            util.log service.name
            util.log service.binpath
            util.log service.binary
            util.log service.startargs
            util.log service.reload

    #Check whether the process for the uuid is running already
    getForeverInstance: (ms,uuid) ->
        util.log 'isRunning routine'
        for instance in ms.processes
            if instance.id is uuid
                util.log "service #{ms.name} for uuid #{uuid} is present in processes array"
                return instance.fproc
        util.log "service #{ms.name} for uuid #{uuid} is not present in processes array"
        return new Error "forever Instance not available"

    start: (name, uuid,callback) ->
        util.log "start:" + name
        #get ms object
        ms = @getManagedService(name)
        return false if ms instanceof Error

        #get the handler check the service/with uuid isrunning already, if it runs no need to start again.
        fi = @getForeverInstance(ms,uuid)
        return false unless fi instanceof Error
    
        binname = null
        #populate the with absolute path for binary.
        binname = "#{ms.binpath}/#{ms.binary}"
        util.log  "uThe binary absolute path is" + binname

        #check whether the binary exists in the absolute path  - Error case
        isexists = fs.existsSync(binname)
        util.log "output of is existsin?" + isexists
        unless isexists
            util.log "The binary is not present in the system, result" 
            return false

        #make it in forever format [prgname,arg1,arg2...]
        args = []
        args = ms.startargs
        args.unshift(binname)
        # start the service
        util.log args
        fp = forever.start(args, max: 10000, silent: false, spawnWith: customFds: [-1,-1,-1], detached:false )
        # add the forever instance & uuid in ms object
        #ms.add fp,uuid
        fp.on 'error',(err)=>
            util.log "service returned the error." + err
            callback(false)
        fp.on 'exit', (code)=>
            util.log "program exited.. " + code
            callback(false)

        fp.on 'start',(data)=>
            util.log "service #{name} for uuid #{uuid} successfully started "
            ms.add fp,uuid
            callback(true)


    stop: (name, uuid) ->
        util.log 'stop :'+ name
        #get the service object
        ms = @getManagedService(name)
        return false if ms instanceof Error
        #get the handler check the service/with uuid isrunning already, if it runs no need to start again.
        fi = @getForeverInstance(ms,uuid)
        return false if fi instanceof Error
        #stop the process
        fi.stop()
        util.log "process stopped"


    restart: (name, uuid,callback) ->
        ms = @getManagedService(name)
        return false if ms instanceof Error
        fi = @getForeverInstance(ms,uuid)
        if fi instanceof Error
            start name,uuid,(result) =>
                util.log "service is not running.. hence starting"
                callback(result)
            #return true
        else
            fi.restart()
            util.log "restareted"
            return true
        
    reload: (name, uuid) ->
        util.log 'reload is called'
        #Todo : to be implemented.

module.exports = ServiceManager
