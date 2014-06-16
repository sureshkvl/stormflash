EventEmitter = require('events').EventEmitter
os = require 'os'
fs = require 'fs'
async = require 'async'
exec = require('child_process').exec

class StormPackageManager extends EventEmitter
    _defaultInstaller = 'dpkg'
    _defaultPkgMgr = 'apt-get'

    _discoverNpmModules = (callback) ->
        exec "npm ls --json --depth=0", (error, stdout, stderr) =>
            return callback stdout if stdout

    _discoverDebPkgs = (callback) ->
        exec "dpkg -l | tail -n+6", (error, stdout, stderr) =>
            return callback stdout if stdout

    _discoverEnvironment = (callback)->
        switch (process.platform)
            when "linux"
                env =
                    type: os.type()
                    platform: os.platform()
                    arch:   os.arch()
                    nodeVersion: process.version

                fs.readFile "/proc/version", (err, data) =>
                    throw err if err?
                    match = /ubuntu/i.test(data)
                    if match?
                        @installer = 'dpkg'
                        @pkgmgr = 'apt-get'
                    else
                        # For now non ubuntu is redhat
                        @installer = 'rpm'
                        @pkgmgr = 'yum'
                    return callback env
            else
                @log "unsupported platform"
                return new Error "Unsupported Platform " + process.platform

    constructor: (context) ->
        @installer = undefined
        @pkgmgr = undefined
        @env = {}
        @npmPackages = {}
        @debPackages = {}

        if context?
            @repeatInterval = context.repeatInterval
            @log = context.log

        @repeatInterval?= 8000
        @log ?= console.log

        _discoverEnvironment  (env) =>
            @env = env
            throw env if env instanceof Error
            @log 'discovered environment', @env


    monitorDebPkgs: (callback) ->
        # Find installed debain pacakages
        @log "searching for debian packages"
        _discoverDebPkgs (content) =>
            return callback "success"  unless content?
            @analyzeDeb content, 0
            callback "success"

    analyzeDeb: (content, firstime) ->
            if content?
                # Got the list of debain packages in the file
                # they are of the format ii <packagename> <package version> <description>
                contents = content.split(/[ ,]+/).join(',').split('ii')
                for pkg in contents
                    content = pkg.split(',')
                    if content[1]? and content[2]?
                        result =
                            name:content[1]
                            version: content[2]
                            source: "builtin"
                            type: "dpkg"
                        if firstime
                            @debPackages[result.name] = result.version
                        else
                            @emit 'discovered', "deb", result unless @debPackages[content[1]]?
                            @debPackages[result.name] = result.version

    analyzenpm: (content, firstime) ->
        modules = JSON.parse content
        for entry of modules.dependencies
            result =
                name: entry
                version: modules.dependencies[entry].version?="*"
                source: "builtin"
                type: "npm"
            if firstime
                @npmPackages[entry] = result.version
            else
                @emit "discovered", "npm", result unless @npmPackages[entry]?
                @npmPackages[result.name] = result.version

            if typeof modules.dependencies[entry].dependencies is 'object'
                curobject = modules.dependencies[entry].dependencies
                for content of curobject
                    result =
                        name: content
                        version: curobject[content].version?="*"
                        source: 'dependency'
                        type: "npm"
                    if firstime
                        @npmPackages[result.name] = result.version
                    else
                        @emit "discovered", "npm", result unless @npmPackages[result.name]?
                        @npmPackages[result.name] = result.version


    monitorNpmModules: (callback)->
        @log "Searching for NPM modules"


        _discoverNpmModules (stdout) =>
            return callback "success"  unless stdout?
            @analyzenpm stdout, 0
            callback "success"


    monitor: (repeatInterval) ->
        repeatInterval ?= @repeatInterval
        @log "repeat Interval now is ", repeatInterval

        async.whilst(
             ()=>
                true
         ,   (repeat) =>
                async.waterfall [
                    (callback) =>
                       @monitorNpmModules  =>
                           callback()
                   ,(callback) =>
                       @monitorDebPkgs  =>
                           callback()
                ]
                 , (err, result) ->

                setTimeout(repeat, repeatInterval)
         ,   (err)=>
                @log 'monitoring of packages stopped..'
        )



    getCommand: (installer, command, component, filename)  ->
        @log "Building command for #{installer}.#{command}"
        append = component.version
        append = "" if component.version is "*"
        switch "#{installer}.#{command}"
            when "dpkg.check"
                return "dpkg -l | grep -w \"#{component.name} \" | grep -w \"#{append} \""
            when "npm.check"
                return "cd /lib; npm ls 2>/dev/null | grep \"#{component.name}@#{append}\""
            when "npm.install"
                return "npm install #{component.name}@#{component.version}" unless filename
                return "npm install #{filename}"
            when "dpkg.install"
                return "dpkg -i #{filename}"
            when "apt-get.install"
                return "apt-get -y --force-yes install #{filename}"
            when "dpkg.uninstall", "apt-get.uninstall"
                return "dpkg -r #{filename}"
            else
                @log new Error "invalid command #{installer}.#{command} for #{component.name}!"
                return null

    check: (installer, component, callback) ->
        @log "checking if the component '#{component.name}' has already been installed using #{installer}..."

        switch installer
            when "npm:"
                command = @getCommand 'npm', 'check', component
            when "dpkg:", "apt-get:"
                command = @getCommand 'dpkg', 'check', component

            else
                return callback new Error "Unsupported installer #{installer}"

        @execute command, (error) =>
            unless error instanceof Error
                @log "#{component.name} is already installed"
                callback true
            else
                callback error

    execute: (command, callback) ->
    
        exec = require('child_process').exec
        
        cwd = "/"
        env = process.env
        env.LD_LIBRARY_PATH= '/lib:/usr/lib'
        env.PATH= '/bin:/sbin:/usr/bin:/usr/sbin'
        env.NODE_PATH= '/lib/node_modules'
            
        exec "#{command}", {cwd:cwd, env:env}, (error, stdout, stderr) =>
            @log "execution result for #{command} ", error, stdout, stderr
            if error?
                return callback new Error error
            return callback stdout

    install: (pinfo, callback) ->
        return new Error "Invalid parameters" unless pinfo.name? and pinfo.version? and pinfo.source?

        @log "Installing package #{pinfo.name}"

        url = require 'url'
        if pinfo.source?
            parsedurl = url.parse pinfo.source, true
            @log 'the protocol for the package download is ', parsedurl.protocol

        @check parsedurl.protocol, pinfo, (pkg) =>
            unless pkg instanceof Error
                @log "Found the component installed ", pinfo.name
                return callback pinfo
            cmd = undefined
            switch (parsedurl.protocol)
                when 'npm:'
                    if parsedurl.path
                        #XXX assuming http to download the package
                        parsedurl.protocol = "http"
                        filename = url.format(parsedurl)
                        cmd = @getCommand "npm", "install", pinfo, filename
                    else
                        cmd = @getCommand "npm", "install", pinfo
                    pinfo.type = "npm"

                when "dpkg:"
                    return callback new Error "Must specify source" unless pinfo.source?
                    pinfo.type = "dpkg"
                    #XXX assuming http to download the package
                    parsedurl.protocol = "http"
                    webreq = require 'request'
                    fs = require 'fs'
                    filename = "/tmp/#{pinfo.name}.pkg"
                    source = url.format(parsedurl)
                    webreq source,
                        (error, response, body) =>

                            return new Error "unable to download file" if error?
                            if fs.existsSync filename
                                cmd = @getCommand "dpkg", "install", pinfo, filename

                                return callback new Error "Unable to install package install" unless cmd?
                                @execute  cmd, (result) =>
                                    return callback new Error result if result instanceof Error
                                    callback pinfo
                            else
                                return callback new Error "unable to download package"

                    .pipe(fs.createWriteStream(filename))
                    return
                when "apt-get:"
                    pinfo.type = "dpkg"
                    append = ""
                    append = "=#{pinfo.version}" if pinfo.version isnt "*"
                    cmd = @getCommand "apt-get", "install", pinfo, "#{pinfo.name}#{append}"
                else
                    return callback new Error "Unsupported package manager"
            try
                @execute cmd, (result) =>
                    return callback new Error result if result instanceof Error
                    callback pinfo
            catch err
                return callback new Error "Failed to install"

    uninstall: (pinfo, callback) ->
        return callback new Error "Should not uninstall built in package" if pinfo.source is "builtin"?
        url = require 'url'
        if pinfo.source?
            parsedurl = url.parse pinfo.source, true

            return callback new Error "Cannot parse the package source" unless parsedurl?
            switch (parsedurl.protocol)
                when "npm:"
                    cmd = @getCommand "npm", "uninstall", pinfo
                when "dpkg:", "apt-get:"
                    #XXX apt-get remove is dangerous. Ignore installed dependencies
                    cmd = @getCommand "dpkg", "uninstall", pinfo
                else
                    return callback new Error "Unsupported uninstall protocol"

            @execute cmd, (result) =>
                return callback result if result instanceof Error
                return callback "Success"

module.exports = StormPackageManager
