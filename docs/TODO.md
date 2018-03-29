
# Misc
- When assertions fail recurse down the expr and print values

- Allow contextual enum member lookup
turn:
    Mmap(nil, 4 * 1024 * 1024, prot: sys.Prot.READ | sys.Prot.WRITE, flags: sys.MapFlags.FILE | sys.MapFlags.SHARED, fd, offset: 0)

into:
    Mmap(nil, 4 * 1024 * 1024, prot: READ | WRITE, flags: FILE | SHARED, fd, offset: 0)

