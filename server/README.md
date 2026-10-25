# Ubuntu Docker host setup

One-off setup for a server that runs the dev containers. Do these by hand, from a
session that will not be cut off if a firewall change goes wrong (console access or a
second SSH session).

## 1. Base

- Ubuntu LTS, unattended security upgrades on.
- SSH: key-only (`PasswordAuthentication no`), no root login, source restricted to the
  internal subnet.
- Docker Engine from Docker's own apt repository (not the `docker.io` snap).
- `pwsh` (PowerShell 7), `gh`, and `az` with the `azure-devops` extension, for
  `bin/New-AgenticProject.ps1`.

## 2. Who can use Docker

Anyone in the `docker` group is effectively root on the server. Keep the group to the
people who would have sudo anyway. If other Systems Team members will share the server,
decide between that and rootless Docker per user. Note that `aos-egress.sh` filters
rootful Docker only; rootless Docker needs a different approach (owner-match rules in
the host OUTPUT chain).

## 3. Agent egress firewall

Containers on the `aos-agents` network can reach the internet but not the internal
network, except the hosts you list.

```bash
sudo cp aos-egress.default.example /etc/default/aos-egress   # then edit the allow list
sudo cp aos-egress.sh /usr/local/sbin/
sudo cp aos-egress.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now aos-egress
```

Check it from a throwaway container:

```bash
docker run --rm --network aos-agents curlimages/curl -sS -m 5 -o /dev/null -w '%{http_code}\n' https://api.anthropic.com   # expect a status code
docker run --rm --network aos-agents curlimages/curl -sS -m 5 http://<some internal host>     # expect a failure
```

Project dev containers join this network through `--network=aos-agents` in
`.devcontainer/devcontainer.json`; they will not start until the network exists.

Docker ignores `ufw` for published ports. Bind any published port to a specific
address (`127.0.0.1:4000:4000`), never bare `4000:4000`.

## 4. Per-user settings for the on-prem AI

The dev container reads these from your environment on the server. Put them in
`~/.profile` (the API key in a separate file only you can read):

```bash
export AOS_ONPREM_URL=https://<onprem-ai-host>
export AOS_ONPREM_MODEL=<model-id>        # optional
[ -r ~/.config/aos/onprem.env ] && . ~/.config/aos/onprem.env   # chmod 600; sets AOS_ONPREM_API_KEY
export AOS_ADO_ORG_URL=https://<org>.visualstudio.com
export AOS_ADO_PROJECT='Systems Team'
```

If the on-prem service uses a certificate from an internal CA, the container needs that
CA: add it to the image or set `NODE_EXTRA_CA_CERTS` to a mounted copy.

## 5. Optional: gVisor (phase 3)

Install `runsc`, register it as a Docker runtime, and add `"--runtime=runsc"` to the
dev container `runArgs`. Test first: some tools behave differently under gVisor.
