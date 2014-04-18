forever = require('forever-monitor')
validate = require('json-schema').validate

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

    constructor:(x)->
        @name=x.name
        @binpath=x.binpath
        @binary=x.binname
        @startargs=x.startargs
        @reload=x.reload

        # array of { id: uuid, fproc: foreverinstance }
        @processes=[]

    add: (proc, uuid) ->
        console.log 'uuid id',uuid
        @processes.push
            id: uuid
            fproc: proc


#Manager class ( APIs - to add the service , control(start/stop/restart/reload) the service)
class ServiceManager
    constructor:()->
        @services = []
        console.log "Service Manager constructor called"


    validateServiceData: (data) ->
        result=validate data,schema
        if result.valid is true
            console.log 'valid JSON data'
            return true 
        else
            console.log result
            return false

    getManagedService: (name) ->
        # lookup inside @services
        for i in @services
            if i.name  is  name
                return i 
        #error case
        console.log "managed service object for #{name} is not available in the array"
        return new Error "service not available"

   
    addService: (service)=>
        # validate service JSON object
        return new Error "Invalid input data" unless @validateServiceData service

        #check whether the service already exists. If exists return error
        x= @getManagedService(service.name)
        unless x  instanceof Error
            console.log "service already exists in the array"
            return new Error "Service already exists"

        #create a new service
        ms = new ManagedService service
        @services.push ms if ms


    list: ()->
        console.log 'inside list'
        for i in @services
            console.log i.name
            console.log i.binpath
            console.log i.binary
            console.log i.startargs
            console.log i.reload

    #Check whether the process for the uuid is running already
    getForeverInstance: (ms,uuid) ->
        console.log 'isRunning routine'
        for i in ms.processes
            if i.id is uuid
                console.log "service #{ms.name} for uuid #{uuid} is present in processes array"
                return i.fproc
        console.log "service #{ms.name} for uuid #{uuid} is not present in processes array"
        return new Error "forever Instance not available"

    start: (name, uuid) ->
        console.log "start:", name
        #get ms object
        ms= @getManagedService(name)
        return false if ms instanceof Error

        #get the handler check the service/with uuid isrunning already, if it runs no need to start again.
        fi= @getForeverInstance(ms,uuid)
        return false unless fi instanceof Error
       
        binname =null
        #populate the with absolute path for binary.
        binname = "#{ms.binpath}/#{ms.binary}"
        console.log  "The binary absolute path is",binname

        #make it in forever format [prgname,arg1,arg2...]
        x=[]
        x= ms.startargs
        x.unshift(binname)
        # start the service
        # Todo : forever parameters to be relooked
        console.log x
        fp = forever.start(x, max: 10000, silent: false, spawnWith: customFds: [-1,-1,-1], detached:false )
        # add the forever instance & uuid in ms object
        ms.add fp,uuid
        console.log "service #{name} for uuid #{uuid} successfully started "
        return true

    stop: (name, uuid) ->
        console.log 'stop :',name
        #get the service object
        ms= @getManagedService(name)
        return false if ms instanceof Error
        #get the handler check the service/with uuid isrunning already, if it runs no need to start again.
        fi=@getForeverInstance(ms,uuid)
        return false if fi instanceof Error
        #stop the process
        fi.stop()
        console.log "process stopped"


    restart: (name, uuid) ->
        ms= @getManagedService(name)
        return false if ms instanceof Error
        fi=@getForeverInstance(ms,uuid)
        if fi instanceof Error
            start(name,uuid)
            console.log "service is not running.. hence starting"
            return true
        else
            fi.restart()
            console.log "restareted"
            return true
        
    reload: (name, uuid) ->
        console.log 'reload is called'
        #Todo : to be implemented.

module.exports = new ServiceManager
