#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <portia/portia.h>

void setup_cortexes(cortex2d_t* even_cortex, cortex2d_t* odd_cortex, cortex_size_t cortex_width, cortex_size_t cortex_height, nh_radius_t nh_radius) {
    c2d_init(&even_cortex, cortex_width, cortex_height, nh_radius);
    c2d_init(&odd_cortex, cortex_width, cortex_height, nh_radius);
    c2d_set_evol_step(even_cortex, 0x01U);
    c2d_set_pulse_mapping(even_cortex, PULSE_MAPPING_RPROP);
    c2d_set_max_syn_count(even_cortex, 24);
    char touchFileName[40];
    char inhexcFileName[40];
    sprintf(touchFileName, "./res/%d_%d_touch.pgm", cortex_width, cortex_height);
    sprintf(inhexcFileName, "./res/%d_%d_inhexc.pgm", cortex_width, cortex_height);
    c2d_touch_from_map(even_cortex, touchFileName);
    c2d_inhexc_from_map(even_cortex, inhexcFileName);
    c2d_copy(odd_cortex, even_cortex);
}

int main(int argc, char **argv) {
    cortex_size_t cortex_width = 1024;
    cortex_size_t cortex_height = 512;
    cortex_size_t input_width = 128;
    cortex_size_t input_height = 1;
    uint32_t iterations_count = 100000;
    dim3 cortex_grid_size(cortex_width / BLOCK_SIZE_2D, cortex_height / BLOCK_SIZE_2D);
    dim3 cortex_block_size(BLOCK_SIZE_2D, BLOCK_SIZE_2D);
    dim3 input_grid_size(input_width, input_height);
    dim3 input_block_size(1, 1);
    nh_radius_t nh_radius = 2;

    srand(time(NULL));

    error_code_t error;

    // Cortex configuration.
    cortex2d_t* even_cortex;
    cortex2d_t* odd_cortex;
    setup_cortexes(even_cortex, odd_cortex, cortex_width, cortex_height, nh_radius);

    // Copy cortexes to device.
    cortex2d_t* d_even_cortex;
    cortex2d_t* d_odd_cortex;
    cudaMalloc((void**) &d_even_cortex, sizeof(cortex2d_t));
    cudaCheckError();
    cudaMalloc((void**) &d_odd_cortex, sizeof(cortex2d_t));
    cudaCheckError();
    error = c2d_to_device(d_even_cortex, even_cortex);
    error = c2d_to_device(d_odd_cortex, odd_cortex);

    // Input init.
    input2d_t* input;
    i2d_init(
        &input,
        (cortex_width / 2) - (input_width / 2),
        0,
        (cortex_width / 2) + (input_width / 2),
        input_height,
        DEFAULT_EXC_VALUE * 2,
        PULSE_MAPPING_FPROP
    );

    // Set input values.
    for (int i = 0; i < input_width * input_height; i++) {
        input->values[i] = even_cortex->sample_window - 1;
    }

    // Copy input to device.
    input2d_t* d_input;
    cudaMalloc((void**) &d_input, sizeof(input2d_t));
    cudaCheckError();
    i2d_to_device(d_input, input);

    // Start timer.
    uint64_t start_time = millis();

    for (uint32_t i = 0; i < iterations_count; i++) {
        cortex2d_t* prev_cortex = i % 2 ? d_odd_cortex : d_even_cortex;
        cortex2d_t* next_cortex = i % 2 ? d_even_cortex : d_odd_cortex;

        // TODO Fetch input.

        // Copy input to device.
        i2d_to_device(d_input, input);

        // Feed.
        c2d_feed2d<<<input_grid_size, input_block_size>>>(prev_cortex, d_input);
        cudaCheckError();
        cudaDeviceSynchronize();

        c2d_tick<<<cortex_grid_size, cortex_block_size>>>(prev_cortex, next_cortex);
        cudaCheckError();
        cudaDeviceSynchronize();

        if (i % 1000 == 0) {
            printf("\nPerformed %d iterations in %ldms\n", i, millis() - start_time);
        }

        // usleep(100);
    }

    // Stop timer.
    uint64_t end_time = millis();
    printf("\nCompleted %d iterations in %ldms\n", iterations_count, end_time - start_time);

    // Copy the cortex back to host to check the results.
    c2d_to_host(even_cortex, d_even_cortex);
    c2d_to_file(even_cortex, (char*) "out/test.c2d");

    // Cleanup.
    c2d_destroy(even_cortex);
    c2d_destroy(odd_cortex);
    c2d_device_destroy(d_even_cortex);
    c2d_device_destroy(d_odd_cortex);
    i2d_destroy(input);
    i2d_device_destroy(d_input);

    return 0;
}