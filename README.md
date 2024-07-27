
# lua-resty-proxydns

`lua-resty-proxydns` is a Lua module designed for OpenResty that proxies DNS requests, caches them locally, and allows redirection to specific addresses for predefined domains.

## Features

- **DNS Proxying**: Redirects DNS requests through specified nameservers.
- **Local Caching**: Caches DNS queries and responses locally to enhance performance.
- **Custom Domain Redirection**: Redirects predefined domains to specified addresses.

## Installation

To install this module, you can use the OpenResty Package Manager (opm):

```sh
opm get iakuf/lua-resty-proxydns
```

## Dependencies

This module requires the `lua-cjson` and `lua-resty-openssl` libraries to work. Ensure that both libraries are installed and accessible in your OpenResty environment.

### Install lua-cjson

You can install `lua-cjson` using OPM:

```bash
opm get ledgetech/lua-cjson
```

### Install lua-resty-dns-server

You can install `lua-resty-dns-server` using OPM:

```bash
opm get selboo/lua-resty-dns-server
```

### Install lua-resty-resolver

You can install `lua-resty-resolver` using OPM:

```bash
opm get jkeys089/lua-resty-resolver
```

## Configuration

Add the DNS proxy configuration to your `nginx.conf`:

```nginx
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

### Customizing Specific Domain to Specific Address

If you want to customize a specific domain to a specific address, you can directly configure the init_custom_domains with a file path containing the domain and corresponding IP addresses.

```nginx
dns_proxy:init_custom_domains("/etc/openresty/domains.txt")

```

Create a `domains.txt` file in the specified location (`/etc/openresty/domains.txt`) with the format:

```ini
example.com 192.168.1.1
test.com 192.168.1.2
```

Each line contains a domain followed by an IP address to which the domain should be redirected.

### Redirecting All Domains to a Specific Address

To redirect all domains in the DNS to a specific address, you can configure the redirect_all parameter with an address, for example:

```shell
dns_proxy:redirect_all("10.10.10.1")
```

You can dynamically adjust this setting. If an empty string is passed, the DNS will resolve normally. Specific sources can be given specific outputs accordingly.

## Usage

Start your OpenResty server as usual. The DNS proxy will handle requests for the domains specified in `domains.txt` and cache the DNS queries as configured.

## License

This module is licensed under the MIT License - see the LICENSE file for details.
