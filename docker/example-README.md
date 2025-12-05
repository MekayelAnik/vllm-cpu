# Context7 MCP Server
### Multi-Architecture Docker Image for Distributed Deployment

<div align="left">

<img alt="context7-mcp" src="https://img.shields.io/badge/Context7-MCP-00E9A3?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMiA3TDEyIDEyTDIyIDdMMTIgMloiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik0yIDEyTDEyIDE3TDIyIDEyIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPgo8cGF0aCBkPSJNMiAxN0wxMiAyMkwyMiAxNyIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KPC9zdmc+&logoColor=white" width="400">

[![Docker Pulls](https://img.shields.io/docker/pulls/mekayelanik/context7-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/context7-mcp)
[![Docker Stars](https://img.shields.io/docker/stars/mekayelanik/context7-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/context7-mcp)
[![License](https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square)](https://raw.githubusercontent.com/MekayelAnik/context7-mcp-docker/refs/heads/main/LICENSE)

**[Official Website](https://context7.com/)** • **[Documentation](https://github.com/upstash/context7)** • **[Docker Hub](https://hub.docker.com/r/mekayelanik/context7-mcp)**

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Supported Architectures](#supported-architectures)
- [Available Tags](#available-tags)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [MCP Client Configuration](#mcp-client-configuration)
- [Network Configuration](#network-configuration)
- [Updating](#updating)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)
- [Support & License](#support--license)

---

## Overview

Context7 MCP Server is a lightweight, high-performance Model Context Protocol server designed for distributed deployment across multiple architectures. Built on Alpine Linux for minimal footprint and maximum security.

### Key Features

✨ **Multi-Architecture Support** - Native support for x86-64 and ARM64  
🚀 **Multiple Transport Protocols** - HTTP, SSE, and WebSocket support  
🔒 **Secure by Design** - Alpine-based with minimal attack surface  
⚡ **High Performance** - ZSTD compression for faster deployments  
🎯 **Production Ready** - Stable releases with comprehensive testing  
🔧 **Easy Configuration** - Simple environment variable setup

---

## Supported Architectures

| Architecture | Tag Prefix | Status |
|:-------------|:-----------|:------:|
| **x86-64** | `amd64-<version>` | ✅ Stable |
| **ARM64** | `arm64v8-<version>` | ✅ Stable |

> 💡 Multi-arch images automatically select the correct architecture for your system.

---

## Available Tags

| Tag | Stability | Description | Use Case |
|:----|:---------:|:------------|:---------|
| `stable` | ⭐⭐⭐ | Most stable release | **Recommended for production** |
| `latest` | ⭐⭐⭐ | Latest stable release | Stay current with stable features |
| `1.0.21` | ⭐⭐⭐ | Specific version | Version pinning for consistency |
| `beta` | ⚠️ | Beta releases | **Testing only** |

### System Requirements

- **Docker Engine:** 23.0+
- **RAM:** Minimum 512MB
- **CPU:** Single core sufficient

> 🔒 **CRITICAL:** Do NOT expose this container directly to the internet without proper security measures (reverse proxy, SSL/TLS, authentication, firewall rules).

---

## Quick Start

### Docker Compose (Recommended)

```yaml
services:
  context7-mcp:
    image: mekayelanik/context7-mcp:stable
    container_name: context7-mcp
    restart: unless-stopped
    ports:
      - "8010:8010"
    environment:
      - PORT=8010
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Dhaka
      - NODE_ENV=production
      - PROTOCOL=SHTTP
    hostname: context7-mcp
    domainname: local
```

**Deploy:**
```bash
docker compose up -d
docker compose logs -f context7-mcp
```

### Docker CLI

```bash
docker run -d \
  --name=context7-mcp \
  --restart=unless-stopped \
  -p 8010:8010 \
  -e PORT=8010 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Dhaka \
  -e NODE_ENV=production \
  -e PROTOCOL=SHTTP \
  mekayelanik/context7-mcp:stable
```

### Access Endpoints

| Protocol | Endpoint | Use Case |
|:---------|:---------|:---------|
| **HTTP** | `http://host-ip:8010/mcp` | Best compatibility (recommended) |
| **SSE** | `http://host-ip:8010/sse` | Real-time streaming |
| **WebSocket** | `ws://host-ip:8010/message` | Bidirectional communication |

> ⏱️ **ARM Devices:** Allow 30-60 seconds for initialization before accessing endpoints.

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `PORT` | `8010` | Internal server port |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Asia/Dhaka` | Container timezone ([TZ database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)) |
| `NODE_ENV` | `production` | Node.js environment |
| `PROTOCOL` | `SHTTP` | Default transport protocol |

### User & Group IDs

Find your IDs and set them to avoid permission issues:

```bash
id username
# uid=1000(user) gid=1000(group)
```

### Timezone Examples

```yaml
- TZ=Asia/Dhaka        # Bangladesh
- TZ=America/New_York  # US Eastern
- TZ=Europe/London     # UK
- TZ=UTC               # Universal Time
```

---

## MCP Client Configuration

### Transport Support

| Client | HTTP | SSE | WebSocket | Recommended |
|:-------|:----:|:---:|:---------:|:------------|
| **VS Code (Cline/Roo-Cline)** | ✅ | ✅ | ❌ | HTTP |
| **Claude Desktop** | ✅ | ✅ | ⚠️* | HTTP |
| **Claude CLI** | ✅ | ✅ | ⚠️* | HTTP |
| **Codex CLI** | ✅ | ✅ | ⚠️* | HTTP |
| **Codeium (Windsurf)** | ✅ | ✅ | ⚠️* | HTTP |
| **Cursor** | ✅ | ✅ | ⚠️* | HTTP |

> ⚠️ *WebSocket is experimental ([Issue #1288](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1288))

---

### VS Code (Cline/Roo-Cline)

Configure in `.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "context7": {
      "url": "http://host-ip:8010/mcp",
      "transport": "http"
    }
  }
}
```

---

### Claude Desktop App

**Config Locations:**
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

**Configuration:**
```json
{
  "mcpServers": {
    "context7": {
      "transport": "http",
      "url": "http://localhost:8010/mcp",
      "autoApprove": [
        "resolve-library-id",
        "get-library-docs"
        ]
    }
  }
}
```

---

### Claude CLI

Configure in `~/.config/claude-cli/config.json`:

```json
{
  "mcpServers": {
    "context7": {
      "transport": "http",
      "url": "http://host-ip:8010/mcp",
      "autoApprove": [
        "resolve-library-id",
        "get-library-docs"
        ]
    }
  }
}
```

---

### Codex CLI

Configure in `~/.codex/config.json`:

```json
{
  "mcpServers": {
    "context7": {
      "transport": "http",
      "url": "http://host-ip:8010/mcp"
    }
  }
}
```

---

### Codeium (Windsurf)

Configure in `.codeium/mcp_settings.json`:

```json
{
  "mcpServers": {
    "context7": {
      "transport": "http",
      "url": "http://host-ip:8010/mcp"
    }
  }
}
```

---

### Cursor

Configure in `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "transport": "http",
      "url": "http://host-ip:8010/mcp"
    }
  }
}
```

---

### Testing Configuration

Verify with [MCP Inspector](https://github.com/modelcontextprotocol/inspector):

```bash
npm install -g @modelcontextprotocol/inspector
mcp-inspector http://host-ip:8010/mcp
```

---

## Network Configuration

### Comparison

| Network Mode | Complexity | Performance | Use Case |
|:-------------|:----------:|:-----------:|:---------|
| **Bridge** | ⭐ Easy | ⭐⭐⭐ Good | Default, isolated |
| **Host** | ⭐⭐ Moderate | ⭐⭐⭐⭐ Excellent | Direct host access |
| **MACVLAN** | ⭐⭐⭐ Advanced | ⭐⭐⭐⭐ Excellent | Dedicated IP |

---

### Bridge Network (Default)

```yaml
services:
  context7-mcp:
    image: mekayelanik/context7-mcp:stable
    ports:
      - "8010:8010"
```

**Benefits:** Container isolation, easy setup, works everywhere
**Access:** `http://localhost:8010/mcp`

---

### Host Network (Linux Only)

```yaml
services:
  context7-mcp:
    image: mekayelanik/context7-mcp:stable
    network_mode: host
```

**Benefits:** Maximum performance, no NAT overhead, no port mapping needed
**Considerations:** Linux only, shares host network namespace
**Access:** `http://localhost:8010/mcp`

---

### MACVLAN Network (Advanced)

```yaml
services:
  context7-mcp:
    image: mekayelanik/context7-mcp:stable
    mac_address: "AB:BC:CD:DE:EF:01"
    networks:
      macvlan-net:
        ipv4_address: 192.168.1.100

networks:
  macvlan-net:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
```

**Benefits:** Dedicated IP, direct LAN access
**Considerations:** Linux only, requires additional setup
**Access:** `http://192.168.1.100:8010/mcp`

---

## Updating

### Docker Compose

```bash
docker compose pull
docker compose up -d
docker image prune -f
```

### Docker CLI

```bash
docker pull mekayelanik/context7-mcp:stable
docker stop context7-mcp && docker rm context7-mcp
# Run your original docker run command
docker image prune -f
```

### One-Time Update with Watchtower

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once \
  context7-mcp
```

---

## Troubleshooting

### Pre-Flight Checklist

- ✅ Docker Engine 23.0+
- ✅ Port 8010 available
- ✅ Sufficient startup time (ARM devices)
- ✅ Latest stable image
- ✅ Correct configuration

### Common Issues

#### Container Won't Start

```bash
# Check Docker version
docker --version

# Verify port availability
sudo netstat -tulpn | grep 8010

# Check logs
docker logs context7-mcp
```

#### Permission Errors

```bash
# Get your IDs
id $USER

# Update configuration with correct PUID/PGID
# Fix volume permissions if needed
sudo chown -R 1000:1000 /path/to/volume
```

#### Client Cannot Connect

```bash
# Test connectivity
curl http://localhost:8010/mcp
curl http://host-ip:8010/mcp

# Check firewall
sudo ufw status

# Verify container
docker inspect context7-mcp | grep IPAddress
```

#### Slow ARM Performance

- Wait 30-60 seconds after start
- Monitor: `docker logs -f context7-mcp`
- Check resources: `docker stats context7-mcp`
- Use faster storage (SSD vs SD card)

### Debug Information

When reporting issues, include:

```bash
# System info
docker --version && uname -a

# Container logs
docker logs context7-mcp --tail 200 > logs.txt

# Container config
docker inspect context7-mcp > inspect.json
```

---

## Additional Resources

### Documentation
- 📚 [Context7 Official Docs](https://github.com/upstash/context7)
- 📦 [NPM Package](https://www.npmjs.com/package/@upstash/context7-mcp)
- 🔧 [MCP Inspector](https://github.com/modelcontextprotocol/inspector)

### Docker Resources
- 🐳 [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- 🌐 [Docker Networking](https://docs.docker.com/network/)
- 🛡️ [Docker Security](https://docs.docker.com/engine/security/)

### Monitoring
- 📊 [Diun - Update Notifier](https://crazymax.dev/diun/)
- ⚡ [Watchtower](https://containrrr.dev/watchtower/)

---

## Support & License

### Getting Help

**Docker Image Issues:**
- GitHub: [context7-mcp-docker/issues](https://github.com/MekayelAnik/context7-mcp/issues)

**Context7 MCP Issues:**
- GitHub: [upstash/context7/issues](https://github.com/upstash/context7/issues)
- Website: [context7.com](https://context7.com/)

### Contributing

We welcome contributions:
1. Report bugs via GitHub Issues
2. Suggest features
3. Improve documentation
4. Test beta releases

### License

GPL License. See [LICENSE](https://raw.githubusercontent.com/MekayelAnik/context7-mcp-docker/refs/heads/main/LICENSE) for details.

Context7 MCP server has its own license - see [Main NPM repo](https://github.com/upstash/context7).

---

<div align="center">

[⬆ Back to Top](#context7-mcp-server)

</div>
