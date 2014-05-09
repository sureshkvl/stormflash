###
#utility functions

#getnpmname funciton parse input line (npm output),
#and return s the package name and version (only top level package)
#input line : "npm ls" output line.
#output : packageobj or null
getnpmname = (name) ->
    packageobj=
        {
            'name':''
            'version':''
        }
    temparr=name.split(/\s+/)
    # when parsing top packages- array length will be only 2.
    # so we have to process only if array length is 2
    if temparr.length == 2
        for i in temparr
            #example line : cloudflash-bolt@0.3.4
                if i.indexOf('@') != -1
                    val=i.split('@')
                    #val[0] is name, val[1] is version
                    packageobj.name=val[0]
                    packageobj.version=val[1]
                    return packageobj
    #return null if not able to parse
    return null


#getpkgname function  parse the input line (dpkg -l output line)
#and return the package name and version
#input: "dpkg -l" output
#output: packageobj  or null
#sample input line : ii  zlib1g-dev:amd64        1:1.2.7.dfsg-13ubuntu2             amd64     library
getpkgname = (name) ->

    packageobj=
        {
            'name':''
            'version':''
        }
    temparr=name.split(/\s+/)
    # for headers(dpkg -l output headers) array length will be less than 4
    if temparr.length > 4
        if temparr[1]?
            packageobj.name=temparr[1]
            packageobj.version=temparr[2]
            return packageobj
    return null

#isInstalled function : Check the given tool is present in the filesystem
isInstalled = (toolname)->
    mod = require('find-in-path')
    #console.log toolname
    present=false
    mod(toolname,(err,path)->
        console.log "isInstalled Error #{err} occured, when we find toolname #{toolname}" if err?
        if path?
            present=true
            console.log  "#{toolname} present in the system"
    )
    return present


#rundpkg function:
# executes the dpkg -l command and parse the output and populate the resultarray with packagename and version number
rundpkg = ((callback)->
    cs=require('child_process')
    myoutput=''
    resultarray=[]
    pg=cs.spawn('dpkg',['-l'])
    pg.stdout.on 'data',(data)->
        myoutput=myoutput.concat(data)
    pg.stderr.on 'data',(data)->
        console.log 'rundpkg:recvd error '+data
    pg.on 'close',(code)->
        console.log 'rundpkg: exits with code ',code
        myout=myoutput.split("\n")
        i=0
        for k in myout
            #In dpkg output,initial 5 lines are headers.. so no need to process it.
            #i++
            #if i>4
            op=getpkgname(k)
            resultarray.push op unless op is null
        callback(resultarray)
    )

#runnpm function:
#executes the 'npm ls command' , and parse the output and populate the resultarray with only top level npm packages.
runnpm = ((callback)->
    cs=require('child_process')
    myoutput=''
    resultarray=[]
    pg=cs.spawn('npm',['ls'])
    pg.stdout.on 'data',(data)->
        myoutput=myoutput.concat(data)
    pg.stderr.on 'data',(data)->
        console.log 'runnpm : recvd error' +data
    pg.on 'close',(code)->
        console.log 'runnpm: exits with code',code
        myout=myoutput.split("\n")
        for k in myout
            op= getnpmname(k)
            resultarray.push op unless op is null
            callback(resultarray)
    )

###
os = require('os')

class Environment

    async = require 'async'
    request = require 'request'
    providers = [
        name: "openstack"
        metaurl: "http://169.254.169.254/openstack/latest/meta_data.json"
       , # this comma MUST be one column lower
        name: "gce"
        metaurl: "http://169.254.169.254/computeMetadata/v1"
    ]

    #linux flavors
    linuxflavors=['cloudnode','ubuntu','fedora','centos','redhat']
    # pkgmgrapp array stores the  package manager applications supported for the respective OS flavor.
    pkgmgrapp=[]

    constructor: ->
        console.log 'Environment constructor called'
        ###
        #initialize pkgmgrapp array with cloudnode,ubuntu package manager details
        pkgmgrapp.push(flavor:'cloudnode',pkg:['dpkg'])
        pkgmgrapp.push(flavor:'ubuntu',pkg:['dpkg','apt-get'])
        #
        if fs.existsSync('/etc/lsb-release') is true
            contents=fs.readFileSync('/etc/lsb-release','utf8')
            console.log contents
            for val in linuxflavors
                @osflavor= val if contents.toLowerCase().indexOf(val.toLowerCase()) != -1

        console.log "OS: #{@ostype}, Flavor #{@osflavor}"
        #detect the installed package manager application only if ostype or flavor is detected.
        unless @ostype is 'Unknown' or @osflavor is 'Unknown'
            #identify the package list from the array for a linux flavor.
            for i in pkgmgrapp
                pkglist= i.pkg if i.flavor.toLowerCase() is @osflavor.toLowerCase()
            #detect the package installed in the system and break on first occurence.
            for i in pkglist
                if isInstalled(i) is true
                    @packageApp=i
                    break
        console.log 'packageapp ',@packageApp
        #check the npm present
        @npmpresent=isInstalled('npm')
        console.log 'npm present',@npmpresent

        ###

    check: (provider, callback) ->
        callback unless provider?
        request provider.metaurl, (err, res, body) ->
            console.log "#{provider.name} metadata http response statusCode: " + res.statusCode

            if res.statusCode == 200
                try
                    metadata = JSON.parse body
                    util.log "metadata: "+metadata
                    stormdata =
                        provider: provider.name
                        stormtracker: metadata.meta.stormtracker
                        serialkey: metadata.uuid

                    return callback stormdata if stormdata.serialkey
                catch error
                    util.log "unable to process response: "+body
            callback

    discover: (callback) ->
        i = 0
        stormdata = null
        async.until (
            () -> # test condition
                i >= providers.count or stormdata?
            (repeat) -> # repeat function
                @check providers[i++], (match) ->
                    stormdata = match if match?
                    repeat
            (err) -> # finally
                if err or not stormdata?
                    util.log "unable to discover the running provider environment!"
                callback stormdata
        )

    os: ->
        tmpdir: os.tmpdir()
        endianness: os.endianness()
        hostname: os.hostname()
        type: os.type()
        platform: os.platform()
        release: os.release()
        arch: os.arch()
        uptime: os.uptime()
        loadavg: os.loadavg()
        totalmem: os.totalmem()
        freemem: os.freemem()
        cpus: os.cpus()
        networkInterfaces: os.networkInterfaces()

module.exports = new Environment

