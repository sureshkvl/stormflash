ptrace = require('process-trace')

spawn = require('child_process').spawn
EventEmitter = require('events').EventEmitter
async = require('async')


class ProcessManager extends EventEmitter
    _defaultMonitorInterval = 5

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
            @log "Entering detach callback for the process with pid #{pid}, key #{key}, Error : ", err
            if err is null and key isnt undefined
                @log "detached from the process with pid #{pid}"
                @emit "detached", result, pid, key
                @log "sending signal to process with pid #{pid} with result #{result}"
            else
                @log "failed to detach from the process with pid #{pid}"
                @emit "detachError", err, pid, key

        signalCb = (err, pid, key, signal, signum) =>
            @log "Signal recieved with err #{err} pid #{pid} key #{key} and signal #{signal}"
            if err isnt null and signal is null
                @log "Unexpected error"
                @emit "error", signal, pid, key
            switch signal
                when "exited", "killed" , "stopped"
                    @emit "signal", signal, signum, pid, key

        @dCbPtr = ptrace.getcbptr detachCb
        @sCbPtr = ptrace.getcbptr signalCb


    setMonitorInterval: (interval) ->
        @monitorInterval = interval


    mapSignals: (signal) ->
        @log "Signal: ", signal
        signum = ''
        switch signal
            when "SIGHUP"
                signum = 1 
            when "SIGINT"
                signum = 2
            when "SIGQUIT"
                signum = 3
            when "SIGILL"
                signum = 4
            when "SIGTRAP"
                signum = 5
            when "SIGABRT"
                signum = 6
            when "SIGBUS"
                signum = 7 
            when "SIGFPE"
                signum = 8
            when "SIGKILL"
                signum = 9 	
            when "SIGUSR1"
                signum = 10 
            when "SIGSEGV"
                signum = 11 	
            when "SIGUSR2"
                signum = 12 	
            when "SIGPIPE"
                signum = 13 	
            when "SIGALRM"
                signum = 14 	
            when "SIGTERM"
                signum = 15 
            when "SIGSTKFLT"
                signum = 16 	
            when "SIGCHLD"
                signum = 17 	
            when "SIGCONT"
                signum = 18 	
            when "SIGSTOP"
                signum = 19 	
            when "SIGTSTP"
                signum = 20 	
            when "SIGTTIN"
                signum = 21 	
            when "SIGTTOU"
                signum = 22 	
            when "SIGURG"
                signum = 23 	
            when "SIGXCPU"
                signum = 24 	
            when "SIGXFSZ"
                signum = 25 
            when "SIGVTALRM"
                signum = 26	
            when "SIGPROF"
                signum = 27 	
            when "SIGWINCH"
                signum = 28 
            when "SIGIO"
                signum = 29 	
            when "SIGPWR"
                signum = 30 
            when "SIGSYS"
                signum = 31 
            else
                signum = -1
        return signum


    start: (binary, path, args, options, key) ->
        #Spawn a child . optionally can kill the existing process if any
        options ?= @options
        @log "starting the process #{path}/#{binary} with args ", args, "and options ", options
        child = spawn "#{path}" + "/#{binary}", args, options
        child.unref()
        child.on "error", (err) =>
            @log "Error in starting the process. Reason is ", err
            @emit "error", err, child.pid, key

        child.on "exit", (code, signal) =>
            signum = ''
            @log "Process Exit. Reason is ", code, signal
            @log "going to call mapSignals"
            signum = @mapSignals signal
            @log "SISISISIS. signal details ", signal, signum
            switch signum
                when 11,13
                    @log "Emitting signals with #{signum}"
                    @emit "signal", "stopped", signum, child.pid, key
                
        @log "Process started with pid #{child.pid}"
        return child.pid

    stop: (signum, pid, key) ->
        #signal the child.
        @detach signum, pid, key
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

    detach: (signum, pid, key) ->
        @log "inside detach", pid
    
        # Handle 'detach' event here
        @once 'detached', (result, key, pid) =>
            ptrace.sendsignal pid, signum
            
        # detach from the process
        ptrace.detach pid, key, @retries,  @dCbPtr

    monitor: (pid, key) ->
        getsignal = () =>
            ptrace.getsignal.async pid, key, @sCbPtr, () ->
        setTimeout getsignal, @monitorInterval

module.exports = ProcessManager
