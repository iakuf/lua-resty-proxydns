
# lua-resty-proxydns

`lua-resty-proxydns` is a Lua module designed for OpenResty that proxies DNS requests, caches them locally, and allows redirection to specific addresses for predefined domains.

## Features

- **DNS Proxying**: Redirects DNS requests through specified nameservers.
- **Local Caching**: Caches DNS queries and responses locally to enhance performance.
- **Custom Domain Redirection**: Redirects predefined domains to specified addresses.

## Installation

1. Ensure you have OpenResty installed on your system. If not, install OpenResty from [the official site](https://openresty.org/).
2. Clone this repository or download the module:
```bash
git clone https://github.com/iakuf/lua-resty-proxydns.git
```

1. Place the `lib/resty/proxydns.lua` file in your OpenResty's Lua library path.

## Dependencies

This module requires the `lua-cjson` and `lua-resty-openssl` libraries to work. Ensure that both libraries are installed and accessible in your OpenResty environment.

### Install lua-cjson

You can install `lua-cjson` using OPM:

```
    opm get ledgetech/lua-cjson
```

### Install lua-resty-dns-server

You can install `lua-resty-dns-server` using OPM:

```
    opm get selboo/lua-resty-dns-server
```

### Install lua-resty-resolver

You can install `lua-resty-resolver` using OPM:

```
    opm get jkeys089/lua-resty-resolver
```



## Configuration

1. Add the DNS proxy configuration to your `nginx.conf`:

   ```
    stream {
       lua_shared_dict dns_cache 10m;
       init_by_lua_block {
           local dns_proxy = require("resty.proxydns")
           dns_proxy:config({
               nameservers = {"8.8.8.8", "8.8.4.4"},
               retrans = 5,
               timeout = 2000,
           })  
           dns_proxy:init_custom_domains("/etc/openresty/domains.txt")
       }
   
       server {
           listen 53 udp;
   
           content_by_lua_block {
               local dns_proxy = require("resty.proxydns")
               dns_proxy:run()
           }   
       }
   }
   ```

2. Create a `domains.txt` file in the specified location (`/etc/openresty/domains.txt`) with the format:

   ```
   example.com 192.168.1.1
   test.com 192.168.1.2
   ```

   Each line contains a domain followed by an IP address to which the domain should be redirected.

## Usage

Start your OpenResty server as usual. The DNS proxy will handle requests for the domains specified in `domains.txt` and cache the DNS queries as configured.

## License

This module is licensed under the MIT License - see the LICENSE file for details.
