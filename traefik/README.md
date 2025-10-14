# Traefik Reverse Proxy Setup

This directory contains the configuration for Traefik reverse proxy integration with the mediaserver stack.

## Overview

Traefik provides:
- SSL/TLS termination with Let's Encrypt certificates
- Automatic service discovery via Docker labels
- Load balancing and health checks
- Security middleware (rate limiting, headers)
- Internal dashboard for monitoring

## Configuration Files

- `traefik.yml` - Main Traefik static configuration
- `config/middleware.yml` - Security middleware definitions
- `certs/` - SSL certificate storage (auto-managed)

## Setup Instructions

### 1. Cloudflare Configuration

1. **Get Cloudflare API Token**:
   - Go to Cloudflare Dashboard → Profile → API Tokens
   - Create token with "Edit zone DNS" permissions
   - Copy the token value

2. **Update Environment Variables**:
   Edit `.env` file:
   ```bash
   CLOUDFLARE_EMAIL=your-email@example.com
   CLOUDFLARE_API_TOKEN=cf-api-token-with-dns-edit
   CLOUDFLARE_DNS_API_TOKEN=${CLOUDFLARE_API_TOKEN}
   ```

   Update `traefik/traefik.yml` and set `certificatesResolvers.cloudflare.acme.email` to the same address.

3. **Generate Traefik Password**:
   ```bash
   # Generate an apr1 hash and escape $ for docker compose
   echo 'your-secure-password' | htpasswd -nBm admin | sed 's/\$/\$\$/g'
   ```
   Replace the value of `traefik.http.middlewares.dashboard-auth.basicauth.users` in `traefik-compose.yml` with the generated hash.

### 2. DNS Configuration

**Good news!** Your current DNS setup is already optimal. You only need to ensure these two records exist in Cloudflare:

| Type | Name | Value | TTL | Purpose |
|------|------|-------|-----|---------|
| A | @ | YOUR_SERVER_IP | 300 | Main domain points to your server |
| CNAME | * | w0lverine.uk | 300 | **Wildcard** - handles ALL subdomains |

**✅ Your Setup is Perfect!**
- The wildcard CNAME (`*`) automatically routes all subdomains (jellyfin.w0lverine.uk, plex.w0lverine.uk, etc.) to your main domain
- No need for individual A records for each service
- This is the most efficient and maintainable approach

**Optional Enhancement:**
If you want to be extra explicit, you could add individual A records, but they're not necessary with the wildcard setup:

```bash
# Optional: Individual service records (not required with wildcard)
A    jellyfin     YOUR_SERVER_IP    300
A    plex         YOUR_SERVER_IP    300
A    homepage     YOUR_SERVER_IP    300
# ... etc
```

**Verification:**
```bash
# Test DNS resolution
nslookup jellyfin.w0lverine.uk
nslookup homepage.w0lverine.uk
# Should resolve to YOUR_SERVER_IP
```

### 3. Deploy Traefik

```bash
# Deploy Traefik stack
docker compose -f traefik-compose.yml up -d

# Check Traefik logs
docker logs traefik

# Check Traefik health
curl -u admin:test -f http://localhost:8083/api/overview
```

### 4. Open External Access

- Forward TCP ports `80` and `443` from your router/firewall to the Traefik host (`10.0.0.100` in this setup).
- Ensure the host firewall allows inbound `80/tcp` and `443/tcp` (e.g. `sudo ufw allow 80,443/tcp` if UFW is enabled).

### 4. SSL Certificate Generation

Traefik will automatically generate SSL certificates on first request:
```bash
# Trigger certificate generation
curl -k --resolve jellyfin.w0lverine.uk:443:127.0.0.1 https://jellyfin.w0lverine.uk

# Check certificate status
docker logs traefik | grep -i certificate
```

## Access URLs

### External Access (via Traefik)
- **Homepage**: https://homepage.w0lverine.uk
- **Jellyfin**: https://jellyfin.w0lverine.uk
- **Plex**: https://plex.w0lverine.uk
- **Grafana**: https://grafana.w0lverine.uk
- **Traefik Dashboard**: https://traefik.w0lverine.uk (requires auth)

### Internal Access (direct)
- **Homepage**: http://YOUR_SERVER_IP:3000
- **Jellyfin**: http://YOUR_SERVER_IP:8096
- **Plex**: http://YOUR_SERVER_IP:32400
- **Grafana**: http://YOUR_SERVER_IP:3001

## Security Features

### Rate Limiting
- Default: 50 requests/second, burst of 100
- Applied to all services automatically

### Security Headers
- HSTS (HTTP Strict Transport Security)
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin

## Monitoring

### Traefik Dashboard
- **URL**: https://traefik.w0lverine.uk
- **Username**: admin (from .env)
- **Password**: Default placeholder is `test` (update by generating a new bcrypt/apr1 hash and replacing the value in `traefik-compose.yml`)

### Health Checks
```bash
# Check Traefik health
curl -u admin:test -f http://localhost:8083/ping

# View routing table
curl -u admin:test -f http://localhost:8083/api/http/routers

# View services
curl -u admin:test -f http://localhost:8083/api/http/services
```

## Troubleshooting

### Common Issues

1. **SSL Certificate Not Generating**:
   - Check Cloudflare API credentials
   - Verify DNS records are correct
   - Check Traefik logs: `docker logs traefik`

2. **Services Not Accessible**:
   - Verify service labels are applied
   - Check if services are running
   - Review Traefik routing rules

3. **Dashboard Access Denied**:
   - Verify the basicauth hash configured in `traefik-compose.yml`
   - Regenerate the hash and redeploy if you changed credentials

### Debug Commands
```bash
# View all Traefik configuration
curl -u admin:test -f http://localhost:8083/api/overview

# Check specific router
curl -u admin:test -f http://localhost:8083/api/http/routers/jellyfin

# View middleware
curl -f http://localhost:8083/api/http/middlewares

# Check Traefik logs with debug
docker logs traefik --details
```

## Maintenance

### Certificate Renewal
- Automatic renewal every 60 days
- Monitor via Traefik dashboard
- Check logs for renewal status

### Updates
```bash
# Update Traefik
docker compose -f traefik-compose.yml pull
docker compose -f traefik-compose.yml up -d

# Restart Traefik
docker restart traefik
```

### Backup
- SSL certificates: `/opt/mediaserver/traefik/certs/`
- Configuration: All files in `/opt/mediaserver/traefik/`
- Include in regular backup routine
