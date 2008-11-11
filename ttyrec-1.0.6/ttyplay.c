/*
 * Copyright (c) 2000 Satoru Takabayashi <satoru@namazu.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>
#include <termios.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>

#include "ttyrec.h"
#include "ttyplay.h"
#include "io.h"

off_t seek_offset_clrscr;
typedef void	(*ProcessFunc)	(FILE *fp, double speed, 
				 ReadFunc read_func, WaitFunc wait_func);

struct timeval
timeval_diff (struct timeval tv1, struct timeval tv2)
{
    struct timeval diff;

    diff.tv_sec = tv2.tv_sec - tv1.tv_sec;
    diff.tv_usec = tv2.tv_usec - tv1.tv_usec;
    if (diff.tv_usec < 0) {
	diff.tv_sec--;
	diff.tv_usec += 1000000;
    }

    return diff;
}

struct timeval
timeval_div (struct timeval tv1, double n)
{
    double x = ((double)tv1.tv_sec  + (double)tv1.tv_usec / 1000000.0) / n;
    struct timeval div;
    
    div.tv_sec  = (int)x;
    div.tv_usec = (x - (int)x) * 1000000;

    return div;
}

double
ttywait (struct timeval prev, struct timeval cur, double speed)
{
    struct timeval diff = timeval_diff(prev, cur);
    fd_set readfs;

    assert(speed != 0);
    diff = timeval_div(diff, speed);

    FD_SET(STDIN_FILENO, &readfs);
    select(1, &readfs, NULL, NULL, &diff); /* skip if a user hits any key */
    if (FD_ISSET(0, &readfs)) { /* a user hits a character? */
        char c;
        read(STDIN_FILENO, &c, 1); /* drain the character */
        switch (c) {
        case '+':
        case 'f':
            speed *= 2;
            break;
        case '-':
        case 's':
            speed /= 2;
            break;
        case '1':
            speed = 1.0;
            break;
        }
    }
    return speed;
}

double
ttynowait (struct timeval prev, struct timeval cur, double speed)
{
    /* do nothing */
    return 0; /* Speed isn't important. */
}

/*int
ttyread (FILE *fp, Header *h, char **buf)
{
    if (read_header(fp, h) == 0) {
	return 0;
    }

    *buf = malloc(h->len);
    if (*buf == NULL) {
	perror("malloc");
    }
	
    if (fread(*buf, 1, h->len, fp) == 0) {
	perror("fread");
    }
    return 1;
}*/

int
ttyread (FILE * fp, Header * h, char **buf, int pread)
{
  long offset;

  /* do this BEFORE header read, hlen bug */
  offset = ftell (fp);

  if (read_header (fp, h) == 0)
    {
      return READ_EOF;
    }

  /* length should never be longer than one BUFSIZ */
  if (h->len > BUFSIZ)
    {
      fprintf (stderr, "h->len too big (%ld) limit %ld\n",
		      (long)h->len, (long)BUFSIZ);
      exit (-21);
    }

  *buf = malloc (h->len);
  if (*buf == NULL)
    {
      perror ("malloc");
      exit (-22);
    }

  if (fread (*buf, 1, h->len, fp) != h->len)
    {
      fseek (fp, offset, SEEK_SET);
      return READ_EOF;
    }
  return READ_DATA;
}

