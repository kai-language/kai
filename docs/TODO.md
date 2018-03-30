
# Misc
- When assertions fail recurse down the expr and print values

- Allow contextual enum member lookup
turn:
    Mmap(nil, 4 * 1024 * 1024, prot: sys.Prot.READ | sys.Prot.WRITE, flags: sys.MapFlags.FILE | sys.MapFlags.SHARED, fd, offset: 0)

into:
    Mmap(nil, 4 * 1024 * 1024, prot: READ | WRITE, flags: FILE | SHARED, fd, offset: 0)

- improve error for invoking on incorrect file 
    ERROR: print.kaik was invalid!


# Types Package
- Emit a generated file for reference to
- For the types package use enum #flags for the flags member
- Flag to indicate explicit backing type on Enum & for enum #flags
