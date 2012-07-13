cloudflash
==========

CloudFlash is a web framework for cloud based automation of openvpn, firmware, modules, and services.

CloudFlash supports JSON data serialization format. The format for both the request and the response 
should be specified by using the Content-Type header, the Accept header.

URI structure:

For now there is no API version specified in either URI or JSON data. But, in future we plan to use 
API version in the URI. 

   For example /services/V1.0/service family/service type
   

Authentication:

Current implementation of cloudflash in VCG does not require that each request will include the credntials of 
the user submiting the request.
Plan is to have OAuth scheme of authentication.

List of APIs

  1. Services:
     List Services
         
            Verb	URI	        Description
             GET	/services	Lists summary of services configured in VCG identified by service ID.

     Note: The operation does not require a message body.
     Success: Returns JSON data with list of services installed on VCG. Each service is identified by service ID 
     The service ID is generated is a UUID. 
     Service Family is the generic service type while name is the actual service name. 
     pkgurl: The package download link provided to VCG
     api: Supported APIs for this service.
     
     Note: Currently no validation of the package contents done.
     TODO: Caller to provide md5sum of the package along with pkgurl.
     
     Example Request and Response:
     
     GET /services HTTP/1.1
     
       Host: localhost:3000
       Connection: keep-alive
       Cache-Control: max-age=0
       User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.11 (KHTML, like Gecko) Chrome/20.0.1132.47 Safari/536.11
       Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
       Accept-Encoding: gzip,deflate,sdch
       Accept-Language: en-US,en;q=0.8
       Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3
       
     Response 
     
     {"services":[null,null,null,null,
       {"service":
         {"version":"1.0","name":"at","family":"remote-access","pkgurl":"http://10.1.10.145/vpnrac-0.0.1.deb","api":"/vpnrac","id":"40860f06-7dcf-41ab-a414-98957b092b7b","status":"installed"}
       }]
     }

1. Get Services API (@services /)
---------------------------------
	This API will collect the installed services like openvpn, firewall, etc on the device from
	/services/service.txt and return a JSON formatted string to use it in upper layer of the web service.
	eg : 
	{
		"services" : { 
			"0942a130-1ac6-4ec4-b7cb-3ceec772495b" : {
				"type"    : "openvpn",
				"version" : "1.0.1.0",
				"date"    : "Wed Jul 04 2012 04:18:28 GMT-0700 (PDT)",
				"status"  : "success"
			},
			"c3de5869-cea9-4336-bbc2-e1fba28f893d" : {
				"type"    : "firewall",
				"version" : "1.0.1.0",
				"date"    : "Wed Jul 04 2012 04:19:06 GMT-0700 (PDT)",
				"status"  : "success"
			}
		}
	} 

2. Post Service API (@post /service/openvpn)
--------------------------------------------
	This API will install the specified new service on the device and update the service details 
	into /services/service.txt

3. Post openVPN Config API (@post /service/GUID/openvpn)
--------------------------------------------------------
	This API will get the JSON object formated schema for configuration data and validate the parameter and
	create configuration file in /services/<GUID>/openvpn/server.conf for openvpn. It also used to modify 
	the configuration parameter too.
	eg :
	{
		"services" : {   	
			"openvpn" : {
				"port":"7500",
				"dev": "tap",
		
				"proto": "udp",
				"max-routes": "255",
				"script-security": "3 system",
				"multihome":"",
				"management": "127.0.0.1 2020",
				"cipher": "AES-256-CBC",
				"tls-cipher": "AES256-SHA",
				"auth": "SHA1",
				"ca": "/etc/ca-bundle.pem",
				"dh": "/etc/dh1024.pem",
				"cert": "/etc/identity/snap.cert",
				"key": "/etc/identity/snap.key",
				"topology": "subnet",
				"server": "172.17.3.0 255.255.255.0",
				"route-gateway": "172.17.3.1",
		
				"client-config-dir": "/config/openvpn/ccd",
				"ccd-exclusive":"",
				"route": "10.1.9.0 255.255.255.0",
				"push": "route 192.168.9.0 255.255.255.0",
		                                          
				"max-clients": "254",
		                                  
				"persist-key":"",
				"persist-tun":"",                          
		                                  
				"status": "/var/log/server-status.log",
				"keepalive": "5 45",                        
				                                   
				"comp-lzo": "no",
				"push": "comp-lzo no",
		
				"sndbuf": "262144",                      
				"rcvbuf": "262144",                  
				"txqueuelen": "500",                         
				"replay-window": "512 15",                                           
		
				"verb": "3",
				"mlock":""    
			}
		}
	}

