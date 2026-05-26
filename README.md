# Secure your Plex Software Stack with Tailscale

> Applications like Sonarr/Radarr/Prowlarr are companion applications that support the Plex Media Server environemnt. These applications are not built to be openly deployed over the internet - they are open source and built for homelab enthusiasts. Accessing these applications remotely while staying secure can be hard, but Tailscale's Subnet Router can help expose them securely.
> No more port fowarding or Reverse Proxy to expose the admin UI's - reduce your attack surface and stay secure!


## The Architecture

The majority of deployments use Docker, a containerization application host. Each container gets its own private IP on an internal NAT range and by default accept connections from anywhere. Many users utilize a firewall, like the Linux default UFW, which requires exposing the ports those applications use by poking a hole in the firewall.

### Typical Server Example Setup:

-->Docker
    -Plex Media Server: https://app.plex.tv/desktop/#!/
    -Sonarr: myDomain.com:8989
    -Radarr: myDomain.com:7878
    -Prowlarr: myDomain.com:9696
    -Tautulli: myDomain.com:8181
-->UFW
    -ALLOW: 32400 (Plex)
    -ALLOW: 8989 (Sonarr)
    -ALLOW: 7878 (Radarr)
    -ALLOW: 9696 (Prowlarr)
    -ALLOW: 8181 (Tautulli)
    -ALLOW: 22 (SSH)

With Tailscale, you no longer need to expose the admin application ports to the internet. Access is handled via the Tailscale infrastructure, and access is gated on Tailscale instead of locally in each application. Once this is enabled, you can disable authentication completely for the admin applciations, as they are only accessable via the Tailnet.

### Tailscale Based Server Example Setup:

-->Docker
    -Plex Media Server: https://app.plex.tv/desktop/#!/
    -Sonarr: http://172.30.0.10:8989
    -Radarr: http://172.30.0.11:7878
    -Prowlarr: http://172.30.0.12:9696
    -Tautulli: http://172.30.0.13:8181
    -ts-subnet-router
-->UFW
    -ALLOW: 32400 (Plex)
    -ALLOW: 22 (SSH)

BUT....

We have to use IP addresses and ports. Bleh! Thankfully, Tailscale has a great solution: Tailscale Serve can proxy internal IP requests to a DNS hostname. Additionally, while we reduced the amount of holes in our firewall from 6 --> 2, we can further decrease our attack posture by moving SSH onto the Tailnet too. 

### Tailscale Serve ENHANCED Server Example Setup:

-->Docker
    -Plex Media Server: https://app.plex.tv/desktop/#!/
    -Sonarr: https://app.your-tailnet.ts.net/sonarr/
    -Radarr: https://app.your-tailnet.ts.net/radarr/
    -Prowlarr: https://app.your-tailnet.ts.net/prowlarr/
    -Tautulli: https://app.your-tailnet.ts.net/tautulli/
    -ts-subnet-router
-->UFW
    -ALLOW: 32400 (Plex)
-->systemd
    -tailscaled.service

    
```mermaid
flowchart TD
    Start([User on MacBook opens browser]) --> Req[Request:<br/>https://apps.your-tailnet.ts.net/tautulli/]
    Req --> TS{MacBook<br/>on the tailnet?}

    TS -->|No| Fail1[Connection times out<br/>ERR_CONNECTION_TIMED_OUT<br/>DNS does not resolve;<br/>no route to 100.x.x.x]

    TS -->|Yes| DNS[MagicDNS resolves<br/>apps.your-tailnet.ts.net<br/>to subnet router's tailnet IP]
    DNS --> WG[MacBook initiates<br/>WireGuard tunnel to<br/>subnet router]
    WG --> ACL{Tailscale ACL:<br/>is this identity<br/>allowed to reach dst?}

    ACL -->|No| Fail2[WireGuard handshake refused<br/>Connection times out<br/>No HTTP layer reached;<br/>no block page]

    ACL -->|Yes| TLS[TLS handshake;<br/>Tailscale Serve auto-provisioned<br/>Let's Encrypt cert]
    TLS --> Route[Serve matches path /tautulli/<br/>and proxies to<br/>http://172.30.0.13:8181]
    Route --> App[Tautulli responds]
    App --> Done([Tautulli UI loads])

    classDef fail fill:#fee,stroke:#c66,color:#222
    classDef ok fill:#efe,stroke:#6c6,color:#222
    class Fail1,Fail2 fail
    class Done ok
```
[!TIP]If the user device is not on the tailnet, or they are not authorized to access the resource, they will experience a timeout. This is intentional and expected, as there is no need to let the user know the service is active if they are not authorized.

## Prerequisites

<!-- TODO:
- A Tailscale account (free tier is fine)
- A Linux host with Docker + Docker Compose
- An auth key from the Tailscale admin console
- Tailscale installed on at least one client device (your laptop)
-->

## Quick Start

```bash
# TODO: clone + env + up
git clone https://github.com/Logvin/secure-plex-with-tailscale.git
cd secure-plex-with-tailscale
cp .env.example .env
# Edit .env with your Tailscale auth key
docker compose up -d
```

## What's Running

<!-- TODO: short table of services.
| Service | Purpose | Reachable from |
|---|---|---|
| plex | media server | public (plex.tv account auth) |
| sonarr | TV management | tailnet only |
| radarr | movie management | tailnet only |
| prowlarr | indexer manager | tailnet only |
| ts-subnet-router | exposes private Docker network to tailnet | n/a |
| ts-ssh-sidecar | Tailscale SSH gateway for the host | tailnet only |
-->

## Accessing Your Stack

<!-- TODO:
- Public Plex: same as always, via plex.tv account or LAN IP
- Private *arr stack:
  - From any device on your tailnet
  - Hit the Docker container IPs (e.g. http://172.30.0.10:8989 for Sonarr)
  - OR set up MagicDNS entries / hosts file shortcuts
- Tailscale SSH:
  - tailscale ssh root@ts-ssh-sidecar
-->

## The ACL Policy

<!-- TODO: walk through acl.hujson and explain:
- groups (you, family, guests)
- tags (server-admin, plex-only)
- rules (who can reach what, on which ports)
- why this beats per-app basic auth -->

## Verifying the Security Boundary

<!-- TODO: the proof-it-works section.
- Show that the *arr admin UIs are NOT reachable from a device not on
  the tailnet (curl from outside times out)
- Show that they ARE reachable from a tailnet device
- Show that Plex still works for streaming from outside
- Optional: tcpdump or ss to prove ports aren't published to the host
-->

## How This Compares to Other Approaches

<!-- TODO: short, honest comparison table.
| Approach | Pro | Con |
|---|---|---|
| Reverse proxy + basic auth | Easy | Admin UIs still on public internet |
| Reverse proxy + OIDC (Authelia/Authentik) | Strong SSO | Public DNS exists; CVE in the *arr is still a CVE in your edge |
| Tailscale (this guide) | Removes services from public internet entirely; identity-based access | Requires Tailscale client on every device that needs access |
-->

## Teardown

```bash
docker compose down -v
# TODO: any cleanup beyond docker compose down
```

## License

MIT. See [LICENSE](LICENSE).

---

<!-- TODO: footer / author / link to Tailscale docs you found most useful -->
