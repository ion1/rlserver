#ifndef INCLUDED_ttyplay_h
#define INCLUDED_ttyplay_h

#include <stdio.h>
#include "ttyrec.h"

int ttyplay_main (char *ttyfile, int mode);

typedef double (*WaitFunc) (struct timeval prev,
                            struct timeval cur, double speed);
typedef int (*ReadFunc) (FILE * fp, Header * h, char **buf, int pread);
typedef void (*WriteFunc) (char *buf, int len);

/* Return values for ReadFunc (and ProcessFunc) */
#define READ_DATA	0 /* Data */
#define READ_EOF	1 /* Normal EOF or user aborted */
#define READ_RESTART	2 /* Screen must be redrawn (after simplemail) */

#endif /* !INCLUDED_ttyplay_h */
