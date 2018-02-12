
#include <stdint.h>

#include "rules.h"
#include "macros.h"

#ifndef Byte
#  define Byte uint8_t
#endif

#ifndef NULL
#  define NULL 0
#endif

static int ONE(int (*func)(const Byte*,const Byte*), const Byte *ptr, const Byte *eof, int *bytes) {
	int x = (*func)(ptr, eof);
	if (bytes != (int*)NULL) {
		*bytes += x;
	}
	return x;
}

static int MANY(int (*func)(const Byte*,const Byte*), const Byte *ptr, const Byte *eof, int *bytes, int min, int max) {
	int total = 0;
	int i = 0;
	int x;
	while ((max < 1 || i < max) && (x = (*func)(ptr, eof))) {
		total += x;
		i++;
	}
	if (min > 0 && i < min) {
		return 0;
	}
	if (bytes != (int*)NULL) {
		*bytes += total;
	}
	return total;
}

#define BETWEEN(a, max, min) ((a) >= (min) && (a) <= (max))

/******** PRIMITIVES ********/

int ALPHA(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if ((*txt >= 0x41 && *txt <= 0x5A) || (*txt >= 0x61 && *txt <= 0x7A)) {
		return 1;
	}
	return 0;
}

int BIT(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == '0' || *txt == '1') {
		return 1;
	}
	return 0;
}

int CHAR(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt >= 0x31 && *txt <= 0x7F) {
		return 1;
	}
	return 0;
}

int CR(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == 0x0D) {
		return 1;
	}
	return 0;
}

int CRLF(const Byte *txt, const Byte *eof) {
	int n;
	if ((n = CR(txt, eof)) && ONE(&LF, PTR_ADD(txt, n), eof, &n)) {
		return n;
	}
	return 0;
}

int CTL(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if ((*txt >= 0x00 && *txt <= 0x1F) || *txt == 0x7F) {
		return 1;
	}
	return 0;
}

int DIGIT(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt >= 0x30 && *txt <= 0x39) {
		return 1;
	}
	return 0;
}

int DQUOTE(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == 0x22) {
		return 1;
	}
	return 0;
}

int HEXDIG(const Byte *txt, const Byte *eof) {
	int n;
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if ((n = DIGIT(txt, eof))) {
		return n;
	} else if (*txt == 'A' || *txt == 'a'
			|| *txt == 'B' || *txt == 'b'
			|| *txt == 'C' || *txt == 'c'
			|| *txt == 'D' || *txt == 'd'
			|| *txt == 'E' || *txt == 'e'
			|| *txt == 'F' || *txt == 'f') {
		return 1;
	}
	return 0;
}

int HTAB(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == 0x09) {
		return 1;
	}
	return 0;
}

int LF(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == 0x0A) {
		return 1;
	}
	return 0;
}

int LWSP(const Byte *txt, const Byte *eof) {
	int total = 0;
	int i = 0;
	Byte *ptr = (Byte*)txt;
	while (ONE(&WSP, ptr, eof, &i) || (ONE(&CRLF, ptr, eof, &i) && ONE(&WSP, PTR_ADD(ptr, i), eof, &i))) {
		total += i;
		ptr = PTR_ADD(ptr, i);
		i = 0;
	}
	return total;
}

int OCTET(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	}
	return 1;
}

int SP(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt == 0x20) {
		return 1;
	}
	return 0;
}

int VCHAR(const Byte *txt, const Byte *eof) {
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (*txt >= 0x21 && *txt <= 0x7E) {
		return 1;
	}
	return 0;
}

int WSP(const Byte *txt, const Byte *eof) {
	int n;
	if ((n = SP(txt, eof)) || (n = HTAB(txt, eof))) {
		return n;
	}
	return 0;
}

/******** ABNF Rules ********/

