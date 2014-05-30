EventEmitter = require('events').EventEmitter
os = require 'os'
fs = require 'fs'
async = require 'async'
exec = require('child_process').exec

class StormPackageManager extends EventEmitter
    _defaultInstaller = 'dpkg'
    _defaultPkgMgr = 'apt-get'

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
                console.log "unsupported platform"
                return new Error "Unsupported Platform " + process.platform

    constructor: (@repeatInterval) ->
        @installer = undefined
        @pkgmgr = undefined
        @env = {}
        @packages = []
        _discoverEnvironment  (env) =>
            @env = env
            throw env if env instanceof Error
            console.log 'discovered environment', @env

        if not @repeatInterval?
            @repeatInterval = 8000


    monitorDebPkgs: (callback) ->
        # Find installed debain pacakages
        console.log "searching for debian packages"
        exec "dpkg -l | tail -n+6", (error, stdout, stderr) =>
            if stdout?
                # Got the list of debain packages in the file
                # they are of the format ii <packagename> <package version> <description>
                contents = stdout.split(/[ ,]+/).join(',').split('ii')
                for pkg in contents
                    content = pkg.split(',')
                    if content[1]? and content[2]?
                        result =
                            name:content[1]
                            version: content[2]
                            source: undefined
                        #console.log 'emitting discovered event'
                        @emit 'discovered', "deb", result
                callback "success"

    monitorNpmModules: (callback)->
        console.log "Searching for NPM modules"
        exec "npm ls --json --depth=0", (error, stdout, stderr) =>
            return callback "success"  unless stdout?
            modules = JSON.parse stdout
            for entry of modules.dependencies
                result =
                    name: entry
                    version: modules.dependencies[entry].version?="*"
                    source: 'builtin'
                @emit "discovered", "npm", result
                if typeof modules.dependencies[entry].dependencies is 'object'
                    curobject = modules.dependencies[entry].dependencies
                    for content of curobject
                        result =
                            name: content
                            version: curobject[content].version?="*"
                            source: 'dependency'
                        @emit "discovered", "npm", result
            callback "success"
             


    monitor: (repeatInterval) ->
        repeatInterval = @repeatInterval unless repeatInterval?

        ###
        emitter = () =>
            setImmediate @monitorDebPkgs, @
            setImmediate @monitorNpmModules, @

        setInterval emitter, repeatInterval

        ###
        async.whilst(
             ()=>
                true
         ,   (repeat) =>
                async.waterfall [
                    (callback) =>
                       @monitorDebPkgs () =>
                           callback()
                   ,(callback) =>
                       @monitorNpmModules () =>
                           callback()
                 ]
                 , (err, result) ->

                setTimeout(repeat, repeatInterval)
         ,   (err)=>
                console.log 'monitoring of packages stopped..'
        )
         


    getCommand: (installer, command, component, filename)  ->
        console.log "Building command for #{installer}.#{command}"
        switch "#{installer}.#{command}"
            when "dpkg.check"
                return "dpkg -l | grep -w \"#{component.name} \" | grep -w \"#{component.version} \""
            when "npm.check"
                return "cd /lib; npm ls 2>/dev/null | grep #{component.name}@#{component.version}"
            when "npm.install"
                return "npm install #{component.name}@#{component.version}" unless filename
                return "npm install #{filename}"
            when "dpkg.install"
                return "dpkg -i #{filename}"
            when "apt-get.install"
                return "apt-get -y install #{filename}"
            when "dpkg.uninstall", "apt-get.uninstall"
                return "dpkg -r #{filename}"
            else
                console.log new Error "invalid command #{installer}.#{command} for #{component.name}!"
                return null

    check: (installer, component, callback) ->
        console.log "checking if the component '#{component.name}' has already been installed using #{installer}..."

        switch installer
            when "npm:"
                command = @getCommand 'npm', 'check', component
            when "dpkg:", "apt-get:"
                command = @getCommand 'dpkg', 'check', component

            else
                return callback new Error "Unsupported installer #{installer}"

        @execute command, (error) =>
            unless error instanceof Error
                console.log "#{component.name} is already installed"
                callback true
            else
                callback error

    execute: (command, callback) ->
        exec = require('child_process').exec
        console.log 'executing the command ', command
        exec "#{command}", (error, stdout, stderr) =>
            if error?
                return callback new Error error
            return callback stdout

    install: (pinfo, callback) ->
        return new Error "Invalid parameters" unless pinfo.name? and pinfo.version? and pinfo.source?
        # dpkg://cpn.intercloud.net:443/path/package.dpkg
        # Proceed with package installationa

        url = require 'url'
        if pinfo.source?
            parsedurl = url.parse pinfo.source, true
            console.log 'the protocol for the package download is ', parsedurl.protocol

        @check parsedurl.protocol, pinfo, (pkg) =>
            unless pkg instanceof Error
                console.log "Found the component installed ", pinfo.name
                return callback pinfo

        switch (parsedurl.protocol)
            when 'npm:'
                if parsedurl.path
                    #XXX assuming http to download the package
                    parsedurl.protocol = "http"
                    filename = url.format(parsedurl)
                    cmd = @getCommand "npm", "install", pinfo, filename
                else
                    cmd = @getCommand "npm", "install", pinfo

            when "dpkg:"
                return callback new Error "Must specify source" unless pinfo.source?
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
                            return callback result if result instanceof Error
                            callback pinfo
                    else
                        return callback new Error "unable to download package"

                .pipe(fs.createWriteStream(filename))
                return
            when "apt-get:"
                cmd = @getCommand "apt-get", "install", pinfo, "#{pinfo.name}=#{pinfo.version}"
            else
                return callback new Error "Unsupported package manager"
        try
            @execute cmd, (result) =>
                return callback result
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

module.exports.StormPackageManager = StormPackageManager
