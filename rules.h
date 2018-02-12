#ifndef __RULES_H__
#define __RULES_H__

#include <stdint.h>

/* RFC 5234 Primitives */
extern int ALPHA(const uint8_t *txt, const uint8_t *eof);
extern int BIT(const uint8_t *txt, const uint8_t *eof);
extern int CHAR(const uint8_t *txt, const uint8_t *eof);
extern int CR(const uint8_t *txt, const uint8_t *eof);
extern int CRLF(const uint8_t *txt, const uint8_t *eof);
extern int CTL(const uint8_t *txt, const uint8_t *eof);
extern int DIGIT(const uint8_t *txt, const uint8_t *eof);
extern int DQUOTE(const uint8_t *txt, const uint8_t *eof);
extern int HEXDIG(const uint8_t *txt, const uint8_t *eof);
extern int HTAB(const uint8_t *txt, const uint8_t *eof);
extern int LF(const uint8_t *txt, const uint8_t *eof);
extern int LWSP(const uint8_t *txt, const uint8_t *eof);
extern int OCTET(const uint8_t *txt, const uint8_t *eof);
extern int SP(const uint8_t *txt, const uint8_t *eof);
extern int VCHAR(const uint8_t *txt, const uint8_t *eof);
extern int WSP(const uint8_t *txt, const uint8_t *eof);

/* RFC 5234 */
extern int rulelist(const uint8_t *txt, const uint8_t *eof);
extern int rule(const uint8_t *txt, const uint8_t *eof);
extern int rulename(const uint8_t *txt, const uint8_t *eof);
extern int defined_as(const uint8_t *txt, const uint8_t *eof);
extern int elements(const uint8_t *txt, const uint8_t *eof);
extern int c_wsp(const uint8_t *txt, const uint8_t *eof);
extern int c_nl(const uint8_t *txt, const uint8_t *eof);
extern int comment(const uint8_t *txt, const uint8_t *eof);
extern int alternation(const uint8_t *txt, const uint8_t *eof);
extern int concatenation(const uint8_t *txt, const uint8_t *eof);
extern int repetition(const uint8_t *txt, const uint8_t *eof);
extern int repeat(const uint8_t *txt, const uint8_t *eof);
extern int element(const uint8_t *txt, const uint8_t *eof);
extern int group(const uint8_t *txt, const uint8_t *eof);
extern int option(const uint8_t *txt, const uint8_t *eof);
extern int char_val(const uint8_t *txt, const uint8_t *eof);
extern int num_val(const uint8_t *txt, const uint8_t *eof);
extern int bin_val(const uint8_t *txt, const uint8_t *eof);
extern int dec_val(const uint8_t *txt, const uint8_t *eof);
extern int hex_val(const uint8_t *txt, const uint8_t *eof);
extern int prose_val(const uint8_t *txt, const uint8_t *eof);

#endif
