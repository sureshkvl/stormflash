processmgr=require('../processlib.coffee')

uproxy =
	name : 'uproxy'
	binpath: '/usr/local/bin'
	binname:  'universal'
	startargs : ['--config_file=/home/suresh/uproxy.ini','-L','/var/log/uproxy','&']
	reload : yes

udhcpd =
	name: 'busybox'
	binpath : '/usr/sbin'
	binname: 'udhcpd'
	startargs: ['-fS','&']
	reload: no
	
processmgr.addService(uproxy)
processmgr.addService(udhcpd)

x=processmgr.start(uproxy.name,'instance1')
console.log "process udhcpd start ",x
setTimeout ()=>
    processmgr.restart(uproxy.name,'instance1')
, 5000
