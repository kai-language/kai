#include <stdio.h>
#include <stdint.h>

typedef int	cpu_type_t;
typedef int	cpu_subtype_t;
typedef int vm_prot_t;

#define MH_MAGIC_64 0xfeedfacf /* the 64-bit mach magic number */
#define MH_CIGAM_64 0xcffaedfe /* NXSwapInt(MH_MAGIC_64) */

#define MH_OBJECT   0x1     /* relocatable object file */

#define MH_SUBSECTIONS_VIA_SYMBOLS 0x2000

#define CPU_TYPE_X86_64 0x1000007
#define CPU_TYPE_ARM64  0x100000c

#define CPU_SUBTYPE_I386_ALL 0x3
#define CPU_SUBTYPE_ARM_ALL  0x0
#define CPU_SUBTYPE_ARM_V8   0xD

#define	LC_SYMTAB	  0x2
#define	LC_DYSYMTAB	  0xb
#define LC_SEGMENT_64 0x19
#define LC_VERSION_MIN_MACOSX 0x24

struct mach_header_64 {
    uint32_t    magic;      /* mach magic number identifier */
    cpu_type_t  cputype;    /* cpu specifier */
    cpu_subtype_t   cpusubtype; /* machine specifier */
    uint32_t    filetype;   /* type of file */
    uint32_t    ncmds;      /* number of load commands */
    uint32_t    sizeofcmds; /* the size of all the load commands */
    uint32_t    flags;      /* flags */
    uint32_t    reserved;   /* reserved */
};

struct segment_command_64 { /* for 64-bit architectures */
	uint32_t	cmd;		/* LC_SEGMENT_64 */
	uint32_t	cmdsize;	/* includes sizeof section_64 structs */
	char		segname[16];	/* segment name */
	uint64_t	vmaddr;		/* memory address of this segment */
	uint64_t	vmsize;		/* memory size of this segment */
	uint64_t	fileoff;	/* file offset of this segment */
	uint64_t	filesize;	/* amount to map from the file */
	vm_prot_t	maxprot;	/* maximum VM protection */
	vm_prot_t	initprot;	/* initial VM protection */
	uint32_t	nsects;		/* number of sections in segment */
	uint32_t	flags;		/* flags */
};

struct section_64 { /* for 64-bit architectures */
    char		sectname[16];	/* name of this section */
    char		segname[16];	/* segment this section goes in */
    uint64_t	addr;		/* memory address of this section */
    uint64_t	size;		/* size in bytes of this section */
    uint32_t	offset;		/* file offset of this section */
    uint32_t	align;		/* section alignment (power of 2) */
    uint32_t	reloff;		/* file offset of relocation entries */
    uint32_t	nreloc;		/* number of relocation entries */
    uint32_t	flags;		/* flags (section type and attributes)*/
    uint32_t	reserved1;	/* reserved (for offset or index) */
    uint32_t	reserved2;	/* reserved (for count or sizeof) */
    uint32_t	reserved3;	/* reserved */
};

struct relocation_info {
    int32_t    r_address;
    uint32_t   r_symbolnum:24,
               r_pcrel:1,     /* was relocated pc relative already */
               r_length:2,    /* 0=byte, 1=word, 2=long, 3=quad */
               r_extern:1,    /* does not include value of sym referenced */
               r_type:4;    /* if not 0, machine specific relocation type */
};

enum reloc_type_x86_64 {
	X86_64_RELOC_UNSIGNED,		// for absolute addresses
	X86_64_RELOC_SIGNED,		// for signed 32-bit displacement
	X86_64_RELOC_BRANCH,		// a CALL/JMP instruction with 32-bit displacement
	X86_64_RELOC_GOT_LOAD,		// a MOVQ load of a GOT entry
	X86_64_RELOC_GOT,			// other GOT references
	X86_64_RELOC_SUBTRACTOR,	// must be followed by a X86_64_RELOC_UNSIGNED
	X86_64_RELOC_SIGNED_1,		// for signed 32-bit displacement with a -1 addend
	X86_64_RELOC_SIGNED_2,		// for signed 32-bit displacement with a -2 addend
	X86_64_RELOC_SIGNED_4,		// for signed 32-bit displacement with a -4 addend
	X86_64_RELOC_TLV,		// for thread local variables
};