/*int
ttypread (FILE *fp, Header *h, char **buf)
{
    while (ttyread(fp, h, buf) == 0) {
	struct timeval w = {0, 250000};
	select(0, NULL, NULL, NULL, &w);
	clearerr(fp);
    }
    return 1;
}*/
int
ttypread (FILE * fp, Header * h, char **buf, int pread)
{
  int counter = 0;
  fd_set readfs;
  struct timeval zerotime;

  zerotime.tv_sec = 0;
  zerotime.tv_usec = 0;

  /*
   * Read persistently just like tail -f.
   */
  while (ttyread (fp, h, buf, 1) == READ_EOF)
    {
      struct timeval w = { 0, 100000 };
      select (0, NULL, NULL, NULL, &w);
      clearerr (fp);
      if (counter++ > (20 * 60 * 10))
        {
          /*endwin ();*/
          printf ("Exiting due to 20 minutes of inactivity.\n");
          exit (-23);
        }


      /* look for keypresses here. as good a place as any */
      FD_SET (STDIN_FILENO, &readfs);
      select (1, &readfs, NULL, NULL, &zerotime);
      if (FD_ISSET (0, &readfs))
        {                       /* a user hits a character? */
          char c;
          read (STDIN_FILENO, &c, 1); /* drain the character */

          switch (c)
            {
            case 'q':
              return READ_EOF;
              break;
	    /*case 's':
	      switch (stripped)
	      {
		case NO_GRAPHICS: populate_gfx_array ((stripped = DEC_GRAPHICS)); break;
		case DEC_GRAPHICS: populate_gfx_array ((stripped = IBM_GRAPHICS)); break;
		case IBM_GRAPHICS: populate_gfx_array ((stripped = NO_GRAPHICS)); break;
	      }
	      return READ_RESTART;
	      break;

              case 'm':
	      if (!loggedin)
	      {
		initcurses();
		loginprompt(1);
		if (!loggedin) return READ_RESTART;
	      }
              if (loggedin)
	      {
		initcurses ();
		domailuser (chosen_name);
                return READ_RESTART;
	      }
	      
              break;
	      */
            }
        }
    }
  return READ_DATA;
}

/*
void
ttywrite (char *buf, int len)
{
    fwrite(buf, 1, len, stdout);
}
*/
void
ttywrite (char *buf, int len)
{
  int i;

  /*for (i = 0; i < len; i++)
  {
    if (stripped != NO_GRAPHICS)
      buf[i] = strip_gfx (buf[i]);
  }*/

  fwrite (buf, 1, len, stdout);
}

void
ttynowrite (char *buf, int len)
{
    /* do nothing */
}

/*
void
ttyplay (FILE *fp, double speed, ReadFunc read_func, 
	 WriteFunc write_func, WaitFunc wait_func)
{
    int first_time = 1;
    struct timeval prev;

    setbuf(stdout, NULL);
    setbuf(fp, NULL);

    while (1) {
	char *buf;
	Header h;

	if (read_func(fp, &h, &buf) == 0) {
	    break;
	}

	if (!first_time) {
	    speed = wait_func(prev, h.tv, speed);
	}
	first_time = 0;

	write_func(buf, h.len);
	prev = h.tv;
	free(buf);
    }
}
*/
int
ttyplay (FILE * fp, double speed, ReadFunc read_func,
         WriteFunc write_func, WaitFunc wait_func, off_t offset)
{
  int first_time = 1;
  int r = READ_EOF;
  struct timeval prev;

  setbuf (stdout, NULL);
  setbuf (fp, NULL);

  /* for dtype's attempt to get the last clrscr and playback from there */
  if (offset)
    {
      fseek (fp, offset, SEEK_SET);
    }

  while (1)
    {
      char *buf;
      Header h;

      r = read_func (fp, &h, &buf, 0);
      if (r != READ_DATA)
        {
          break;
        }

      if (!first_time)
        {
          speed = wait_func (prev, h.tv, speed);
        }
      first_time = 0;

      write_func (buf, h.len);
      prev = h.tv;
      free (buf);
    }
  return r;
}


