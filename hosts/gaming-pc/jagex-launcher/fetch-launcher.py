# Rebuilds the official Jagex Launcher from Jagex's CDN, the same files its Windows installer
# downloads. Every piece is checked against the sha256 digests in Jagex's metafile.
import base64, gzip, hashlib, json, os, sys, urllib.request

cdn = "https://jagex.akamaized.net/direct6/launcher-win"
metafile_id, out = sys.argv[1], sys.argv[2]

def get(url):
    with urllib.request.urlopen(url) as r:
        return r.read()

meta = json.loads(get(f"{cdn}/metafile/{metafile_id}/metafile.json"))
data = bytearray()
for d in meta["pieces"]["digests"]:
    digest = base64.b64decode(d).hex()
    # 6-byte header, then gzip data (or stored as-is when compression wouldn't help)
    piece = get(f"{cdn}/pieces/{digest[:2]}/{digest}.solidpiece")[6:]
    if piece[:2] == b"\x1f\x8b":
        piece = gzip.decompress(piece)
    if hashlib.sha256(piece).hexdigest() != digest:
        sys.exit(f"piece {digest} failed its checksum")
    data += piece

pos = 0
for f in meta["files"]:
    path = os.path.join(out, f["name"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data[pos : pos + f["size"]])
    pos += f["size"]
