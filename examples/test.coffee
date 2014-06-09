sf = require('../src/stormflash').StormFlash
require('look').start()
fs = require 'fs'

agent = new sf()
StormPackage = require('../src/stormflash').StormPackage
StormInstance = require('../src/stormflash').StormInstance

packages = [
    #            "name": "test",
    #            "version" : "0.0.1",
    #            "source" : "npm://testnpm",
    #          ,
    #            "name": "debtest",
    #            "version" : "0.2.2",
    #            "source" : "dpkg://testme.com/testdeb.pkg",
    #          ,
            "name": "corenova",
            "version" : "*",
            "source" : "npm://",
      ]
    
       
getListofpackages = ->
    console.log "List of Packages .........................................................."
    agent.packages.list()


getSpecificPackage = ->
    console.log agent.packages.get "mypkg"


deletePackage = ->
    console.log agent.packages.remove "mypkg"


testPackageInstall = ->
    for pkg in packages
        agent.install pkg , (result) ->
            if result instanceof Error
                console.log "Failed. Reason is ", result
             console.log "Success in installing the package" unless result instanceof Error


createInstance = ->
    out = fs.openSync './out.log', 'a'
    err = fs.openSync './err.log', 'a'
    env = process.env
    env.MY_PATH = 'ravi'
    instance =
            name: "openvpn"
            path: "/usr/sbin"
            monitor: true
            args: ["--config", "/config/openvpn/ravi.conf", "--log", "/tmp/openvpn.log"]
            options:
                env:env
                stdio: ['ignore', out, err]

    sinstance = new StormInstance instance
    sinstance.id = 'testserver'
    res = agent.instances.add "testserver", sinstance
    console.log "result to add instance", res
    agent.instances.get "testserver", (instance) =>
        console.log "response to get ", instance
        return  if instance instanceof Error

    console.log agent.instances.list()
    agent.start "testserver", (result, error) =>
        console.log "result of starting procesS", result, error
        #agent.stop "testserver", (result) =>

getInstances = ->
    console.log "Get List of Instances.................................."
    console.log agent.instances.list()


discoverInstances = ->
    agent.instances.discover()

#setTimeout getListofPackages, 500
#agent.spm.monitorNpmModules()
#
#
process.on 'uncaughtException', (err) ->
    console.log "Here is the  backtrace"
    console.log err.stack

setTimeout ()->
    #agent.spm.monitorDebPkgs()
    #agent.spm.monitor 8000
    agent.run()
    #agent.instances.discover()
    #discoverInstances()
    #getInstances()
    createInstance()
    #testPackageInstall()
#    getSpecificPackage()
    ()->
    #    getListofpackages()
#    deletePackage()
, 100
setTimeout () ->
    console.log "Matching zappajs with packages.............................."
    agent.packages.find "zappajs", "*"
, 2000


