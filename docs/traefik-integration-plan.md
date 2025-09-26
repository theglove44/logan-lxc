# Traefik Integration Plan for Mediaserver Project

## Executive Summary

This document outlines the comprehensive plan to integrate Traefik reverse proxy into the existing mediaserver Docker Compose stack. The integration will provide centralized SSL/TLS termination, domain-based routing, and enhanced security for external access using the domain `mjoln1r.com`.

**Project**: Logan LXC Mediaserver  
**Goal**: Enable secure external access to media services via domain names  
**Timeline**: 4-6 hours implementation + testing  
**Risk Level**: Medium (reversible changes)

## Current State Analysis

### Existing Architecture
- **Network**: Single bridge network `media_net`
- **Service Count**: 15+ services across two Docker Compose stacks
- **Current Access**: Direct IP:port access (LAN only)
- **SSL/TLS**: No centralized certificate management
- **External Access**: Not available

### Current Service Exposure
| Service | Current Port | Container Port | Network Mode |
|---------|-------------|----------------|--------------|
| Homepage | 3000 | 3000 | bridge |
| Jellyfin | 8096 | 8096 | bridge |
| Plex | 32400 | 32400 | host |
| Overseerr | 5155 | 5055 | bridge |
| Sonarr | 8989 | 8989 | bridge |
| Radarr | 7878 | 7878 | bridge |
| Prowlarr | 9696 | 9696 | bridge |
| SABnzbd | 8080 | 8080 | bridge |
| Bazarr | 6767 | 6767 | bridge |
| Tautulli | 8181 | 8181 | bridge |
| Grafana | 3001 | 3000 | bridge |
| Prometheus | 9090 | 9090 | bridge |
| Dozzle | 9999 | 8080 | bridge |
| Filebrowser | 8081 | 80 | bridge |
| cAdvisor | 8082 | 8080 | bridge |
| Node Exporter | 9100 | 9100 | bridge |

## Proposed Architecture

### Domain Structure
```
mjoln1r.com (main domain)
├── jellyfin.mjoln1r.com → Jellyfin media server
├── plex.mjoln1r.com → Plex media server
├── overseerr.mjoln1r.com → Content request portal
├── sonarr.mjoln1r.com → TV automation
├── radarr.mjoln1r.com → Movie automation
├── prowlarr.mjoln1r.com → Indexer management
├── sabnzbd.mjoln1r.com → Download client
├── bazarr.mjoln1r.com → Subtitle management
├── tautulli.mjoln1r.com → Plex analytics
├── homepage.mjoln1r.com → Main dashboard
├── grafana.mjoln1r.com → Monitoring dashboard
├── prometheus.mjoln1r.com → Metrics database
├── dozzle.mjoln1r.com → Container logs
└── filebrowser.mjoln1r.com → File manager
```

### SSL/TLS Configuration
- **Certificate Provider**: Let's Encrypt
- **DNS Challenge**: Cloudflare DNS-01
- **Certificate Type**: Wildcard `*.mjoln1r.com`
- **Auto-renewal**: Enabled (60 days)
- **Security**: TLS 1.2/1.3 with secure ciphers

### Security Features
- **Rate Limiting**: Configurable per service
- **Security Headers**: HSTS, CSP, X-Frame-Options, X-Content-Type-Options
- **CORS**: Configured for cross-origin requests
- **IP Restrictions**: Optional for sensitive services

### Network Architecture
```
Internet → Cloudflare (DNS + CDN) → Traefik (SSL/TLS) → Docker Services
                                      ↓
                                 media_net (bridge)
                                      ↓
                              Service Containers
```

## Implementation Plan

### Phase 1: Traefik Setup (45-60 minutes)

#### 1.1 Create Traefik Configuration
**File**: `traefik-compose.yml`

```yaml
version: '3.8'
name: traefik

services:
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"    # HTTP
      - "443:443"  # HTTPS
      - "8080:8080" # Dashboard (internal only)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/traefik.yml:ro
      - ./traefik/config/:/config/:rw
      - ./traefik/certs/:/certs/:rw
    networks:
      - web
      - media_net
    environment:
      - CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL}
      - CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.mjoln1r.com`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$05$$..."
    healthcheck:
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  web:
    external: true
  media_net:
    external: true
