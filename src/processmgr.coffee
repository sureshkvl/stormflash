ptrace = require('node-ptrace')
EventEmitter = require('events').EventEmitter


class ProcessManager extends EventEmitter
    _defaultMonitorInterval = 10

    _defaultSpawnOptions =
        customFds: [-1, -1, -1]
        detached: true


    attachCb = (err, pid, cookie, result) ->
        if err is null
            @emit "attached", result, pid, cookie
            @pids.push pid
        else
            @emit "attachError", err, pid, cookie

    detachCb = (err, pid, cookie, result) ->
        if err is null
            @pids.remove pid
            @emit "detached", result, pid, cookie
        else
            @emit "detachError", err, pid, cookie

    signalCb = (err, pid, cookie, signal) ->
        switch signal
            when "stopped", "killed", "exited"
                @emit "signal", signal, pid, cookie



    constructor: (@monitorInterval, @options) ->
        @pids = []
        if @monitorInterval is null
            @monitorInterval = _defaultMonitorInterval
        if @options is null
            @options = _defaultSpawnOptions

        #Register the callbacks with ptrace module
        aCbPtr = ptrace.getcbptr attachCb
        dCbPtr = ptrace.getcbptr detachCb
        sCbPtr = ptrace.getcbptr signalCb

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

        @emit "started", key, child.pid if child.pid?

    stop: (pid, key) ->
        #signal the child. Remove from list of pids
        result = ptrace.sendsignal pid, SIGHUP
        if result is true
            pids.remove pid
            @emit "stopped", "graceful", key, pid

    attach: (pid) ->
        # add to the list of pids and attach to the process
        ptrace.add pid, @retries, cookie, aCbPtr

    detach: (pid) ->
        # detach from the process and delete from the pids list
        ptrace.detach pid, @retries, cookie,  dCbPtr

    monitor: (pid, key) ->
        ptrace.getsignal(pid, cookie, sCbPtr)

                    


module.exports.ProcessManager = ProcessManager
