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


def parse_cidrs(raw: str) -> list[str]:
    """Split comma/semicolon lists of CIDRs; empty parts dropped."""
    if not raw:
        return []
    return [part.strip() for part in raw.replace(";", ",").split(",") if part.strip()]


def primary_cidr(raw: str, fallback: str = "192.168.10.0/24") -> str:
    found = parse_cidrs(raw)
    return found[0] if found else fallback


def cidr_gateway(cidr: str) -> str:
    """Convention: .1 is the router on a /24-style net."""
    base_ip = cidr.split("/", 1)[0].strip()
    prefix = base_ip.rsplit(".", 1)[0]
    return f"{prefix}.1"


def wg_host_ips(network: str) -> tuple[str, str, str]:
    """Router / phone / optional PC addresses inside a /24-style WG net."""
    cidr = primary_cidr(network, "10.13.13.0/24")
    gw = cidr_gateway(cidr)
    prefix = gw.rsplit(".", 1)[0]
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
        host = self.pc_lan_ip.strip() or "192.168.10.1"
        return f"http://{host}:8080"

    @property
    def endpoint_host(self) -> str:
        return self.endpoint.strip() or "WAN-IP-OR-DDNS"


def build_mikrotik_script(bundle: WireGuardBundle) -> str:
    """Idempotent overlay for hAP ax S (LAN-interfaces / WAN-interfaces).

    Does not touch Wi-Fi, DHCP, CAKE or existing filter policy except inserting
    the WG handshake accept immediately before ``INPUT drop WAN``.
    """
    peer_adds = [
        f'/interface wireguard peers add interface=$wgName public-key="{bundle.phone_public_key}" '
        f'allowed-address={bundle.phone_ip}/32 comment="{_safe_name(bundle.phone_name)}"'
    ]
    if bundle.generate_pc_peer and bundle.pc_public_key:
        peer_adds.append(
            f'/interface wireguard peers add interface=$wgName public-key="{bundle.pc_public_key}" '
            f'allowed-address={bundle.pc_wg_ip}/32 comment="almanac-pc"'
        )
    peer_block = "\n".join(peer_adds)
    lan_nets = ", ".join(parse_cidrs(bundle.lan_cidr) or ["192.168.10.0/24"])
    return f"""# Almanac WireGuard overlay — hAP ax S / RouterOS 7
# Вставить в Terminal (WinBox). Можно повторять: ключи и порт обновятся.
# Не публиковать TCP 8080 на WAN — с улицы только UDP {bundle.wg_port}.
# LAN, в которые пускаем телефон: {lan_nets}

:local wgName "wg-almanac"
:local wgPort {bundle.wg_port}
:local wgAddr "{bundle.router_ip}/24"

/interface wireguard
:if ([:len [find name=$wgName]] = 0) do={{
  add name=$wgName listen-port=$wgPort private-key="{bundle.mikrotik_private_key}" comment="Almanac home lab"
}} else={{
  set [find name=$wgName] listen-port=$wgPort private-key="{bundle.mikrotik_private_key}" comment="Almanac home lab"
}}

/ip address
:if ([:len [find where interface=$wgName and comment="Almanac WG"]] = 0) do={{
  add address=$wgAddr interface=$wgName comment="Almanac WG"
}} else={{
  set [find where interface=$wgName and comment="Almanac WG"] address=$wgAddr
}}

:foreach lst in={{"LAN-interfaces";"LAN"}} do={{
  :if ([:len [/interface list find name=$lst]] > 0) do={{
    :if ([:len [/interface list member find where list=$lst and interface=$wgName]] = 0) do={{
      /interface list member add list=$lst interface=$wgName comment="Almanac WG"
    }}
  }}
}}

:local wanList ""
:if ([:len [/interface list find name="WAN-interfaces"]] > 0) do={{ :set wanList "WAN-interfaces" }}
:if ($wanList = "" && [:len [/interface list find name="WAN"]] > 0) do={{ :set wanList "WAN" }}

/ip firewall filter
:if ([:len [find where comment="Almanac WG handshake"]] = 0) do={{
  :local dropWan [find where comment="INPUT drop WAN"]
  :if ([:len $dropWan] > 0) do={{
    :if ($wanList != "") do={{
      add chain=input action=accept protocol=udp dst-port=$wgPort in-interface-list=$wanList comment="Almanac WG handshake" place-before=$dropWan
    }} else={{
      add chain=input action=accept protocol=udp dst-port=$wgPort comment="Almanac WG handshake" place-before=$dropWan
    }}
  }} else={{
    :if ($wanList != "") do={{
      add chain=input action=accept protocol=udp dst-port=$wgPort in-interface-list=$wanList comment="Almanac WG handshake" place-before=0
    }} else={{
      add chain=input action=accept protocol=udp dst-port=$wgPort comment="Almanac WG handshake" place-before=0
    }}
  }}
}} else={{
  set [find where comment="Almanac WG handshake"] dst-port=$wgPort
}}

/interface wireguard peers
:foreach p in=[find interface=$wgName] do={{ remove $p }}
{peer_block}
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
    nets = parse_cidrs(wg_network) + parse_cidrs(lan_cidr)
    allowed = ", ".join(nets)
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
    dns = cidr_gateway(primary_cidr(bundle.lan_cidr))
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
