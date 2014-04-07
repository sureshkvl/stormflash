#utility functions
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
			i++
			if i>4
				temparr=k.split(/\s+/)
				#column1 is package name
				resultarray.push temparr[1] if temparr[1]?
		callback(resultarray)
	)



#package list class
class PackageLib
	# global arrays
	#linux flavors 
	linuxflavors=['ubuntu','fedora','centos','redhat']
	# pkgmgrapp array stores the  package manager applications supported for the respective OS flavor.
	pkgmgrapp=[]
	
	#global variables
	@ostype='Unknown'
	@osflavor='Unknown'
	@packageApp='Unknown'

	constructor:->
		console.log 'PackageList constructor called'
		#initialize pkgmgrapp array with ubuntu package manager details
		pkgmgrapp.push(flavor:'ubuntu',pkg:['dpkg','apt-get'])
		@ostype=require('os').type()
		
		#check the OS flavor, 
		#if the /etc/lsb-release file is present  and flavor is matched with linuxflavors array, 
		#then the new flavor name will be assigned in to @osflavor
		#else, the default value  'Unknown' still remains. (applicable for non Linux OS also).
		fs=require('fs')
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

	
	
	list:(callback)->
		res=
			{
			'os':''
			'osflavor':''
			'packagemanager':''
			'installed':[]
			}
		res.os=@ostype
		res.osflavor=@osflavor
		res.packagemanager=@packageApp

		if @packageApp is 'dpkg'
			rundpkg((resultarray)=>
				res.installed=resultarray
				callback(res)
			)


module.exports = PackageLib
