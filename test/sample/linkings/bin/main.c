#include <stdio.h>
#include <stdlib.h>

extern int sum(int n);

int main(int argc, char **argv)
{
  if (argc != 2)
  {
    fprintf(stderr, "Usage: %s <n>\n", argv[0]);
    return 1;
  }
  int n = atoi(argv[1]);
  printf("Sum from 1 to %d is: %d\n", n, sum(n));
  return 0;
}