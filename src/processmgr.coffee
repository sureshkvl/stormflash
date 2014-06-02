ptrace = require('process-trace')

spawn = require('child_process').spawn
EventEmitter = require('events').EventEmitter


class ProcessManager extends EventEmitter
    _defaultMonitorInterval = 10

    _defaultSpawnOptions =
        customFds: [-1, -1, -1]
        detached: true




    constructor: (context) ->
        super
        if context?
            @monitorInterval = context.monitorInterval
            @retries = context.retries
            @options = context.options
            @log = context.log
       
        @monitorInterval ?= _defaultMonitorInterval
        @options ?= _defaultSpawnOptions
        @log ?= console.log

        @log "Monitor interval is ", @monitorInterval, " options for spawn are ", @options

        #Register the callbacks with ptrace module
        unless @retries?
            @retries = 5


        detachCb = (err, pid, key, result) =>
            if err and key isnt undefined
                @log "detached from the process with pid #{pid}"
                @emit "detached", result, pid, key
                result = ptrace.sendsignal pid, 2
                @log "sending signal to process with pid #{pid} with result #{result}"
            else
                @log "failed to detach from the process with pid #{pid}"
                @emit "detachError", err, pid, key

        signalCb = (err, pid, key, signal) =>
            @log "Signal recieved with err #{err} pid #{pid} key #{key} and signal #{signal}"
            if err isnt null and signal is null
                @log "Unexpected error"
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
        @log "starting the process #{path}/#{binary} with args ", args, "and options ", @options
        child = spawn "#{path}" + "/#{binary}", args, @options
        child.unref()
        ###
        child.on "error", (err) =>
            @log "Error in starting the process. Reason is ", err
            @emit "error", err, child.pid, key

        child.on "exit", (code, signal) =>
            @log "Process Exit. Reason is ", code, signal
            if code isnt 0
                @emit "signal", "stopped" , child.pid,key
            else
                ptrace.sendsignal child.pid, 1
        ###
        @log "Process started with pid #{child.pid}"
        return child.pid

    stop: (pid, key) ->
        #signal the child.
        @detach pid, key
        return

    attach: (pid, key) ->
        attachCb = (err, pid, key, result) =>
            @log "type of result is ", typeof result
            @log "Response to attach ", err, pid, key, result
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
        getsignal = () =>
            ptrace.getsignal.async pid, key, @sCbPtr, () ->
        setTimeout getsignal, @monitorInterval




                    


module.exports.ProcessManager = ProcessManager
