
#include "include/shim.h"
//#include <Foundation/Foundation.h>

// flsl is only present on BSD derivitives.
int findLastSetBit(long value) {
    return 64 - __builtin_clzl(value);
}
