#ifndef TINY_H
#define TINY_H

/* Read-mostly global. Initial value 42. */
extern int tiny_offset;

/* Returns a + b + tiny_offset. */
int tiny_sum(int a, int b);

/* Returns a - b. */
int tiny_diff(int a, int b);

#ifdef TINY_DEV
/* Returns a * k. Added in the "dev" version (TINY_2.0); absent from "stable"
   (TINY_1.0). A consumer built against dev that calls tiny_scale fails against
   a stable lib — the version deploy mismatch. */
int tiny_scale(int a, int k);
#endif

#endif /* TINY_H */