void
set_seek_offset_clrscr (FILE * fp)
{
  off_t raw_seek_offset = 0;
  char *buf;
  struct stat mystat;
  int state = 0;
  int i;
  int bytesread;

  fstat (fileno (fp), &mystat);
  buf = malloc (mystat.st_size);
  fseek (fp, 0, SEEK_SET);
  bytesread = fread (buf, 1, mystat.st_size, fp);

  /* one byte at at time sucks, but is a simple hack for the temp
   * being to avoid looking fori wraparounds */
  for (i = 0; i < bytesread; i++)
    {
      if (buf[i] == 0x1b)
        {
          state = 1;
        }
      else if ((buf[i] == 0x5b) && (state == 1))
        {
          state = 2;
        }
      else if ((buf[i] == 0x32) && (state == 2))
        {
          state = 3;
        }
      else if ((buf[i] == 0x4a) && ((state == 2) || (state == 3)))
        {
          state = 4;
        }
      else
        {
          state = 0;
        }

      if (state == 4)
        {
          raw_seek_offset = i - 2;
        }
    }

  free (buf);

  /* now find last filepos that is less than seek offset */
  fseek (fp, 0, SEEK_SET);
  while (1)
    {
      char *buf;
      Header h;

      if (ttyread (fp, &h, &buf, 0) != READ_DATA)
        {
          break;
        }

      if (ftell (fp) < raw_seek_offset)
        {
          seek_offset_clrscr = ftell (fp);
        }

      free (buf);
    }

}

void
ttyskipall (FILE *fp)
{
    /*
     * Skip all records.
     */
    ttyplay(fp, 0, ttyread, ttynowrite, ttynowait, 0);
}

void ttyplayback (FILE *fp, double speed, 
		  ReadFunc read_func, WaitFunc wait_func)
{
    ttyplay(fp, speed, ttyread, ttywrite, wait_func, 0);
}

/*void ttypeek (FILE *fp, double speed, 
/	      ReadFunc read_func, WaitFunc wait_func)
{
    ttyskipall(fp);
    ttyplay(fp, speed, ttypread, ttywrite, ttynowait);
}
*/

void
ttypeek (FILE * fp, double speed, ReadFunc read_func, WaitFunc wait_func)
{
  int r;

  do
  {
    ttyskipall (fp);
    set_seek_offset_clrscr (fp);
    if (seek_offset_clrscr)
      {
        ttyplay (fp, 0, ttyread, ttywrite, ttynowait, seek_offset_clrscr);
      }
    r = ttyplay (fp, speed, ttypread, ttywrite, ttynowait, 0);
  } while (r == READ_RESTART);
}


void
usage (void)
{
    printf("Usage: ttyplay [OPTION] [FILE]\n");
    printf("  -s SPEED Set speed to SPEED [1.0]\n");
    printf("  -n       No wait mode\n");
    printf("  -p       Peek another person's ttyrecord\n");
    exit(EXIT_FAILURE);
}

int 
main (int argc, char **argv)
{
    double speed = 1.0;
    ReadFunc read_func  = ttyread;
    WaitFunc wait_func  = ttywait;
    ProcessFunc process = ttyplayback;
    FILE *input = stdin;
    struct termios old, new;

    set_progname(argv[0]);
    while (1) {
        int ch = getopt(argc, argv, "s:np");
        if (ch == EOF) {
            break;
	}
	switch (ch) {
	case 's':
	    if (optarg == NULL) {
		perror("-s option requires an argument");
		exit(EXIT_FAILURE);
	    }
	    sscanf(optarg, "%lf", &speed);
	    break;
	case 'n':
	    wait_func = ttynowait;
	    break;
	case 'p':
	    process = ttypeek;
	    break;
	default:
	    usage();
	}
    }

    if (optind < argc) {
	input = efopen(argv[optind], "r");
    }

    tcgetattr(0, &old); /* Get current terminal state */
    new = old;          /* Make a copy */
    new.c_lflag &= ~(ICANON | ECHO | ECHONL); /* unbuffered, no echo */
    tcsetattr(0, TCSANOW, &new); /* Make it current */

    process(input, speed, read_func, wait_func);
    tcsetattr(0, TCSANOW, &old);  /* Return terminal state */

    return 0;
}