```

#### 1.2 Traefik Static Configuration
**File**: `traefik/traefik.yml`

```yaml
global:
  checkNewVersion: true
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        options: default
  traefik:
    address: ":8080"

certificatesResolvers:
  cloudflare:
    acme:
      email: ${CLOUDFLARE_EMAIL}
      storage: /certs/acme.json
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"

tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
      curvePreferences:
        - CurveP521
        - CurveP384
```

#### 1.3 Environment Variables
**Add to `.env`**:
```bash
# Cloudflare Integration
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_KEY=your-cloudflare-api-key

# Traefik Credentials
TRAEFIK_USERNAME=admin
TRAEFIK_PASSWORD=secure-password-hash
```

### Phase 2: Service Integration (60-90 minutes)

#### 2.1 Core Services Labels
**Update `compose.yml`** with Traefik labels:

```yaml
services:
  jellyfin:
    # ... existing config ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.mjoln1r.com`)"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls.certresolver=cloudflare"
      - "traefik.http.routers.jellyfin.service=jellyfin"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
      - "traefik.http.routers.jellyfin.middlewares=security-headers,rate-limit"

  plex:
    # ... existing config ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.plex.rule=Host(`plex.mjoln1r.com`)"
      - "traefik.http.routers.plex.entrypoints=websecure"
      - "traefik.http.routers.plex.tls.certresolver=cloudflare"
      - "traefik.http.routers.plex.service=plex"
      - "traefik.http.services.plex.loadbalancer.server.port=32400"
      - "traefik.http.routers.plex.middlewares=security-headers"

  # ... repeat for all services ...
```

#### 2.2 Monitoring Services Labels
**Update `homepage-stack.yml`** with similar labels for monitoring services.

### Phase 3: Security Middleware (20-30 minutes)

#### 3.1 Dynamic Configuration
**File**: `traefik/config/middleware.yml`

```yaml
http:
  middlewares:
    security-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Frame-Options: "DENY"
          X-Content-Type-Options: "nosniff"
          Referrer-Policy: "strict-origin-when-cross-origin"
          Permissions-Policy: "geolocation=(), microphone=(), camera=()"
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true

    rate-limit:
      rateLimit:
        burst: 100
        average: 50

    auth:
      basicAuth:
        users:
          - "admin:$2y$05$..."

    cors:
      cors:
        allowCredentials: true
        allowHeaders:
          - "Content-Type"
          - "Authorization"
        allowMethods:
          - "GET"
          - "POST"
          - "PUT"
          - "DELETE"
        allowOriginList:
          - "https://mjoln1r.com"
        maxAge: 86400
```

### Phase 4: DNS Configuration (15-20 minutes)

#### 4.1 Cloudflare DNS Records
**Your current setup is already optimal!** You only need these two records:

| Type | Name | Value | TTL | Purpose |
|------|------|-------|-----|---------|
| A | @ | YOUR_SERVER_IP | 300 | Main domain → server IP |
| CNAME | * | mjoln1r.com | 300 | **Wildcard** → handles ALL subdomains |

**✅ Perfect Setup!**
- The wildcard CNAME (`*`) automatically routes all subdomains to your main domain
- No individual A records needed for each service
- Most efficient and maintainable approach

**Optional:** Individual A records (not required):
```bash
A    jellyfin     YOUR_SERVER_IP    300
A    plex         YOUR_SERVER_IP    300
# ... etc
```

### Phase 5: Testing and Validation (60-90 minutes)

#### 5.1 Internal Testing
```bash
# Test Traefik health
curl -f https://traefik.mjoln1r.com/api/overview

# Test service routing
curl -f https://jellyfin.mjoln1r.com/web/index.html
curl -f https://homepage.mjoln1r.com
curl -f https://grafana.mjoln1r.com
```

#### 5.2 SSL Certificate Validation
```bash
# Check certificate details
echo | openssl s_client -servername jellyfin.mjoln1r.com -connect YOUR_SERVER_IP:443 2>/dev/null | openssl x509 -noout -dates -subject

