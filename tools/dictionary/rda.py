"""Minimal reader for R .rda files holding character vectors (XDR format)."""
import lzma, struct, sys

def read_rda(path):
    raw = lzma.open(path).read()
    assert raw[:5] == b"RDX2\n" or raw[:5] == b"RDX3\n", raw[:5]
    buf = raw[5:]
    assert buf[:2] == b"X\n"
    pos = 2
    def i32():
        nonlocal pos
        v = struct.unpack(">i", buf[pos:pos+4])[0]; pos += 4; return v
    version = i32(); i32(); i32()
    if version == 3:
        n = i32(); pos += n
    out = {}
    def item():
        nonlocal pos
        flags = i32()
        t = flags & 0xFF
        has_attr = flags & (1 << 9)
        has_tag = flags & (1 << 10)
        if t == 254: return None  # NILVALUE
        if t == 2:  # LISTSXP pairlist
            attr = item() if has_attr else None
            tag = item() if has_tag else None
            car = item(); cdr = item()
            return ("pair", tag, car, cdr)
        if t == 1:  # SYMSXP
            return ("sym", item())
        if t == 9:  # CHARSXP
            n = i32()
            if n == -1: return None
            s = buf[pos:pos+n]; pos += n
            return s.decode("utf-8", "replace")
        if t == 16:  # STRSXP
            n = i32(); v = [item() for _ in range(n)]
            if has_attr: item()
            return v
        if t in (13, 14, 10):
            n = i32(); size = 4 if t != 14 else 8
            pos += n * size
            if has_attr: item()
            return None
        if t == 255:  # REFSXP
            return ("ref",)
        raise ValueError(f"type {t} at {pos}")
    node = item()
    while node and node[0] == "pair":
        _, tag, car, cdr = node
        name = tag[1] if tag and tag[0] == "sym" else tag
        out[name] = car
        node = cdr
    return out

if __name__ == "__main__":
    d = read_rda(sys.argv[1])
    for k, v in d.items():
        print(k, type(v), len(v) if v else None, v[:5] if isinstance(v, list) else v)
