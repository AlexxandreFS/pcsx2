set(gcc7_mmx_code "
#include <stdio.h>
#include <stdint.h>
#include <xmmintrin.h>
#include <emmintrin.h>

class alignas(16) GSVector4i
{
public:
    __m128i m;

	explicit GSVector4i(__m128i m)
	{
		this->m = m;
	}

	static void storel(void* p, const GSVector4i& v)
	{
		_mm_storel_epi64((__m128i*)p, v.m);
	}

	static GSVector4i loadl(const void* p)
	{
		return GSVector4i(_mm_loadl_epi64((__m128i*)p));
	}

	bool eq(const GSVector4i& v) const
	{
		return _mm_movemask_epi8(_mm_cmpeq_epi32(m, v.m)) == 0xffff;
	}
};


union GIFRegTRXPOS
{
	unsigned long long u64;
	void operator = (const GSVector4i& v) {GSVector4i::storel(this, v);}
	bool operator != (const union GIFRegTRXPOS& r) const {return !((GSVector4i)r).eq(*this);}
	operator GSVector4i() const {return GSVector4i::loadl(this);}
};

extern GIFRegTRXPOS	TRXPOS;
GIFRegTRXPOS TRXPOS = {};

void GIFRegHandlerTRXPOS(const GIFRegTRXPOS&  p)
{
	if(p != TRXPOS)
	{
        printf(\"foo\");
	}

	TRXPOS = (GSVector4i)p;
}

int main()
{
    GIFRegTRXPOS r = {};
    GIFRegHandlerTRXPOS(r);

    uint16_t fpu[16] = {0};
    __asm__ __volatile__(\"fstenv %0\" : \"=m\"(fpu));

    bool ok = fpu[4] == 0xFFFF;

    if (!ok) {
        printf(\"Wrong MMX state !\");
        exit(1);
    }

    return 0;
}
")

function(GCC7_BUG)
    # try_run doesn't work when cross-compiling is enabled. It is completely silly in our case
    # as i386 binaries are 100% fine on x64.
    set(OLD_CMAKE_CROSSCOMPILING ${CMAKE_CROSSCOMPILING})
    set(CMAKE_CROSSCOMPILING 0)

    set(IN "${CMAKE_BINARY_DIR}/gcc7_mmx.cpp")
    file(WRITE "${IN}" "${gcc7_mmx_code}")

    enable_language(CXX)

    try_run(
            run_result
            compile_result_unused
            "${CMAKE_BINARY_DIR}"
            "${IN}"
            CMAKE_FLAGS "-DCOMPILE_DEFINITIONS:STRING=-msse -msse2 -O2 -m32 -march=i686"
        )

    if (${run_result})
        message(FATAL_ERROR "GCC 7.0/7.1  generates invalid code => https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80799\n"
            "You can either backport the fix or swith to another version of GCC.")
    endif()

    set(CMAKE_CROSSCOMPILING ${OLD_CMAKE_CROSSCOMPILING})

endfunction()
