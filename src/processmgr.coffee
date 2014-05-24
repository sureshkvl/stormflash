ptrace = require('node-ptrace')
spawn = require('child_process').spawn
EventEmitter = require('events').EventEmitter


class ProcessManager extends EventEmitter
    _defaultMonitorInterval = 10

    _defaultSpawnOptions =
        customFds: [-1, -1, -1]
        detached: true


    attachCb = (err, pid, cookie, result) ->
        key = cookie.toString() if cookie?
        if err and key isnt undefined
            @emit "attached", result, pid, key
        else
            @emit "attachError", err, pid, key

    detachCb = (err, pid, cookie, result) ->
        key = cookie.toString() if cookie?
        if err and key isnt undefined
            @emit "detached", result, pid, key
        else
            @emit "detachError", err, pid, key

    signalCb = (err, pid, cookie, signal) ->
        key = cookie.toString() if cookie?
        if err and key isnt undefined
            @emit "stopped", "", pid, key
        switch signal
            when "stopped", "killed", "exited"
                @emit "signal", signal, pid, key




    constructor: (@monitorInterval, @options) ->
        unless @monitorInterval?
            @monitorInterval = _defaultMonitorInterval
        unless @options?
            @options = _defaultSpawnOptions
        console.log "Monitor interval is ", @monitorInterval, " options for spawn are ", @options

        #Register the callbacks with ptrace module
        @aCbPtr = ptrace.getcbptr attachCb
        @dCbPtr = ptrace.getcbptr detachCb
        @sCbPtr = ptrace.getcbptr signalCb

    setMonitorInterval: (interval) ->
        @monitorInterval = interval

    start: (binary, path, args, key) ->
        #Spawn a child . optionally can kill the existing process if any
        child = spawn "#{path}" + "/{binary}", args, @options
        child.on "error", (err) =>
            @emit "error", err, pid, key

        child.on "exit", (code, signal) =>
            if code is null
                @emit "signal", signal, child.pid, cookie

        return child.pid

    stop: (pid, key) ->
        #signal the child.
        result = ptrace.sendsignal pid, SIGHUP
        return new Error "Failed to stop the process" if result isnt 1
        return result

    attach: (pid, cookie) ->
        # attach to the process
        buf = new Buffer(cookie)
        ptrace.add pid, buf, @retries, @aCbPtr

    detach: (pid, cookie) ->
        # detach from the process 
        buf = new Buffer(cookie)
        ptrace.detach pid, buf, @retries,  @dCbPtr

    monitor: (pid, cookie) ->
        buf = new Buffer(cookie)
        ptrace.getsignal(pid, buf, @sCbPtr)

                    


module.exports.ProcessManager = ProcessManager
