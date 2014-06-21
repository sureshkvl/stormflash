ptrace = require('process-trace')

spawn = require('child_process').spawn
EventEmitter = require('events').EventEmitter

async = require 'async'

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
                result = ptrace.sendsignal pid, 9
                @log "sending signal to process with pid #{pid} with result #{result}"
            else
                @log "failed to detach from the process with pid #{pid}"
                @emit "detachError", err, pid, key

        signalCb = (err, pid, key, signal) =>
            @log "Signal recieved with err #{err} pid #{pid} key #{key} and signal #{signal}"
            if err isnt null and signal is null
                @log "Unexpected error"
                @emit "error", signal, pid, key
            switch signal
                when "exited", "killed" , "stopped"
                    @emit "signal", signal, pid, key

        @dCbPtr = ptrace.getcbptr detachCb
        @sCbPtr = ptrace.getcbptr signalCb

    #----------------------------------------------------------------------------------------
    # New waitpid function to handle different pid check conditions
    #----------------------------------------------------------------------------------------
    #
    # Examples:
    #
    # test=false timeout=1000
    #
    #   this will check for upto 1 second for PID to STOP.  If PID is
    #   not running, it will retun immediately. If PID continues to
    #   run upto 1 second, it will return with err set.
    #
    #   This is useful test to see if process stays running for X
    #   duration and also to see if process actually stops within a
    #   given duration.
    #
    # test=true timeout=1000
    #
    #   this will check for upto 1 second for PID to START.  If PID is
    #   running, it will return immediately.  If PID continues to stay
    #   NOT running for upto 1 second, it will return with err set.
    #
    #   This is useful to test how long it takes for a process to
    #   START. Also, useful to get an indication of load on the system
    #   if spawn event takes a long time to transact.
    #
    waitpid: (pid,opts,callback) ->
        unless pid? and opts? and opts.test?
            callback new Error "must pass in proper options for waitpid!"

        test     = opts.test
        timeout  = opts.timeout  ? 0
        interval = opts.interval ? 100

        counter  = 0
        async.until(
            () ->
                try
                    process.kill pid, 0
                    return test
                catch err
                    return not test
            (wait) ->
                unless timeout is -1
                    throw new Error "timeout reached while waiting on PID" if (counter * interval) > timeout
                counter++;
                setTimeout wait, interval
            (err) -> callback err, (counter * interval)
        )

    setMonitorInterval: (interval) ->
        @monitorInterval = interval

    start: (binary, path, args, options, key) ->
        #Spawn a child . optionally can kill the existing process if any
        options ?= @options
        @log "starting the process #{path}/#{binary} with args ", args, "and options ", options
        child = spawn "#{path}" + "/#{binary}", args, options
        child.unref()
        child.once "error", (err) =>
            @log "Error in starting the process. Reason is ", err
            @emit "error", err, child.pid, key

        ###
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

module.exports = ProcessManager
