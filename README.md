# warp-socks

An out-of-the-box SOCKS5 proxy powered by Cloudflare WARP, ready to run in Docker.

## Run

Requires Docker and WireGuard support in the host kernel.

```bash
docker run -d \
  --name warp-socks \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 1080:1080/tcp \
  -e USERNAME=warp \
  -e PASSWORD='your-password' \
  skylarklab/warp-socks:latest
```

Connect to `IP:1080` with username `warp` and your password.

To enable SOCKS5 UDP relay, also add these options before the image name:

```bash
-p 20000-20099:20000-20099/udp -e UDP_PUBLIC_IP=IP
```

Use the Docker host's IPv4 address reachable by your client. Allow the UDP port range through your firewall.

## Test

```bash
curl -x 'socks5h://USERNAME:PASSWORD@IP:1080' https://www.cloudflare.com/cdn-cgi/trace
```

Look for `warp=on` or `warp=plus` in the response to verify that this request went through WARP.

## Options

| Option | Description |
| --- | --- |
| `-e USERNAME=warp` | SOCKS5 username (default: `warp`) |
| `-e PASSWORD=your-password` | SOCKS5 password (required) |
| `-e LICENSE_KEY=your-key` | Enable WARP+ |
| `-e WARP_ENDPOINT=engage.cloudflareclient.com:1701` | Override the WARP endpoint |
| `-v warp-socks-data:/data` | Keep account and configuration across container replacements |

To use port `2080`, replace `-p 1080:1080/tcp` with `-p 2080:1080/tcp`.
Usernames and passwords must contain no whitespace and be at most 255 bytes each.

## License

MIT. Third-party components retain their own licenses.

On first run, WARP registration is automatic and includes acceptance of Cloudflare's terms of service.