4. Delete openVPN Service API (@del)
------------------------------------
	This API will delete the specific service using GUID.

5. Post Firewall Config API (@post /service/GUID/firewall)
----------------------------------------------------------
	This API will get the JSON object formated schema for configuration data and validate the parameter and
	create configuration file in /services/<GUID>/firewall/shorewall.conf for firewall. It also used to modify 
	the configuration parameter too.
	eg :
	{
		"services" : {   	
			"firewall" : {
				"STARTUP_ENABLED": "Yes",
				"LOGFILE": "/var/log/firewall",
				"LOGFORMAT": "Firewall:%s:%s:",
				"LOGTAGONLY": "No",
				"LOGRATE": "",
				"LOGBURST": "",
				"LOGALLNEW": "",
				"BLACKLIST_LOGLEVEL":"" ,
				"LOGNEWNOTSYN": "$LOG",
				"MACLIST_LOG_LEVEL": "$LOG",
				"TCP_FLAGS_LOG_LEVEL": "$LOG",
				"RFC1918_LOG_LEVEL": "$LOG",
				"SMURF_LOG_LEVEL": "$LOG",
				"BOGON_LOG_LEVEL": "$LOG",
	
				"LOG_MARTIANS": "No",
				"IPTABLES": "iptables",
				"PATH": "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin",
				"SHOREWALL_SHELL": "/bin/sh",
				"SUBSYSLOCK": "/var/lock/subsys/shorewall",
				"STATEDIR": "/var/lib/shorewall",
				"MODULESDIR":"" ,
				"CONFIG_PATH": "/etc/shorewall:/usr/share/shorewall",
				"FW": "FW",
	
				"IP_FORWARDING": "On",
				"ADD_IP_ALIASES": "Yes",
				"ADD_SNAT_ALIASES": "No",
				"RETAIN_ALIASES": "No",
				"TC_ENABLED": "Internal",
				"CLEAR_TC": "Yes",
				"MARK_IN_FORWARD_CHAIN": "No",
				"CLAMPMSS": "No",
				"ROUTE_FILTER": "No",
				"DETECT_DNAT_IPADDRS": "No",
				"MUTEX_TIMEOUT": "60",
				"NEWNOTSYN": "Yes",
				"ADMINISABSENTMINDED": "Yes",
				"BLACKLISTNEWONLY": "Yes",
				"DELAYBLACKLISTLOAD": "No",
				"MODULE_SUFFIX": "",
				"DISABLE_IPV6": "Yes",
				"BRIDGING": "No",
				"DYNAMIC_ZONES": "No",
				"PKTTYPE": "Yes",
				"DROPINVALID": "No",
				"BLACKLIST_DISPOSITION": "DROP",
				"MACLIST_DISPOSITION": "REJECT",
				"TCP_FLAGS_DISPOSITION": "DROP",
	
				"FASTACCEPT": "No"
			}
		}
	}

6. Delete Firewall Service API (@del)
-------------------------------------
	This API will delete the firewall service using GUID.

7. Action API (@post /service/GUID/action)
------------------------------------------
	This API will be used to perform the action like start, stop, restart and status on the 
	installed services by GUID.
	eg : 
	{
		"openvpn" : {
			"start"   : "svcs openvpn start;sleep 3;svcs openvpn status",
			"stop"    : "svcs openvpn stop",
			"status"  : "svcs openvpn status",
			"restart" : "svcs openvpn restart",
			"file"    : "openvpn.pid"
		},
	 	"firewall" : {
			"start"   : "svcs iptables start",
			"stop"    : "svcs iptables stop",
			"status"  : "svcs iptables status",
			"restart" : "svcs iptables restart",
			"file"    : "firewall.pid"
		}
	}
