#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <portia/portia.h>

int main(int argc, char **argv) {
    cortex_size_t cortex_width = 200;
    cortex_size_t cortex_height = 100;
    cortex_size_t input_width = 20;
    cortex_size_t input_height = 1;
    nh_radius_t nh_radius = 1;

    srand(time(NULL));

    error_code_t error;

    // Cortex init.
    cortex2d_t* even_cortex;
    cortex2d_t* odd_cortex;
    error = c2d_init(&even_cortex, cortex_width, cortex_height, nh_radius);
    error = c2d_init(&odd_cortex, cortex_width, cortex_height, nh_radius);
    c2d_copy(odd_cortex, even_cortex);

    // Input init.
    input2d_t* input;
    i2d_init(&input, (cortex_width / 2) - (input_width / 2), 0, (cortex_width / 2) + (input_width / 2), input_height, DEFAULT_EXC_VALUE * 2, PULSE_MAPPING_FPROP);

    // Set input values.
    for (int i = 0; i < input_width * input_height; i++) {
        input->values[i] = even_cortex->sample_window / 2;
    }

    uint64_t start_time = millis();

    for (int i = 0; i < 1000; i++) {
        cortex2d_t* prev_cortex = i % 2 ? odd_cortex : even_cortex;
        cortex2d_t* next_cortex = i % 2 ? even_cortex : odd_cortex;

        // TODO Fetch input.

        // Feed.
        c2d_feed2d(prev_cortex, input);

        c2d_tick(prev_cortex, next_cortex);

        // usleep(100);
    }

    // Stop timer.
    uint64_t end_time = millis();
    printf("\nCompleted 1000 iterations in %ldms\n", end_time - start_time);

    // Copy the cortex back to host to check the results.
    printf("\nHost cortex %d %d\n", even_cortex->width, even_cortex->height);
    c2d_to_file(even_cortex, (char*) "out/test.c2d");

    // Cleanup.
    c2d_destroy(even_cortex);
    c2d_destroy(odd_cortex);
    i2d_destroy(input);

    return 0;
}
