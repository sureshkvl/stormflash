#ptrace = require('node-ptrace')
ptrace = require('process-trace')

spawn = require('child_process').spawn
EventEmitter = require('events').EventEmitter


class ProcessManager extends EventEmitter
    _defaultMonitorInterval = 10

    _defaultSpawnOptions =
        customFds: [-1, -1, -1]
        detached: true




    constructor: (@monitorInterval, @retries, @options) ->
        super
        unless @monitorInterval?
            @monitorInterval = _defaultMonitorInterval
        unless @options?
            @options = _defaultSpawnOptions
        console.log "Monitor interval is ", @monitorInterval, " options for spawn are ", @options

        #Register the callbacks with ptrace module
        if @retries is undefined
            @retries = 5

        detachCb = (err, pid, key, result) =>
            if err and key isnt undefined
                console.log "detached from the process with pid #{pid}"
                @emit "detached", result, pid, key
                result = ptrace.sendsignal pid, 2
                console.log "sending signal to process with pid #{pid} with result #{result}"
            else
                console.log "failed to detach from the process with pid #{pid}"
                @emit "detachError", err, pid, key

        signalCb = (err, pid, key, signal) =>
            console.log "Signal recieved with err #{err} pid #{pid} key #{key} and signal #{signal}"
            if err isnt null and signal is null
                console.log "Unexpected error"
                @emit "stopped", signal, pid, key
            switch signal
                when "exited", "killed" , "stopped"
                    @emit "signal", signal, pid, key

        @dCbPtr = ptrace.getcbptr detachCb
        @sCbPtr = ptrace.getcbptr signalCb


    setMonitorInterval: (interval) ->
        @monitorInterval = interval

    start: (binary, path, args, key) ->
        #Spawn a child . optionally can kill the existing process if any
        console.log "starting the process #{path}/#{binary} with args ", args, "and options ", @options
        child = spawn "#{path}" + "/#{binary}", args, @options
        child.unref()
        ###
        child.on "error", (err) =>
            console.log "Error in starting the process. Reason is ", err
            @emit "error", err, child.pid, key

        child.on "exit", (code, signal) =>
            console.log "Process Exit. Reason is ", code, signal
            if code isnt 0
                @emit "signal", "stopped" , child.pid,key
            else
                ptrace.sendsignal child.pid, 1
        ###
        console.log "Process started with pid #{child.pid}"
        return child.pid

    stop: (pid, key) ->
        #signal the child.
        @detach pid, key
        return

    attach: (pid, key) ->
        attachCb = (err, pid, key, result) =>
            console.log "type of result is ", typeof result
            console.log "Response to attach ", err, pid, key, result
            if err is null
                @emit "attached", result, pid, key
            else
                @emit "attachError", err, pid, key

        @aCbPtr = ptrace.getcbptr attachCb
        # attach to the process
        ptrace.add pid, key , @retries, @aCbPtr

    detach: (pid, key) ->
        # detach from the process 
        ptrace.detach pid, key, @retries,  @dCbPtr

    monitor: (pid, key) ->
        ptrace.getsignal.async pid, key, @sCbPtr, (result) ->


                    


module.exports.ProcessManager = ProcessManager