static int _rulelist_inner(const Byte *txt, const Byte *eof) {
	/*                =  rule / (*c-wsp c-nl) */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = rule(ptr, eof);
	if (n) {
		return n;
	}

	n = MANY(&c_wsp, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	n = c_nl(ptr, eof);
	if (!n) {
		return 0;
	}
	return total + n;
}

int rulelist(const Byte *txt, const Byte *eof) {
	/* rulelist       =  1*( rule / (*c-wsp c-nl) ) */
	return MANY(&_rulelist_inner, txt, eof, (int*)NULL, 1, 0);
}

int rule(const Byte *txt, const Byte *eof) {
	/* rule           =  rulename defined-as elements c-nl */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = rulename(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	n = defined_as(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	n = elements(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	n = c_nl(ptr, eof);
	if (!n) {
		return 0;
	}
	return total + n;
}

static int _rulename_inner(const Byte *txt, const Byte *eof) {
	/*                =  ALPHA / DIGIT / "-" */
	return ALPHA(txt, eof) || DIGIT(txt, eof) || ((PTR_LT(txt, eof) && *txt == '-') ? 1 : 0);
}

int rulename(const Byte *txt, const Byte *eof) {
	/* rulename       =  ALPHA *(ALPHA / DIGIT / "-") */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = ALPHA(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	MANY(&_rulename_inner, ptr, eof, &total, 0, 0);
	return total;
}

int defined_as(const Byte *txt, const Byte *eof) {
	/* defined-as     =  *c-wsp ("=" / "=/") *c-wsp */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = MANY(&c_wsp, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof) || *ptr != '=') {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	if (PTR_LT(ptr, eof) && *ptr == '/') {
		total++;
		PTR_INC(ptr);
	}

	MANY(&c_wsp, ptr, eof, &total, 0, 0);
	return total;
}

int elements(const Byte *txt, const Byte *eof) {
	/* elements       =  alternation *c-wsp */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = alternation(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	MANY(&c_wsp, ptr, eof, &total, 0, 0);

	return total;
}

int c_wsp(const Byte *txt, const Byte *eof) {
	/* c-wsp          =  WSP / (c-nl WSP) */

	int n;
	if ((n = WSP(txt, eof))) {
		return n;
	} else if ((n = c_nl(txt, eof)) && ONE(&WSP, PTR_ADD(txt, n), eof, &n)) {
		return n;
	}

	return 0;
}

int c_nl(const Byte *txt, const Byte *eof) {
	/* c-nl           =  comment / CRLF */
	return comment(txt, eof) || CRLF(txt, eof);
}

static int _comment_inner(const Byte *txt, const Byte *eof) {
	/*                =  WSP / VCHAR */
	return WSP(txt, eof) || VCHAR(txt, eof);
}

int comment(const Byte *txt, const Byte *eof) {
	/* comment        =  ";" *(WSP / VCHAR) CRLF */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	if (PTR_GE(ptr, eof) || *ptr != ';') {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	n = MANY(&_comment_inner, txt, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof)) {
		return 0;
	}
	n = CRLF(ptr, eof);
	if (!n) {
		return 0;
	}
	return total + n;
}

static int _alternation_inner(const Byte *txt, const Byte *eof) {
	/*                = *c-wsp "/" *c-wsp concatenation */
	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = MANY(&c_wsp, txt, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof) || *ptr != '/') {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	n = MANY(&c_wsp, txt, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	n = concatenation(ptr, eof);
	if (!n) {
		return 0;
	}
	return total + n;
}

int alternation(const Byte *txt, const Byte *eof) {
	/* alternation    =  concatenation *(*c-wsp "/" *c-wsp concatenation) */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;
	
	n = concatenation(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	MANY(&_alternation_inner, txt, eof, &total, 0, 0);

	return total;
}

static int _concatenation_inner(const Byte *txt, const Byte *eof) {
	/*                = 1*c-wsp repetition */
	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = MANY(&c_wsp, txt, eof, &total, 1, 0);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	n = repetition(ptr, eof);
	if (!n) {
		return 0;
	}
	return total + n;
}

int concatenation(const Byte *txt, const Byte *eof) {
	/* concatenation  =  repetition *(1*c-wsp repetition) */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;
	
	n = repetition(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	MANY(&_concatenation_inner, txt, eof, &total, 0, 0);

	return total;
}

int repetition(const Byte *txt, const Byte *eof) {
	/* repetition     =  [repeat] element */

	Byte *ptr = (Byte*)txt;
	int repeat_len;
	int element_len;

	repeat_len = repeat(ptr, eof);
	if (repeat_len > 0) {
		ptr = PTR_ADD(ptr, txt);
	}

	element_len = element(ptr, eof);
	if (element_len == 0) {
		return 0;
	}

	return repeat_len + element_len;
}

int repeat(const Byte *txt, const Byte *eof) {
	/* repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT) */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	/* allow zero or more */
	n = MANY(&DIGIT, ptr, eof, &total, 0, 0);

	/* no star; we either have some digits, or no digits */
	if (PTR_GE(ptr, eof) || *ptr != '*') {
		return n;
	}

	/* there was a star */
	PTR_INC(ptr);

	/* maybe consume more digits */
	MANY(&DIGIT, ptr, eof, &total, 0, 0);

	return total;
}

int element(const Byte *txt, const Byte *eof) {
	/* element        =  rulename / group / option / char-val / num-val / prose-val */
	int n;
	if ((n = rulename(txt, eof))) {
		return n;
	} else if ((n = group(txt, eof))) {
		return n;
	} else if ((n = option(txt, eof))) {
		return n;
	} else if ((n = char_val(txt, eof))) {
		return n;
	} else if ((n = num_val(txt, eof))) {
		return n;
	} else if ((n = prose_val(txt, eof))) {
		return n;
	}
	return 0;
}

static int _dry_bracketed(const Byte *txt, const Byte *eof, Byte left, Byte right) {
	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	if (PTR_GE(ptr, eof) || *ptr != left) {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	n = MANY(&c_wsp, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	n = alternation(ptr, eof);
	/* FIXME: I shouldn't have to know here that <alternation> is never blank */
	if (n == 0) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);

	n = MANY(&c_wsp, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof) || *ptr != right) {
		return 0;
	}
	total++;

	return total;

}

int group(const Byte *txt, const Byte *eof) {
	/* group          =  "(" *c-wsp alternation *c-wsp ")" */
	return _dry_bracketed(txt, eof, '(', ')');
}

int option(const Byte *txt, const Byte *eof) {
	/* option         =  "[" *c-wsp alternation *c-wsp "]" */
	return _dry_bracketed(txt, eof, '[', ']');
}

static int _char_val_inner(const Byte *txt, const Byte *eof) {
	/*                = %x20-21 / %x23-7E */
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (BETWEEN(*txt, 0x20, 0x21) || BETWEEN(*txt, 0x23, 0x7E)) {
		return 1;
	}
	return 0;
}

int char_val(const Byte *txt, const Byte *eof) {
	/* char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	n = DQUOTE(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;
	ptr = PTR_ADD(ptr, n);;

	n = MANY(&_char_val_inner, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	n = DQUOTE(ptr, eof);
	if (!n) {
		return 0;
	}
	total += n;

	return total;
}

int num_val(const Byte *txt, const Byte *eof) {
	/* num-val        =  "%" (bin-val / dec-val / hex-val) */

	Byte *ptr;
	int n;

	if (PTR_GE(txt, eof) || *txt != '%') {
		return 0;
	}

	ptr = PTR_ADD(txt, 1);

	if ((n = bin_val(ptr, eof))) {
		return n + 1;
	} else if ((n = dec_val(ptr, eof))) {
		return n + 1;
	} else if ((n = hex_val(ptr, eof))) {
		return n + 1;
	}

	return 0;
}

static int _dry_num_val(const Byte *txt, const Byte *eof, Byte lc, Byte uc, int (*func)(const Byte*,const Byte*)) {
	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	if (PTR_GE(ptr, eof) || *ptr != lc || *ptr != uc) {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	n = MANY(func, ptr, eof, &total, 1, 0);
	if (n == 0) {
		return 0;
	}
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof)) {
		return total;
	}
	if (*ptr == '.') {
		while (PTR_LT(ptr, eof) && *ptr == '.') {
			PTR_INC(ptr);
			n = MANY(func, ptr, eof, &total, 1, 0);
			if (n == 0) {
				/* back-track one byte (for the dot) */
				return total - 1;
			}
			ptr = PTR_ADD(ptr, n);
		}
	} else if (*ptr == '-') {
		total++;
		PTR_INC(ptr);

		n = MANY(func, ptr, eof, &total, 1, 0);
		if (n == 0) {
			/* back-track one byte (for the hyphen) */
			return total - 1;
		}
		ptr = PTR_ADD(ptr, n);
	}

	return total;

}

int bin_val(const Byte *txt, const Byte *eof) {
	/* bin-val        =  "b" 1*BIT [ 1*("." 1*BIT) / ("-" 1*BIT) ] */
	return _dry_num_val(txt, eof, 'b', 'B', &BIT);
}

int dec_val(const Byte *txt, const Byte *eof) {
	/* dec-val        =  "d" 1*DIGIT [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ] */
	return _dry_num_val(txt, eof, 'd', 'D', &DIGIT);
}

int hex_val(const Byte *txt, const Byte *eof) {
	/* hex-val        =  "x" 1*HEXDIG [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ] */
	return _dry_num_val(txt, eof, 'x', 'X', &HEXDIG);
}

static int _prose_val_inner(const Byte *txt, const Byte *eof) {
	/*               = %x20-3D / %x3F-7E */
	if (PTR_GE(txt, eof)) {
		return 0;
	} else if (BETWEEN(*txt, 0x20, 0x3D) || BETWEEN(*txt, 0x3F, 0x7E)) {
		return 1;
	}
	return 0;
}

int prose_val(const Byte *txt, const Byte *eof) {
	/* prose-val      =  "<" *(%x20-3D / %x3F-7E) ">" */

	Byte *ptr = (Byte*)txt;
	int total = 0;
	int n;

	if (PTR_GE(ptr, eof) || *ptr != '<') {
		return 0;
	}
	total++;
	PTR_INC(ptr);

	n = MANY(&_prose_val_inner, ptr, eof, &total, 0, 0);
	ptr = PTR_ADD(ptr, n);

	if (PTR_GE(ptr, eof) || *ptr != '>') {
		return 0;
	}
	total++;

	return total;
}

