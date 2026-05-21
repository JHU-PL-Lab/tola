#ifndef TINY_H
#define TINY_H

/* Read-mostly global. Initial value 42. */
extern int tiny_offset;

/* Returns a + b + tiny_offset. */
int tiny_sum(int a, int b);

/* Returns a - b. */
int tiny_diff(int a, int b);

#endif /* TINY_H */
