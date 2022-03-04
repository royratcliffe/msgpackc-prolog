#include <SWI-Prolog.h>
#include <SWI-Stream.h>
#include <stdint.h>

/*
 * Gets a list of bytes from a list of byte codes by byte count. Fails
 * if the byte list reaches nil _before_ reading all the bytes.
 *
 * Fails if it sees integer byte values outside the acceptable range,
 * zero through 255 inclusive. Failure always updates the given byte
 * buffer with the value of the bytes successfully seen.
 */
int
get_list_bytes(term_t Bytes0, term_t Bytes, size_t count, uint8_t *bytes)
{ term_t Tail = PL_copy_term_ref(Bytes0);
  term_t Byte = PL_new_term_ref();
  while (count--)
  { int value;
    if (!PL_get_list(Tail, Byte, Tail) ||
        !PL_get_integer(Byte, &value) || value < 0 || value > 255) PL_fail;
    *bytes++ = value;
  }
  return PL_unify(Bytes, Tail);
}

/*
 * Relies on the compiler to correctly expand an eight-bit byte to a
 * signed integer _without_ performing sign extension.
 */
int
unify_list_bytes(term_t Bytes0, term_t Bytes, size_t count, const uint8_t *bytes)
{ term_t Tail = PL_copy_term_ref(Bytes0);
  term_t Byte = PL_new_term_ref();
  while (count--)
    if (!PL_unify_list(Tail, Byte, Tail) || !PL_unify_integer(Byte, *bytes++)) PL_fail;
  return PL_unify(Bytes, Tail);
}

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__

/*
 * Rolls 16 bits by eight bits left. Same as eight bits right. The
 * argument name comprises one `x` for each byte, or octet.
 *
 * 89 c8                mov    %ecx,%eax
 * 66 c1 c0 08          rol    $0x8,%ax
 * c3                   ret
 */
uint16_t
be16(uint16_t xx)
{ return xx << 8 | xx >> 8;
}

/*
 * Byte swaps 32 bits.
 *
 * 89 c8                mov    %ecx,%eax
 * 0f c8                bswap  %eax
 * c3                   ret
 */
uint32_t
be32(uint32_t xxxx)
{ return (uint32_t)be16(xxxx) << 16 | be16(xxxx >> 16);
}

/*
 * Byte swaps 64 bits.
 *
 * 48 89 c8             mov    %rcx,%rax
 * 48 0f c8             bswap  %rax
 * c3                   ret
 */
uint64_t
be64(uint64_t xxxxxxxx)
{ return (uint64_t)be32(xxxxxxxx) << 32 | be32(xxxxxxxx >> 32);
}

#else

uint16_t
be16(uint16_t xx)
{ return xx;
}

uint32_t
be32(uint32_t xxxx)
{ return xxxx;
}

uint64_t
be64(uint64_t xxxxxxxx)
{ return xxxxxxxx;
}

#endif

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Important to realise that unsigned long is not always 32-bits wide. On some machines and operating systems, any `long` is 64-bits wide. Same goes for float; some platforms make them identical to doubles.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

union xx
{ uint16_t value;
  uint8_t bytes[sizeof(uint16_t)];
};

union xxxx
{ uint32_t value;
  uint8_t bytes[sizeof(uint32_t)];
};

union xxxxxxxx
{ uint64_t value;
  uint8_t bytes[sizeof(uint64_t)];
};

/*
 * Performs the C equivalent of a C++ reinterpret cast from 32-bit
 * unsigned integer to 32-bit float. Temporarily takes the address of a
 * stack-passed integer, recasts the pointer's target and indirects to
 * the recasting. The compiler optimiser obviates all the indirection.
 * The result is just a register-register move operation.
 *
 * 66 0f 6e c1          movd   %ecx,%xmm0
 * c3                   ret
 */
float
reinterpret_to_float32(uint32_t xxxx)
{ return *(float *)&xxxx;
}

uint32_t
reinterpret_from_float32(float xxxx)
{ return *(uint32_t *)&xxxx;
}

double
reinterpret_to_float64(uint64_t xxxxxxxx)
{ return *(double *)&xxxxxxxx;
}

uint64_t
reinterpret_from_float64(double xxxxxxxx)
{ return *(uint64_t *)&xxxxxxxx;
}

foreign_t
float32_3(term_t Number, term_t Bytes0, term_t Bytes)
{ union xxxx raw;
  if (PL_is_variable(Number))
  { if (!get_list_bytes(Bytes0, Bytes, sizeof(raw.bytes), raw.bytes)) PL_fail;
    return PL_unify_float(Number, reinterpret_to_float32(be32(raw.value)));
  } else
  { double value;
    if (!PL_get_float(Number, &value)) PL_fail;
    raw.value = be32(reinterpret_from_float32(value));
    return unify_list_bytes(Bytes0, Bytes, sizeof(raw.bytes), raw.bytes);
  }
}

foreign_t
float64_3(term_t Number, term_t Bytes0, term_t Bytes)
{ union xxxxxxxx raw;
  if (PL_is_variable(Number))
  { if (!get_list_bytes(Bytes0, Bytes, sizeof(raw.bytes), raw.bytes)) PL_fail;
    return PL_unify_float(Number, reinterpret_to_float64(be64(raw.value)));
  } else
  { double value;
    if (!PL_get_float(Number, &value)) PL_fail;
    raw.value = be64(reinterpret_from_float64(value));
    return unify_list_bytes(Bytes0, Bytes, sizeof(raw.bytes), raw.bytes);
  }
}

install_t install_msgpackc()
{ PL_register_foreign("float32", 3, float32_3, 0);
  PL_register_foreign("float64", 3, float64_3, 0);
}

install_t uninstall_msgpackc()
{ ;
}