# Test SSL Labs rating
curl https://www.ssllabs.com/ssltest/analyze.html?d=jellyfin.mjoln1r.com
```

#### 5.3 External Access Testing
- Test from external network
- Verify all services accessible via domain
- Confirm SSL certificates valid
- Test service functionality through Traefik

## Migration Strategy

### Phase 1: Parallel Operation (Recommended)
1. Deploy Traefik alongside existing direct access
2. Configure DNS and SSL certificates
3. Test domain-based access
4. Maintain direct IP access during testing

### Phase 2: Gradual Migration
1. Update internal documentation with new URLs
2. Migrate user access to domain URLs
3. Monitor for issues
4. Keep direct access as fallback

### Phase 3: Cleanup (Optional)
1. Remove direct port exposure
2. Update firewall rules
3. Clean up unused configurations

## Rollback Procedures

### Emergency Rollback
```bash
# Stop Traefik
docker compose -f traefik-compose.yml down

# Remove Traefik labels from services
# (manual process - remove all traefik.enable=true labels)

# Restart services
docker compose up -d
```

### Partial Rollback
```bash
# Disable specific service routing
docker compose -f traefik-compose.yml exec traefik sh -c "
echo 'http:
  routers:
    jellyfin:
      rule: Host(\`jellyfin.mjoln1r.com\`)
      entrypoints: [websecure]
      tls: {}
      service: jellyfin
      middlewares: [security-headers]
  services:
    jellyfin:
      loadBalancer:
        servers:
        - url: http://jellyfin:8096' > /config/jellyfin-disabled.yml"
```

## Risk Assessment

### High Risk
- **SSL Certificate Issues**: May break external access
- **Service Discovery**: Misconfigured labels could expose services incorrectly

### Medium Risk
- **Network Configuration**: Changes to Docker networks
- **DNS Propagation**: External access may be delayed

### Low Risk
- **Performance**: Traefik adds minimal overhead
- **Reversibility**: All changes can be rolled back

### Mitigation Strategies
- **Testing**: Comprehensive testing before production
- **Backups**: Full configuration backups before changes
- **Monitoring**: Service monitoring during migration
- **Rollback Plan**: Documented procedures for quick reversal

## Timeline and Resources

### Estimated Timeline
- **Implementation**: 3-4 hours
- **Testing**: 1-2 hours
- **DNS Propagation**: 5 minutes - 24 hours
- **SSL Generation**: 1-5 minutes

### Required Resources
- **Cloudflare API Token**: DNS edit permissions
- **Server Access**: SSH access for configuration
- **Testing Environment**: External network for testing
- **Documentation**: Access to update internal docs

### Success Metrics
- [ ] All services accessible via domain names
- [ ] SSL certificates valid and auto-renewing
- [ ] Security headers properly configured
- [ ] Rate limiting functional
- [ ] Internal dashboard accessible
- [ ] No service downtime during migration
- [ ] External access confirmed working

## Configuration Files Summary

### Files to Create
1. `traefik-compose.yml` - Main Traefik stack
2. `traefik/traefik.yml` - Static configuration
3. `traefik/config/middleware.yml` - Security middleware
4. `traefik/certs/` - Certificate storage (auto-created)

### Files to Modify
1. `compose.yml` - Add Traefik labels to core services
2. `homepage-stack.yml` - Add Traefik labels to monitoring services
3. `.env` - Add Cloudflare and Traefik credentials
4. `docs/architecture.md` - Update with new network diagram

### Files to Update (Documentation)
1. `README.md` - Update service URLs
2. `docs/operations-guide.md` - Add Traefik management procedures
3. `docs/troubleshooting.md` - Add Traefik troubleshooting section

## Next Steps

1. **Review**: Complete review of this integration plan
2. **Approval**: Confirm readiness to proceed with implementation
3. **Backup**: Create full system backup before changes
4. **Implementation**: Execute phased implementation plan
5. **Testing**: Comprehensive testing of all functionality
6. **Documentation**: Update all relevant documentation
7. **Monitoring**: Monitor system for issues post-deployment

---

**Status**: Ready for implementation  
**Last Updated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Author**: Kilo Code (Architect Mode)