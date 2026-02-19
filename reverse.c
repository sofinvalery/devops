#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define N 7

int main(void) {
    int a[N][N];
    int zero_above_main = 0;
    int pos_below_side = 0;
    srand((unsigned int)time(NULL));
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            a[i][j] = rand() % 19 - 9;
        }
    }
    printf("Initial matrix:\n");
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {printf("%3d ", a[i][j]);}
        printf("\n");
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            if (j > i && a[i][j] == 0) {zero_above_main++;}
            if (i + j > N - 1 && a[i][j] > 0) {pos_below_side++;}
        }
    }
    if (zero_above_main == pos_below_side) {
        for (int i = 0; i < N; i++) {
            for (int j = 0; j < N; j++) {
                a[i][j] = 0;
            }
        }
    }
    printf("\nZeros above main diagonal: %d\n", zero_above_main);
    printf("Positive below secondary diagonal: %d\n", pos_below_side);
    printf("\nResult matrix:\n");
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {printf("%3d ", a[i][j]);}
        printf("\n");
    }
    return 0;
}