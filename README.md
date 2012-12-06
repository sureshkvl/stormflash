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
    <td>GET</td><td>/services</td><td>List summary of services installed in VCG/CPEs identified by service ID</td>
  </tr>
  <tr>
    <td>POST</td><td>/services</td><td>Create a new service in VCG/CPE </td>
  </tr>
  <tr>
    <td>GET</td><td>/services/service-id</td><td>Describes an installed service in VCG/CPEs by service ID</td>
  </tr>
   <tr>
    <td>PUT</td><td>/services/service-id</td><td>Update existing service configuration in VCG/CPEs by service-id </td>
  </tr>
  <tr>
    <td>DELETE</td><td>/services/service-id</td><td>Delete an installed service in VCG/CPEs by service ID</td>
  </tr>
  
  <tr>
    <td>POST</td><td>/services/service-id/action</td><td>Execute command on the VCG/CPEs </td>
  </tr>

</table>


*URI structure*

For now there is no API version specified in either URI or JSON data. But, in future we plan to use
API version in the URI.

For example

      /services/V1.0/service family/service type


*Authentication*

Current implementation of cloudflash in VCG/CPEs does not require that each request will include the credntials of
the user submiting the request.
Plan is to have OAuth scheme of authentication.

*Services API*
==============

 List Services
--------------

    Verb	URI	        Description
    GET	/services	Lists summary of services configured in VCG/CPEs identified by service ID.


Note: The request does not require a message body.
Success: Returns JSON data with list of services installed on VCG/CPEs. Each service is identified by service ID

The service ID is generated is a UUID.

Service Family is the generic service type while name is the actual service name.

pkg: The package download link provided.

api: Supported APIs for this service.

*Note: Currently no validation of the package contents done*

*TODO: Caller to provide md5sum of the package along with pkgurl*


**Example Request and Response**

*Request*

    GET /services HTTP/1.1

*Response*

```
{
   "services":
   [
       {
           "id": "2ccc8dc8-62c5-491b-b305-3c029bde6f64",
           "description":
           {
               "version": "1.0",
               "name": "openvpn",
               "family": "vpn",
               "pkg":
               [
                   "npm://openvpn"
               ],
               "api": "lib/openvpn",
               "id": "20a80663-d311-4372-99d2-4b1ab14e443c"
           },
           "status":
           {
               "installed": true
           }
       }
   ]
}

```

Create Service
---------------


    Verb	URI	        Description
    POST	/services	Create a new service in VCG/CPEs.


The request **must** have the following parameters in JSON data

      1. service version
      2. service Name
      3. Service Family
      4. Package URL

On success it returns JSON data with the UUID for the service created.

**Example Request and Response**

### Request JSON for npm

    {
        "version": "1.0",
        "name": "openvpn",
        "family": "vpn",
        "pkg": [
             "npm://openvpn"
        ],
        "api": "lib/openvpn"
    }

### Response JSON

   {
       "id": "2ccc8dc8-62c5-491b-b305-3c029bde6f64",
       "description":
       {
           "version": "1.0",
           "name": "openvpn",
           "family": "vpn",
           "pkg":
           [
               "npm://openvpn"
           ],
           "api": "lib/openvpn",
           "id": "20a80663-d311-4372-99d2-4b1ab14e443c"
       },
       "status":
       {
           "installed": true
       }
    }

### Request JSON for deb

    {
        "version": "1.0",
        "name": "openvpn",
        "family": "vpn",
        "pkg": [
            "http://10.2.55.106/cloudflash/openvpn-2.1.3.i386.deb"
        ],
        "api": "lib/openvpn"
    }
### Response JSON

   {
        "id": "f39c0125-6a2e-423b-afbe-00215dfa9284",
        "description": {
            "version": "1.0",
            "name": "openvpn",
            "family": "vpn",
            "pkg": [
                "http://10.2.55.106/cloudflash/openvpn-2.1.3.i386.deb"
            ],
            "api": "lib/openvpn",
            "id": "9e0bc2df-195e-43e5-a65d-fa9275e60e54"
        },
        "status": {
            "installed": true
   }


Describe Service
----------------

    Verb	URI	                 Description
    GET	    /services/service-id	  Show a service in VCG/CPEs specified by service-ID

**Example Request and Response**

### Request Headers

    GET /services/2ccc8dc8-62c5-491b-b305-3c029bde6f64 HTTP/1.1

### Response JSON

    {
       "id": "2ccc8dc8-62c5-491b-b305-3c029bde6f64",
       "description":
       {
           "version": "1.0",
           "name": "openvpn",
           "family": "vpn",
           "pkg":
           [
               "npm://openvpn"
           ],
           "api": "lib/openvpn",
           "id": "20a80663-d311-4372-99d2-4b1ab14e443c"
       },
       "status":
       {
           "installed": true,
           "initialized": false,
           "enabled": false,
           "running": false,
           "result": "openvpn is uninitialized and not running "
       }
    }

Update Service
----------------

    Verb	URI	                 Description
    PUT	    /services/service-id	  Show a service in VCG/CPEs specified by service-ID

**Example Request and Response**

### Request Headers

    {
        "version": "1.0",
        "name": "openvpn",
        "family": "vpn",
        "pkg": [
             "npm://openvpn"
        ],
        "api": "lib/openvpn"
    }


### Response JSON

    {
       "id": "2ccc8dc8-62c5-491b-b305-3c029bde6f64",
       "description":
       {
           "version": "1.0",
           "name": "openvpn",
           "family": "vpn",
           "pkg":
           [
               "npm://openvpn"
           ],
           "api": "lib/openvpn",
           "id": "20a80663-d311-4372-99d2-4b1ab14e443c"
       },
       "status":
       {
           "installed": true,
           "initialized": false,
           "enabled": false,
           "running": false,
           "result": "openvpn is uninitialized and not running "
       }
    }


Delete a service
----------------

    Verb	URI	                 Description
    DELETE	/services/service-id	  Delete a service in VCG/CPEs specified by service-ID


On Success returns 200 with JSON data

*TODO: Return appropriate error code and description in case of failure.*

**Example Request and Response**

### Request Headers

    DELETE services/2ccc8dc8-62c5-491b-b305-3c029bde6f64 

### Response JSON

    {
       "deleted": true
    }


Action Command API
------------------
This API is used to perform the action like start, stop, restart and sync on the installed services as identified by service-id


    Verb	URI	                 Description
    POST	/services/service-id/action	  Execute an action command

**Example Request and Response**

### Request Headers

    POST /services/2ccc8dc8-62c5-491b-b305-3c029bde6f64/action  HTTP/1.1

### Request JSON

    {
       "command":"start"
    }

### Response JSON

    {
       "result": true
    }

