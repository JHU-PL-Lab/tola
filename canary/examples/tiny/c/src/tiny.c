#include "tiny.h"

int tiny_offset = 42;

int tiny_sum(int a, int b) {
    return a + b + tiny_offset;
}

int tiny_diff(int a, int b) {
    return a - b;
}
