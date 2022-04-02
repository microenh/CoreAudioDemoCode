//
//  CARingBufferMisc.h
//  CARingBuffer
//
//  Created by Mark Erbaugh on 3/23/22.
//  Copyright © 2022 WaveLabs. All rights reserved.
//

// Routines from CAAutoDispaser.h, CAAtomic.h & CABitOperations.h needed for CARingBuffer to compile

#ifndef CARingBufferMisc_h
#define CARingBufferMisc_h

#include <stdlib.h>       // for malloc
#include <new>            // for bad_alloc

#if TARGET_OS_WIN32
    #include <windows.h>
    #include <intrin.h>
    #pragma intrinsic(_InterlockedOr)
    #pragma intrinsic(_InterlockedAnd)
#else
    #include <CoreFoundation/CFBase.h>
#endif

// MARK: - code from other header files
// from CAAutoDisposer.h
inline void* CA_malloc(size_t size)
{
    void* p = malloc(size);
    if (!p && size) throw std::bad_alloc();
    return p;
}

// from CABitOperations.h
// count the leading zeros in a word
// Metrowerks Codewarrior. powerpc native count leading zeros instruction:
// I think it's safe to remove this ...
//#define CountLeadingZeroes(x)  ((int)__cntlzw((unsigned int)x))

inline UInt32 CountLeadingZeroes(UInt32 arg)
{
// GNUC / LLVM have a builtin
#if defined(__GNUC__) || defined(__llvm___)
#if (TARGET_CPU_X86 || TARGET_CPU_X86_64)
    if (arg == 0) return 32;
#endif    // TARGET_CPU_X86 || TARGET_CPU_X86_64
    return __builtin_clz(arg);
#elif TARGET_OS_WIN32
    UInt32 tmp;
    __asm{
        bsr eax, arg
        mov ecx, 63
        cmovz eax, ecx
        xor eax, 31
        mov tmp, eax    // this moves the result in tmp to return.
    }
    return tmp;
#else
#error "Unsupported architecture"
#endif    // defined(__GNUC__)
}

// base 2 log of next power of two greater or equal to x
inline UInt32 Log2Ceil(UInt32 x)
{
    return 32 - CountLeadingZeroes(x - 1);
}

// next power of two greater or equal to x
inline UInt32 NextPowerOfTwo(UInt32 x)
{
    return 1 << Log2Ceil(x);
}


#endif /* CARingBufferMisc_h */
