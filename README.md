Stormflash
==========

Synopsis
--------

Stormflash is the core component of stormstack that realizes the intents configured in the stormlight. Stormflash can seamlessly activate, update its environment information to stormtower and thereby gets itself ready to manage the network functions in the installed environment. stormflash provides APIs that can be invoked by an external entity for managing the application lifecycle of the operating environment where stormflash is running.

stormflash is inherited from stormbolt ,stormagent class. Hence stormflash has the stormbolt, stormagent functionality in.

stormflash has the package management capbality built in, which performs the below functionality, 
 - discovers the installed debian, node packages
 - supports the npm , linux package installation.
 - monitor the package changes on regualar interval
 It emits " discovered" event upon discoving the each package.
 
stormflash has the process manager library,  used for managing the process. It supports the start, stop, montior methods. It emits "error","signal","attached","attachedError","detached","detachError"



*List of APIs*
----------------

<table>
  <tr>
    <th>Verb</th><th>URI</th><th>Description</th>
  </tr>
 <tr>
    <td>POST</td><td>/packages</td><td>Create a package entry</td>
  </tr> 
  <tr>
    <td>GET</td><td>/packages</td><td>Get list of packages installed identified by package ID</td>
  </tr>
  <tr>
    <td>GET</td><td>/packages/id</td><td>Get a package details by ID</td>
  </tr>
  <tr>
    <td>DELETE</td><td>/packages/id</td><td>Delete a package entry by ID</td>
  </tr> 
</table>


**POST packages API**

    Verb      URI                       Description
    POST      /packages                 Create a package entry.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Request JSON
   
    {
        "name": "corenova-storm",
        "version": "*",
        "source": "npm://",
        "type": "npm"
    }
### Response JSON

    {
        "id": "e3db8f5c-00f3-4199-9ae2-2bf423774a17",
        "data": {
            "name": "commtouch-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "e3db8f5c-00f3-4199-9ae2-2bf423774a17"
        },
        "saved": true
    }


**GET packages API**

    Verb      URI                       Description
    GET       /packages                 Get list of packages installed.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Response JSON

    [
        {
            "name": "openvpn-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "5d709bbc-4f23-4ae6-9f47-f20f3f0a1add"
        },
        {
            "name": "corenova-storm",
            "version": "*",
            "source": "npm://",
            "type": "npm",
            "status": {
                "installed": true,
                "imported": true
            },
            "id": "f30571f3-7c11-4c6f-ac0b-3dcf162ccedf"
        }
    ]
    

**GET packages API**

    Verb      URI                       Description
    GET       /packages/id              Get a package details by ID.

On success it returns JSON data with the UUID with the packages configuration.

**Example Request and Response**

### Response JSON
    {
        "name": "corenova-storm",
        "version": "*",
        "source": "npm://",
        "type": "npm",
        "status": {
            "installed": true,
            "imported": true
        },
        "id": "f30571f3-7c11-4c6f-ac0b-3dcf162ccedf"
    }



**DELETE Packages API**

    Verb      URI                           Description
    DELETE   /packages/:id                  Delete existing package configuration by ID.

**Example Request and Response**

### Request Headers
DELETE /packages/:id

### Response Header

Status Code : 204 No Content


Copyright & License
--------
LICENSE 

MIT

COPYRIGHT AND PERMISSION NOTICE

Copyright (c) 2014-2015, Clearpath Networks, <licensing@clearpathnet.com>.

All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.