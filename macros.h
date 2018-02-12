#ifndef __MACROS_H__
#define __MACROS_H__

#define PTR_ADD(a, b) ((uint8_t*)((uint64_t)(a) + (uint64_t)(b)))
#define PTR_INC(a) { a = PTR_ADD(a, 1); }

#define PTR_GE(a, b) ((uint64_t)(a) >= (uint64_t)(b))
#define PTR_LT(a, b) ((uint64_t)(a) < (uint64_t)(b))

#endif
