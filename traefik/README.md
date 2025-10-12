# Traefik Reverse Proxy Setup

This directory contains the configuration for Traefik reverse proxy integration with the mediaserver stack.

## Overview

Traefik provides:
- SSL/TLS termination with Let's Encrypt certificates
- Automatic service discovery via Docker labels
- Load balancing and health checks
- Security middleware (rate limiting, headers, CORS)
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
   CLOUDFLARE_API_KEY=your-cloudflare-api-token
   ```

3. **Generate Traefik Password**:
   ```bash
   # Generate bcrypt hash for dashboard access
   echo 'your-secure-password' | htpasswd -nbBC 10 admin | sed 's/$2y/$2a/'
   ```
   Update `TRAEFIK_PASSWORD` in `.env` with the generated hash.

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
curl -f http://localhost:8080/api/overview
```

### 4. SSL Certificate Generation

Traefik will automatically generate SSL certificates on first request:
```bash
# Trigger certificate generation
curl -f https://jellyfin.w0lverine.uk

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

### CORS
- Configured for cross-origin requests
- Allows credentials and specified headers

## Monitoring

### Traefik Dashboard
- **URL**: https://traefik.w0lverine.uk
- **Username**: admin (from .env)
- **Password**: Set during setup

### Health Checks
```bash
# Check Traefik health
curl -f http://localhost:8080/ping

# View routing table
curl -f http://localhost:8080/api/http/routers

# View services
curl -f http://localhost:8080/api/http/services
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
   - Verify TRAEFIK_PASSWORD hash format
   - Check if credentials are set in .env

### Debug Commands
```bash
# View all Traefik configuration
curl -f http://localhost:8080/api/overview

# Check specific router
curl -f http://localhost:8080/api/http/routers/jellyfin

# View middleware
curl -f http://localhost:8080/api/http/middlewares

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