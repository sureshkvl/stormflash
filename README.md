cloudflash
==========

CloudFlash is a web framework for cloud based automation of openvpn, firmware, modules, and services.

1. get services api
-------------------
	This api will collect the installed services like openvpn, firewall, etc on the device from /services/service.txt file and return a JSON formatted string to use it in upper layer of the web service.

2. post service api
-------------------
	This api will install the new service on the device and update it into installed services list.

3. post config api
------------------
	This api will get the JSON object with service configuration data and validate the configuration parameterer.  Create configuration file in /services/openvpn/<GUID>/server.conf, /services/firewall/<GUID>/server.conf for openvpn and firewall respectively.

4. put config api
-----------------
	This api will modify the existing configuration of the installed services based on the GUID.

5. action api
-------------
	This api will be used to perform action on installed services like start, stop, status, etc.
