/*
 * ffn.c
 *
 * Userspace test program for the FFN (Feed-Forward Network) FPGA adapter.
 *
 * Packs three 8x8 bf16 input matrices (mat_a, mat_b, mat_c) plus two bf16
 * bias values (bias_1, bias_2) into 97 x 32-bit words and sends them to the
 * FPGA through the PICOEVB_IOC_ADAPTER ioctl. The kernel driver drives the
 * 4-phase handshake against the AXI-Lite adapter register file. The FPGA
 * runs the FFN pipeline and returns a 32-word (8x8 bf16) output matrix.
 *
 * Packing (matches VHDL adapter_top.vhd, which uses in_elem_cnt[7:6] as the
 * matrix index and packs two 16-bit elements per 32-bit word, low element
 * first):
 *
 *   input[ 0 .. 31] = mat_a, row-major, 2 cols per word
 *   input[32 .. 63] = mat_b, row-major, 2 cols per word
 *   input[64 .. 95] = mat_c, row-major, 2 cols per word
 *   input[96]       = bias_1 (low 16 bits) | bias_2 (high 16 bits)
 *
 * Output:
 *   output[0 .. 31] = ffn_mat_final, row-major, 2 cols per word
 *
 * Usage:
 *   ./ffn                  # runs the built-in test vector
 
 

/*************************************************************************
 *                                   BF16 (Hex)
 *mat_a =
 *[
 *    [0x3DCD, 0x3E99, 0x3F00, 0x3F33, 0x3E99, 0x3E4C, 0x3DCD, 0x0000],
 *    [0x3C23, 0x3EE6, 0x3F19, 0x3F59, 0x3C23, 0x3DA3, 0x3E99, 0x3DF5],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000]
 *]

 *mat_b =
 *[
 *    [0x3DCD, 0x3F4C, 0x3E99, 0x3E4C, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3E4C, 0x3EB8, 0x3E4C, 0x3F05, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3CF5, 0x3E4C, 0x3DCD, 0x3F33, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3D23, 0x3E0F, 0x0000, 0x3F66, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3D4C, 0x3DCD, 0x3E94, 0x3DCD, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3F1E, 0x3DF5, 0x3ECC, 0x3F40, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3D8F, 0x3F66, 0x3EAE, 0x3DCD, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x3F61, 0x3ECC, 0x3DCD, 0x3ECC, 0x0000, 0x0000, 0x0000, 0x0000]
 *]

 *mat_c =
 *[
 *    [0x3DCD, 0x40A0, 0x4110, 0x3F80, 0x4080, 0x4000, 0x4040, 0x4110],
 *    [0x400C, 0x40C0, 0x4126, 0x4040, 0x40C0, 0x406C, 0x3F80, 0x40F3],
 *    [0x4040, 0x40E6, 0x4130, 0x4013, 0x4040, 0x3F80, 0x4033, 0x40C0],
 *    [0x4080, 0x4100, 0x4140, 0x40A0, 0x4000, 0x0000, 0x4110, 0x40A0],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
 *    [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000]
 *]

 *bias_1 = 0x3E99
 *bias_2 = 0x3F19

 *Final Output in BF16 (Hex):
 *[['0x411C' '0x41B3' '0x420B' '0x413D' '0x412B' '0x4089' '0x418E' '0x419E']
 * ['0x4131' '0x41CD' '0x4220' '0x415A' '0x4149' '0x40A5' '0x41A1' '0x41B7']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']
 * ['0x4014' '0x40AE' '0x4107' '0x402C' '0x4057' '0x3FEA' '0x4061' '0x40B6']]

 ***************************************************************************
 *                                  Decimal

 *mat_a = np.array([
 *    [0.10010, 0.29883, 0.50000, 0.69922, 0.29883, 0.19922, 0.10010, 0.00000],
 *    [0.00995, 0.44922, 0.59766, 0.84766, 0.00995, 0.07959, 0.29883, 0.11963],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000]
 *])

 *mat_b = np.array([
 *    [0.10010, 0.79688, 0.29883, 0.19922, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.19922, 0.35938, 0.19922, 0.51953, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.02991, 0.19922, 0.10010, 0.69922, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.03979, 0.13965, 0.00000, 0.89844, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.04980, 0.10010, 0.28906, 0.10010, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.61719, 0.11963, 0.39844, 0.75000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.06982, 0.89844, 0.33984, 0.10010, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.87891, 0.39844, 0.10010, 0.39844, 0.00000, 0.00000, 0.00000, 0.00000]
 *])

 *mat_c = np.array([
 *    [0.10010, 5.00000, 9.00000, 1.00000, 4.00000, 2.00000, 3.00000, 9.00000],
 *    [2.18750, 6.00000, 10.37500, 3.00000, 6.00000, 3.68750, 1.00000, 7.59375],
 *    [3.00000, 7.18750, 11.00000, 2.29688, 3.00000, 1.00000, 2.79688, 6.00000],
 *    [4.00000, 8.00000, 12.00000, 5.00000, 2.00000, 0.00000, 9.00000, 5.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000],
 *    [0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000, 0.00000]
 *])

 *bias_1 = 0.298828125
 *bias_2 = 0.59765625

 *final_output = [
 *    [ 9.7241, 22.3765, 34.8668, 11.8418, 10.6576,  4.2860, 17.7856, 19.7714],
 *    [11.0347, 25.5762, 40.0420, 13.6395, 12.5492,  5.1660, 20.1761, 22.8823],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891],
 *    [ 2.3114,  5.4297,  8.4165,  2.6821,  3.3654,  1.8316,  3.5124,  5.6891]
 *]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "../kernel-module/picoevb-rdma-ioctl.h"

/* ---------------------------------------------------------------- */
/* Built-in bf16 test vector                                        */
/* ---------------------------------------------------------------- */

