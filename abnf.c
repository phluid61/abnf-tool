
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <error.h>

#include "macros.h"
#include "rules.h"

/**
 * Loads a file into a byte buffer.
 */
uint64_t load_file(const char* filename, uint8_t **buffer) {
	uint8_t *ptr;

	int fd;
	struct stat info;
	uint64_t size = 0;

	ssize_t this_read;
	ssize_t remaining;

	*buffer = (uint8_t*)NULL;

	/* open 'filename', or die */
	fd = open(filename, O_RDONLY);
	if (fd == -1) {
		error(0, errno, "unable to open file '%s'", filename);
		goto load_file__finally;
	}

	/* discover the size of the file */
	if (fstat(fd, &info) == -1) {
		error(0, errno, "unable to check file size of '%s'", filename);
		goto load_file__finally;
	}
	if (info.st_size == 0) {
		fprintf(stderr, "not reading empty file '%s'\n", filename);
		goto load_file__finally;
	}
	size = (uint64_t)info.st_size;

	/* allocate an in-memory buffer */
	*buffer = (uint8_t*)malloc((size_t)info.st_size);
	if (*buffer == (uint8_t*)NULL) {
		error(0, errno, "unable to allocate %lu bytes for '%s'", (unsigned long)info.st_size, filename);
		goto load_file__finally;
	}

	/* read whole file into buffer */
	ptr = *buffer;
	remaining = (ssize_t)info.st_size;
	while (remaining > 0) {
		this_read = read(fd, ptr, remaining);
		if (this_read == -1) {
			error(0, errno, "error reading from '%s'", filename);
			/* clean up partial buffer */
			free((void*)(*buffer));
			*buffer = (uint8_t*)NULL;
			size = (uint64_t)0;
			goto load_file__finally;
		}
		remaining -= this_read;
		ptr = PTR_ADD(ptr, this_read);
	}

load_file__finally:
	if (fd != -1) {
		close(fd);
	}
	return size;
}

int main() {
	uint8_t *txt;
	uint64_t size;

	uint8_t *ptr;
	uint8_t *eof;

	size = load_file("abnf.c", &txt);
	if (size == 0) {
		return -1;
	}
/*
	fwrite(txt, (size_t)1, (size_t)size, stdout);
	printf("\n");
*/

	ptr = txt;
	eof = PTR_ADD(txt, size);
	printf("%d\n", rulelist(ptr, eof));

	free((void*)txt);
	return 0;
}

/* vim: set ts=4 sts=4 sw=4
 */
