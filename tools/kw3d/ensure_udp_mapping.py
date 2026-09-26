from __future__ import annotations
import argparse, json, socket, time, urllib.request, urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime, timezone

PORT = 18886
ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "updates_site" / "kw" / "online_config.json"

def local_ipv4() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

def discover_location() -> str:
    msg = "\r\n".join([
        "M-SEARCH * HTTP/1.1",
        "HOST: 239.255.255.250:1900",
        'MAN: "ssdp:discover"',
        "MX: 2",
        "ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1",
        "", ""
    ]).encode()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    s.settimeout(3.0)
    try:
        s.sendto(msg, ("239.255.255.250", 1900))
        while True:
            data, _ = s.recvfrom(65535)
            for line in data.decode(errors="ignore").split("\r\n"):
                if line.lower().startswith("location:"):
                    return line.split(":", 1)[1].strip()
    except socket.timeout:
        raise RuntimeError("No UPnP InternetGatewayDevice discovered")
    finally:
        s.close()

def find_service(location: str) -> tuple[str, str]:
    raw = urllib.request.urlopen(location, timeout=5).read()
    root = ET.fromstring(raw)
    base = root.findtext(".//{*}URLBase") or location
    for svc in root.findall(".//{*}service"):
        service_type = svc.findtext("{*}serviceType") or ""
        if "WANIPConnection" not in service_type and "WANPPPConnection" not in service_type:
            continue
        control_url = svc.findtext("{*}controlURL")
        if control_url:
            return service_type, urllib.parse.urljoin(base, control_url)
    raise RuntimeError("No WANIPConnection/WANPPPConnection service found")

def soap(service_type: str, control_url: str, action: str, args: dict[str, str]) -> str:
    body = [
        '<?xml version="1.0"?>',
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">',
        "<s:Body>", f'<u:{action} xmlns:u="{service_type}">'
    ]
    body += [f"<{k}>{v}</{k}>" for k, v in args.items()]
    body += [f"</u:{action}>", "</s:Body>", "</s:Envelope>"]
    req = urllib.request.Request(control_url, data="".join(body).encode(), method="POST")
    req.add_header("Content-Type", 'text/xml; charset="utf-8"')
    req.add_header("SOAPAction", f'"{service_type}#{action}"')
    return urllib.request.urlopen(req, timeout=6).read().decode(errors="ignore")

def external_ip(service_type: str, control_url: str) -> str:
    raw = soap(service_type, control_url, "GetExternalIPAddress", {})
    root = ET.fromstring(raw)
    for node in root.iter():
        if node.tag.split("}", 1)[-1] == "NewExternalIPAddress":
            return (node.text or "").strip()
    raise RuntimeError("Router did not return an external IP")

def ensure_mapping() -> dict[str, object]:
    lan_ip = local_ipv4()
    location = discover_location()
    service_type, control_url = find_service(location)
    public_ip = external_ip(service_type, control_url)
    args = {
        "NewRemoteHost": "",
        "NewExternalPort": str(PORT),
        "NewProtocol": "UDP",
        "NewInternalPort": str(PORT),
        "NewInternalClient": lan_ip,
        "NewEnabled": "1",
        "NewPortMappingDescription": "KW UDP Server",
        "NewLeaseDuration": "0",
    }
    soap(service_type, control_url, "AddPortMapping", args)
    query = soap(service_type, control_url, "GetSpecificPortMappingEntry", {
        "NewRemoteHost": "", "NewExternalPort": str(PORT), "NewProtocol": "UDP"
    })
    if lan_ip not in query or f"<NewInternalPort>{PORT}</NewInternalPort>" not in query:
        raise RuntimeError("Router did not confirm KW UDP mapping")
    config: dict[str, object] = {}
    if CONFIG_PATH.exists():
        try:
            config = json.loads(CONFIG_PATH.read_text(encoding="utf-8-sig"))
        except Exception:
            config = {}
    config.update({
        "game_transport": "enet_udp",
        "game_udp_host": public_ip,
        "game_udp_port": PORT,
        "game_lan_host": lan_ip,
        "mode": "direct_udp_gameplay",
        "updated": datetime.now(timezone.utc).astimezone().isoformat(),
    })
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    result = {"public_ip": public_ip, "lan_ip": lan_ip, "port": PORT, "mapping": True}
    print("KW_UDP_MAPPING", json.dumps(result))
    return result

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--watch", type=int, default=0, help="Renew mapping every N seconds")
    args = ap.parse_args()
    if args.watch <= 0:
        ensure_mapping()
        return 0
    while True:
        try:
            ensure_mapping()
            delay = max(300, args.watch)
        except Exception as exc:
            print("KW_UDP_MAPPING_ERROR", repr(exc), flush=True)
            delay = 60
        time.sleep(delay)

if __name__ == "__main__":
    raise SystemExit(main())
