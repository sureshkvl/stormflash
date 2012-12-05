cloudflash
==========

CloudFlash is a web framework for cloud based automation of openvpn, firmware, modules, and services.

CloudFlash supports JSON data serialization format. The format for both the request and the response
should be specified by using the Content-Type header, the Accept header.


*List of APIs*
=============

<table>
  <tr>
    <th>Verb</th><th>URI</th><th>Description</th>
  </tr>
  <tr>
    <td>GET</td><td>/services</td><td>List summary of services installed in VCG identified by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/services</td><td>Create a new service in VCG</td>
  </tr>
  <tr>
    <td>GET</td><td>/services/service-id</td><td>Describes an installed service in VCG by service ID</td>
  </tr>
  <tr>
    <td>DELETE</td><td>/services/service-id</td><td>Delete an installed service in VCG by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/openvpn</td><td>Modify existing OpenVPN configuration</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/firewall</td><td>Modify existing Firewall configuration</td>
  </tr>
  <tr>
    <td>POST</td><td>/services/service-id/action</td><td>Execute command on the VCG</td>
  </tr>

</table>


*URI structure*

For now there is no API version specified in either URI or JSON data. But, in future we plan to use
API version in the URI.

For example

      /services/V1.0/service family/service type


*Authentication*

Current implementation of cloudflash in VCG does not require that each request will include the credntials of
the user submiting the request.
Plan is to have OAuth scheme of authentication.

*Services API*
==============

 List Services
--------------

    Verb	URI	        Description
    GET	/services	Lists summary of services configured in VCG identified by service ID.


Note: The request does not require a message body.
Success: Returns JSON data with list of services installed on VCG. Each service is identified by service ID

The service ID is generated is a UUID.

Service Family is the generic service type while name is the actual service name.

pkgurl: The package download link provided to VCG

api: Supported APIs for this service.

*Note: Currently no validation of the package contents done*

*TODO: Caller to provide md5sum of the package along with pkgurl*


**Example Request and Response**

*Request*

    GET /services HTTP/1.1

*Response*

```
{
    "services": [
        {
            "id": "40860f06-7dcf-41ab-a414-98957b092b7b",
            "status": "installed"
            "api": "/vpnrac",
			"description": {
				 "name": "at",
            	 "family": "remote-access",
			     "version": "1.0",
            	 "pkgurl": "http://my-url.com/vpnrac-0.0.1.deb"
			}
        }
    ]
}
```

Create Service
---------------


    Verb	URI	        Description
    POST	/services	Create a new service in VCG.


The request **must** have the following parameters in JSON data

      1. service version
      2. service Name
      3. Service Family
      4. Package URL

On success it returns JSON data with the UUID for the service created.

**Example Request and Response**

### Request JSON

    {
    	"name": "openvon",
    	"family": "vpn",
    	"version": "1.0",
        "pkg": [
             "npm://openvpn",
             "deb://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.deb",
             "rpm://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.rpm"
         ],
         "api": "./lib/openvpn",
    }


### Response JSON
    {
      "id": "3f26cb88-9508-4693-a0bb-da650d9c545f",
      "description": {
        "version": "1.0",
        "name": "openvpn",
        "family": "remote-access",
        "pkg": [
          "npm://openvpn",
          "deb://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.deb",
          "rpm://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.rpm"
        ],
        "api": "./lib/openvpn",
        "id": "81abefcc-bb38-4d16-accb-d7f59bda620b"
      },
      "status": {
        "installed": true
      }
    }


Describe Service
----------------

    Verb	URI	                 Description
    GET	    /services/service-id	  Show a service in VCG specified by service-ID

**Example Request and Response**

### Request Headers

    GET /services/3f26cb88-9508-4693-a0bb-da650d9c545f HTTP/1.1

### Response JSON
    {
      "id": "3f26cb88-9508-4693-a0bb-da650d9c545f",
      "description": {
        "version": "1.0",
        "name": "openvpn",
        "family": "remote-access",
        "pkg": [
          "npm://openvpn",
          "deb://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.deb",
          "rpm://10.1.10.152/SecurePrivateNetwork-linux-32bit-3.1.15.rpm"
        ],
        "api": "./lib/openvpn",
        "id": "81abefcc-bb38-4d16-accb-d7f59bda620b"
      },
      "status": null
    }


Delete a service
----------------

    Verb	URI	                 Description
    DELETE	/services/service-id	  Delete a service in VCG specified by service-ID


On Success returns 200 with JSON data

*TODO: Return appropriate error code and description in case of failure.*

**Example Request and Response**

### Request Headers

    DELETE /services/d40d38bd-aab0-4430-ac61-4b8ee91dc668 HTTP/1.1

### Response JSON

    { deleted: true }


Action Command API
------------------
This API is used to perform the action like start, stop, restart and sync on the installed services as identified by service-id


    Verb	URI	                 Description
    POST	/services/service-id/action	  Execute an action command

**Example Request and Response**

### Request Headers

    POST /services/a12796b8-c786-4351-ba7d-4b95cd8e0797/action HTTP/1.1

### Request JSON

    { command: "stop" }

### Response JSON

    { result: true }

