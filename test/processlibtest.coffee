processmgr=require('../lib/processlib.coffee')

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

processmgr.start uproxy.name,'instance1',(result)=>
            console.log "test  : return value ",result
setTimeout ()=>
    processmgr.restart(uproxy.name,'instance1')
, 5000