static const uint16_t mat_a[8][8] = {
    { 0x3DCD, 0x3E99, 0x3F00, 0x3F33, 0x3E99, 0x3E4C, 0x3DCD, 0x0000 },
    { 0x3C23, 0x3EE6, 0x3F19, 0x3F59, 0x3C23, 0x3DA3, 0x3E99, 0x3DF5 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 }
};

static const uint16_t mat_b[8][8] = {
    { 0x3DCD, 0x3F4C, 0x3E99, 0x3E4C, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3E4C, 0x3EB8, 0x3E4C, 0x3F05, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3CF5, 0x3E4C, 0x3DCD, 0x3F33, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3D23, 0x3E0F, 0x0000, 0x3F66, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3D4C, 0x3DCD, 0x3E94, 0x3DCD, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3F1E, 0x3DF5, 0x3ECC, 0x3F40, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3D8F, 0x3F66, 0x3EAE, 0x3DCD, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x3F61, 0x3ECC, 0x3DCD, 0x3ECC, 0x0000, 0x0000, 0x0000, 0x0000 }
};

static const uint16_t mat_c[8][8] = {
    { 0x3DCD, 0x40A0, 0x4110, 0x3F80, 0x4080, 0x4000, 0x4040, 0x4110 },
    { 0x400C, 0x40C0, 0x4126, 0x4040, 0x40C0, 0x406C, 0x3F80, 0x40F3 },
    { 0x4040, 0x40E6, 0x4130, 0x4013, 0x4040, 0x3F80, 0x4033, 0x40C0 },
    { 0x4080, 0x4100, 0x4140, 0x40A0, 0x4000, 0x0000, 0x4110, 0x40A0 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 },
    { 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 }
};

static const uint16_t bias_1 = 0x3E99;
static const uint16_t bias_2 = 0x3F19;

/* ---------------------------------------------------------------- */
/* Packing helpers                                                  */
/*                                                                  */
/* pack_matrix()   packs an 8x8 uint16 matrix into 32 x 32-bit words,*/
/*                 low-half = even column, high-half = odd column.   */
/*                                                                  */
/* pack_biases()   packs bias_1 (low) and bias_2 (high) into one word.*/
/* ---------------------------------------------------------------- */

static void pack_matrix(const uint16_t mat[8][8], uint32_t *words)
{
    int r, c, w = 0;

    for (r = 0; r < 8; r++) {
        for (c = 0; c < 8; c += 2) {
            uint32_t lo = mat[r][c];
            uint32_t hi = mat[r][c + 1];
            words[w++] = (hi << 16) | lo;
        }
    }
}

static uint32_t pack_biases(uint16_t b1, uint16_t b2)
{
    return ((uint32_t)b2 << 16) | b1;
}

/* ---------------------------------------------------------------- */
/* Pretty-printer for the returned 8x8 matrix                       */
/* ---------------------------------------------------------------- */

static void print_output_matrix(const uint32_t *words)
{
    int r, c, w = 0;
    uint16_t out[8][8];

    for (r = 0; r < 8; r++) {
        for (c = 0; c < 8; c += 2) {
            uint32_t word = words[w++];
            out[r][c]     = word & 0xFFFF;
            out[r][c + 1] = (word >> 16) & 0xFFFF;
        }
    }

    printf("Output matrix (bf16 hex):\n");
    for (r = 0; r < 8; r++) {
        printf("  [ ");
        for (c = 0; c < 8; c++) {
            printf("0x%04X%s", out[r][c], (c == 7) ? "" : ", ");
        }
        printf(" ]\n");
    }
}

/* ---------------------------------------------------------------- */
/* main                                                             */
/* ---------------------------------------------------------------- */

int main(int argc, char **argv)
{
    struct picoevb_rdma_adapter adapter;
    int fd, ret;

    (void)argc;
    (void)argv;

    /* Zero the whole struct so we never send stale stack data. */
    memset(&adapter, 0, sizeof(adapter));

    /* --- Pack the 97 input words --- */
    pack_matrix(mat_a, &adapter.input[0]);   /* words  0 .. 31 */
    pack_matrix(mat_b, &adapter.input[32]);  /* words 32 .. 63 */
    pack_matrix(mat_c, &adapter.input[64]);  /* words 64 .. 95 */
    adapter.input[96] = pack_biases(bias_1, bias_2); /* word 96 */

    /* Sanity print of the packed input */
    printf("Packed input (97 words):\n");
    for (int i = 0; i < 97; i++) {
        printf("  input[%2d] = 0x%08X\n", i, adapter.input[i]);
    }
    printf("\n");

    /* --- Open the device --- */
    fd = open("/dev/picoevb", O_RDWR);
    if (fd < 0) {
        perror("open /dev/picoevb");
        return 1;
    }

    /* --- Run the FFN ioctl --- */
    printf("Issuing PICOEVB_IOC_ADAPTER ...\n");
    ret = ioctl(fd, PICOEVB_IOC_ADAPTER, &adapter);
    if (ret != 0) {
        perror("ioctl PICOEVB_IOC_ADAPTER");
        close(fd);
        return 1;
    }
    printf("ioctl returned 0 (success)\n\n");

    /* --- Print raw 32-word output --- */
    printf("Raw output (32 words):\n");
    for (int i = 0; i < 32; i++) {
        printf("  output[%2d] = 0x%08X\n", i, adapter.output[i]);
    }
    printf("\n");

    /* --- Print unpacked 8x8 result --- */
    print_output_matrix(adapter.output);

    close(fd);
    return 0;
}



