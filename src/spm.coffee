EventEmitter = require('events').EventEmitter
os = require 'os'
fs = require 'fs'

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


    constructor: ->
        @installer = undefined
        @pkgmgr = undefined
        @env = {}
        _discoverEnvironment  (env) =>
            @env = env
            throw env if env instanceof Error
            console.log 'discovered environment', @env


    monitor: ->
        @log "hello"


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
                return "apt-get install #{filename}"
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
                cmd = @getCommand "apt-get", "install", pinfo, "#{pinfo.name}-#{pinfo.version}"
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
