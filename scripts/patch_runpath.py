import struct, sys

path = sys.argv[1]
new = sys.argv[2].encode()

with open(path, 'rb') as f:
    data = bytearray(f.read())

assert data[0:4] == b'\x7fELF', "not an ELF"
is64 = data[4] == 2
le = data[5] == 1
endian = '<' if le else '>'
if is64:
    e_shoff = struct.unpack_from(endian + 'Q', data, 0x28)[0]
    e_shentsize = struct.unpack_from(endian + 'H', data, 0x3A)[0]
    e_shnum = struct.unpack_from(endian + 'H', data, 0x3C)[0]
    e_shstrndx = struct.unpack_from(endian + 'H', data, 0x3E)[0]
else:
    e_shoff = struct.unpack_from(endian + 'I', data, 0x20)[0]
    e_shentsize = struct.unpack_from(endian + 'H', data, 0x2E)[0]
    e_shnum = struct.unpack_from(endian + 'H', data, 0x30)[0]
    e_shstrndx = struct.unpack_from(endian + 'H', data, 0x32)[0]

def section(i):
    off = e_shoff + i * e_shentsize
    name = struct.unpack_from(endian + 'I', data, off)[0]
    stype = struct.unpack_from(endian + 'I', data, off + 4)[0]
    if is64:
        offset = struct.unpack_from(endian + 'Q', data, off + 0x18)[0]
        size = struct.unpack_from(endian + 'Q', data, off + 0x20)[0]
    else:
        offset = struct.unpack_from(endian + 'I', data, off + 0x10)[0]
        size = struct.unpack_from(endian + 'I', data, off + 0x14)[0]
    return name, stype, offset, size

def read_cstr(base, offset):
    end = data.index(b'\x00', base + offset)
    return data[base + offset:end].decode()

_, _, shstr_off, shstr_size = section(e_shstrndx)

dynstr_off = None
dynamic = None
for i in range(e_shnum):
    name, stype, off, size = section(i)
    sname = read_cstr(shstr_off, name)
    if sname == '.dynstr':
        dynstr_off = off
    if stype == 6:  # SHT_DYNAMIC
        dynamic = (off, size)

assert dynstr_off is not None and dynamic is not None, "dynstr/dynamic not found"
dyn_off, dyn_size = dynamic

if is64:
    DT_RUNPATH = 0x1d
    entsize = 16
    for j in range(0, dyn_size, entsize):
        tag = struct.unpack_from(endian + 'Q', data, dyn_off + j)[0]
        val = struct.unpack_from(endian + 'Q', data, dyn_off + j + 8)[0]
        if tag == DT_RUNPATH:
            old = read_cstr(dynstr_off, val)
            if new.decode() in old:
                print(f"RUNPATH already patched: {old!r}")
                sys.exit(0)
            if len(new) + 1 > len(old):
                print(f"cannot shrink: old={len(old)} new={len(new)}")
                sys.exit(1)
            data[dynstr_off + val : dynstr_off + val + len(old)] = new + b'\x00' + b'\x00' * (len(old) - len(new) - 1)
            with open(path, 'wb') as f:
                f.write(data)
            print(f"patched RUNPATH from {old!r} to {new.decode()!r}")
            sys.exit(0)
print("no RUNPATH found")
sys.exit(1)