enum reloc_type_arm64 {
    ARM64_RELOC_UNSIGNED,	  // for pointers
    ARM64_RELOC_SUBTRACTOR,       // must be followed by a ARM64_RELOC_UNSIGNED
    ARM64_RELOC_BRANCH26,         // a B/BL instruction with 26-bit displacement
    ARM64_RELOC_PAGE21,           // pc-rel distance to page of target
    ARM64_RELOC_PAGEOFF12,        // offset within page, scaled by r_length
    ARM64_RELOC_GOT_LOAD_PAGE21,  // pc-rel distance to page of GOT slot
    ARM64_RELOC_GOT_LOAD_PAGEOFF12, // offset within page of GOT slot,
                                    //  scaled by r_length
    ARM64_RELOC_POINTER_TO_GOT,   // for pointers to GOT slots
    ARM64_RELOC_TLVP_LOAD_PAGE21, // pc-rel distance to page of TLVP slot
    ARM64_RELOC_TLVP_LOAD_PAGEOFF12, // offset within page of TLVP slot,
                                     //  scaled by r_length
    ARM64_RELOC_ADDEND		  // must be followed by PAGE21 or PAGEOFF12
};
struct version_min_command {
    uint32_t	cmd;		/* LC_VERSION_MIN_MACOSX */
    uint32_t	cmdsize;	/* sizeof(struct min_version_command) */
    uint32_t	version;	/* X.Y.Z is encoded in nibbles xxxx.yy.zz */
    uint32_t	sdk;		/* X.Y.Z is encoded in nibbles xxxx.yy.zz */
};

struct symtab_command {
	uint32_t	cmd;		/* LC_SYMTAB */
	uint32_t	cmdsize;	/* sizeof(struct symtab_command) */
	uint32_t	symoff;		/* symbol table offset */
	uint32_t	nsyms;		/* number of symbol table entries */
	uint32_t	stroff;		/* string table offset */
	uint32_t	strsize;	/* string table size in bytes */
};

struct nlist_64 {
    union {
        uint32_t  n_strx; /* index into the string table */
    } n_un;
    uint8_t n_type;        /* type flag, see below */
    uint8_t n_sect;        /* section number or NO_SECT */
    uint16_t n_desc;       /* see <mach-o/stab.h> */
    uint64_t n_value;      /* value of this symbol (or stab offset) */
};

struct dysymtab_command {
    uint32_t cmd;	/* LC_DYSYMTAB */
    uint32_t cmdsize;	/* sizeof(struct dysymtab_command) */
    uint32_t ilocalsym;	/* index to local symbols */
    uint32_t nlocalsym;	/* number of local symbols */
    uint32_t iextdefsym;/* index to externally defined symbols */
    uint32_t nextdefsym;/* number of externally defined symbols */
    uint32_t iundefsym;	/* index to undefined symbols */
    uint32_t nundefsym;	/* number of undefined symbols */
    uint32_t tocoff;	/* file offset to table of contents */
    uint32_t ntoc;	/* number of entries in table of contents */
    uint32_t modtaboff;	/* file offset to module table */
    uint32_t nmodtab;	/* number of module table entries */
    uint32_t extrefsymoff;	/* offset to referenced symbol table */
    uint32_t nextrefsyms;	/* number of referenced symbol table entries */
    uint32_t indirectsymoff; /* file offset to the indirect symbol table */
    uint32_t nindirectsyms;  /* number of indirect symbol table entries */
    uint32_t extreloff;	/* offset to external relocation entries */
    uint32_t nextrel;	/* number of external relocation entries */
    uint32_t locreloff;	/* offset to local relocation entries */
    uint32_t nlocrel;	/* number of local relocation entries */
};	

#define	N_TYPE	0x0e  /* mask for the type bits */
#define	N_EXT	0x01  /* external symbol bit, set for external symbols */

#define	N_UNDF	0x0		/* undefined, n_sect == NO_SECT */

#define	NO_SECT		0	/* symbol is not in any section */

#define	S_ZEROFILL               0x00000001
#define S_ATTR_PURE_INSTRUCTIONS 0x80000000
#define S_ATTR_SOME_INSTRUCTIONS 0x00000400

#define	SEG_PAGEZERO	"__PAGEZERO"	/* the pagezero segment which has no */

#define	SEG_TEXT	"__TEXT"	/* the tradition UNIX text segment */
#define	SECT_TEXT	"__text"	/* the real text part of the text */

#define	SEG_DATA	"__DATA"	/* the tradition UNIX data segment */
#define	SECT_DATA	"__data"	/* the real initialized data section */
					/* no padding, no bss overlap */
#define	SECT_BSS	"__bss"		/* the real uninitialized data section*/
					/* no padding */
#define SECT_COMMON	"__common"	/* the section common symbols are */


int main() {
    struct mach_header_64 header;
    header.magic = MH_MAGIC_64;
    header.cputype = CPU_TYPE_X86_64;
    header.cpusubtype = CPU_SUBTYPE_I386_ALL;
    header.flags = ;
    return 0;
}
