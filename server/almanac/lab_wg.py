"""WireGuard keypairs and MikroTik / phone configs for the home-lab helper."""

from __future__ import annotations

import base64
import secrets
from dataclasses import dataclass

# RFC 7748 Curve25519 field prime.
_P = 2**255 - 19
_A24 = 121665
_BASE_U = b"\x09" + b"\x00" * 31


def _cswap(swap: int, x: int, y: int) -> tuple[int, int]:
    mask = -swap
    dummy = mask & (x ^ y)
    return x ^ dummy, y ^ dummy


def x25519(scalar: bytes, u_coord: bytes) -> bytes:
    """X25519(k, u) as in RFC 7748."""
    k = bytearray(scalar)
    k[0] &= 248
    k[31] &= 127
    k[31] |= 64
    n = int.from_bytes(k, "little")

    u = bytearray(u_coord)
    u[31] &= 127
    x1 = int.from_bytes(u, "little") % _P

    x2, z2 = 1, 0
    x3, z3 = x1, 1
    swap = 0
    for t in range(254, -1, -1):
        kt = (n >> t) & 1
        swap ^= kt
        x2, x3 = _cswap(swap, x2, x3)
        z2, z3 = _cswap(swap, z2, z3)
        swap = kt
        a = (x2 + z2) % _P
        aa = (a * a) % _P
        b = (x2 - z2) % _P
        bb = (b * b) % _P
        e = (aa - bb) % _P
        c = (x3 + z3) % _P
        d = (x3 - z3) % _P
        da = (d * a) % _P
        cb = (c * b) % _P
        x3 = pow((da + cb) % _P, 2, _P)
        z3 = (x1 * pow((da - cb) % _P, 2, _P)) % _P
        x2 = (aa * bb) % _P
        z2 = (e * ((aa + _A24 * e) % _P)) % _P
    x2, x3 = _cswap(swap, x2, x3)
    z2, z3 = _cswap(swap, z2, z3)
    return ((x2 * pow(z2, _P - 2, _P)) % _P).to_bytes(32, "little")


def _b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode("ascii")


def generate_keypair() -> tuple[str, str]:
    """Return (private_base64, public_base64) in WireGuard format."""
    raw = bytearray(secrets.token_bytes(32))
    raw[0] &= 248
    raw[31] &= 127
    raw[31] |= 64
    private = bytes(raw)
    public = x25519(private, _BASE_U)
    return _b64(private), _b64(public)


def public_key_from_private(private_b64: str) -> str:
    private = base64.b64decode(private_b64)
    if len(private) != 32:
        raise ValueError("WireGuard private key must be 32 bytes")
    return _b64(x25519(private, _BASE_U))


def wg_host_ips(network: str) -> tuple[str, str, str]:
    """Router / phone / optional PC addresses inside a /24-style WG net."""
    cidr = network.strip() or "10.13.13.0/24"
    base_ip = cidr.split("/", 1)[0]
    prefix = base_ip.rsplit(".", 1)[0]
    return f"{prefix}.1", f"{prefix}.2", f"{prefix}.3"


@dataclass(frozen=True)
class WireGuardBundle:
    endpoint: str
    wg_port: int
    wg_network: str
    lan_cidr: str
    pc_lan_ip: str
    phone_name: str
    mikrotik_private_key: str
    mikrotik_public_key: str
    phone_private_key: str
    phone_public_key: str
    pc_private_key: str = ""
    pc_public_key: str = ""
    generate_pc_peer: bool = False

    @property
    def router_ip(self) -> str:
        return wg_host_ips(self.wg_network)[0]

    @property
    def phone_ip(self) -> str:
        return wg_host_ips(self.wg_network)[1]

    @property
    def pc_wg_ip(self) -> str:
        return wg_host_ips(self.wg_network)[2]

    @property
    def server_url(self) -> str:
        host = self.pc_lan_ip.strip() or "192.168.88.1"
        return f"http://{host}:8080"

    @property
    def endpoint_host(self) -> str:
        return self.endpoint.strip() or "WAN-IP-OR-DDNS"


def build_mikrotik_script(bundle: WireGuardBundle) -> str:
    peers = [
        f'/interface wireguard peers add interface=wg-almanac '
        f'public-key="{bundle.phone_public_key}" allowed-address={bundle.phone_ip}/32 '
        f'comment="{_safe_name(bundle.phone_name)}"'
    ]
    if bundle.generate_pc_peer and bundle.pc_public_key:
        peers.append(
            f'/interface wireguard peers add interface=wg-almanac '
            f'public-key="{bundle.pc_public_key}" allowed-address={bundle.pc_wg_ip}/32 '
            f'comment="almanac-pc"'
        )
    peer_block = "\n".join(peers)
    return f"""# Almanac + WireGuard on MikroTik (RouterOS 7)
# Paste in Terminal. Do not publish 8080 on WAN — only UDP {bundle.wg_port}.

/interface wireguard add name=wg-almanac listen-port={bundle.wg_port} private-key="{bundle.mikrotik_private_key}"
/ip address add address={bundle.router_ip}/24 interface=wg-almanac

{peer_block}

/ip firewall filter add chain=input action=accept protocol=udp dst-port={bundle.wg_port} comment="WG Almanac" place-before=0
/ip firewall filter add chain=forward action=accept in-interface=wg-almanac comment="WG Almanac to LAN"
/ip firewall filter add chain=forward action=accept out-interface=wg-almanac comment="LAN to WG Almanac"
"""


def build_client_conf(
    *,
    private_key: str,
    address: str,
    server_public_key: str,
    endpoint_host: str,
    wg_port: int,
    lan_cidr: str,
    wg_network: str,
    dns: str,
) -> str:
    allowed = f"{wg_network}, {lan_cidr}".strip(", ")
    return f"""[Interface]
PrivateKey = {private_key}
Address = {address}/32
DNS = {dns}

[Peer]
PublicKey = {server_public_key}
Endpoint = {endpoint_host}:{wg_port}
AllowedIPs = {allowed}
PersistentKeepalive = 25
"""


def build_phone_conf(bundle: WireGuardBundle) -> str:
    dns = wg_host_ips(bundle.lan_cidr)[0]
    return build_client_conf(
        private_key=bundle.phone_private_key,
        address=bundle.phone_ip,
        server_public_key=bundle.mikrotik_public_key,
        endpoint_host=bundle.endpoint_host,
        wg_port=bundle.wg_port,
        lan_cidr=bundle.lan_cidr,
        wg_network=bundle.wg_network,
        dns=dns,
    )


def build_pc_conf(bundle: WireGuardBundle) -> str:
    return build_client_conf(
        private_key=bundle.pc_private_key,
        address=bundle.pc_wg_ip,
        server_public_key=bundle.mikrotik_public_key,
        endpoint_host=bundle.endpoint_host,
        wg_port=bundle.wg_port,
        lan_cidr=bundle.lan_cidr,
        wg_network=bundle.wg_network,
        dns=bundle.router_ip,
    )


def _safe_name(value: str) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in "-_" else "-" for ch in value.strip())
    return cleaned[:32] or "phone"
