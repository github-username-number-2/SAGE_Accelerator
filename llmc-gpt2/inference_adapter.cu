#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/types.h>

#include <sys/ioctl.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"
#include "llmc/utils.h"
typedef float floatX;
// ----------------------------------------------------------------------------
// GPT-2 model definition

typedef struct
{
    int max_seq_len;       // max sequence length, e.g. 1024
    int vocab_size;        // vocab size, e.g. 50257
    int padded_vocab_size; // padded to e.g. %128==0, 50304
    int num_layers;        // number of layers, e.g. 12
    int num_heads;         // number of heads in attention, e.g. 12
    int channels;          // number of channels, e.g. 768
} GPT2Config;

// the parameters of the model
constexpr const int NUM_PARAMETER_TENSORS = 16;
typedef struct
{
    floatX *wte;      // (V, C)
    floatX *wpe;      // (maxT, C)
    floatX *ln1w;     // (L, C)
    floatX *ln1b;     // (L, C)
    floatX *qkvw;     // (L, 3*C, C)
    floatX *qkvb;     // (L, 3*C)
    floatX *attprojw; // (L, C, C)
    floatX *attprojb; // (L, C)
    floatX *ln2w;     // (L, C)
    floatX *ln2b;     // (L, C)
    floatX *fcw;      // (L, 4*C, C)
    floatX *fcb;      // (L, 4*C)
    floatX *fcprojw;  // (L, C, 4*C)
    floatX *fcprojb;  // (L, C)
    floatX *lnfw;     // (C)
    floatX *lnfb;     // (C)
} ParameterTensors;
static_assert(sizeof(ParameterTensors) == NUM_PARAMETER_TENSORS * sizeof(void *), "Inconsistent sizes!");

void fill_in_parameter_sizes(size_t *param_sizes, size_t *param_sizeof, GPT2Config config)
{
    size_t Vp = config.padded_vocab_size;
    size_t C = config.channels;
    size_t maxT = config.max_seq_len;
    size_t L = config.num_layers;
    param_sizes[0] = Vp * C;           // wte
    param_sizes[1] = maxT * C;         // wpe
    param_sizes[2] = L * C;            // ln1w
    param_sizes[3] = L * C;            // ln1b
    param_sizes[4] = L * (3 * C) * C;  // qkvw
    param_sizes[5] = L * (3 * C);      // qkvb
    param_sizes[6] = L * C * C;        // attprojw
    param_sizes[7] = L * C;            // attprojb
    param_sizes[8] = L * C;            // ln2w
    param_sizes[9] = L * C;            // ln2b
    param_sizes[10] = L * (4 * C) * C; // fcw
    param_sizes[11] = L * (4 * C);     // fcb
    param_sizes[12] = L * C * (4 * C); // fcprojw
    param_sizes[13] = L * C;           // fcprojb
    param_sizes[14] = C;               // lnfw
    param_sizes[15] = C;               // lnfb

    // populate the parameter sizes in bytes (all the same for now, keeping for future use)
    for (int i = 0; i < NUM_PARAMETER_TENSORS; i++)
    {
        param_sizeof[i] = sizeof(floatX);
    }
}

constexpr int NUM_ACTIVATION_TENSORS = 21;
typedef struct
{
    floatX *encoded; // (B, T, C)
    floatX *ln1;     // (L, B, T, C)
    float *ln1_mean; // (L, B, T)
    float *ln1_rstd; // (L, B, T)
    floatX *atty;    // (L, B, T, C)
    // cuDNN saves only some statistics information
#if ENABLE_CUDNN
    float *att; // (L, B, NH, T)
#else
    floatX *att; // (L, B, NH, T, T)
#endif

    floatX *residual2; // (L, B, T, C)
    floatX *ln2;       // (L, B, T, C)
    float *ln2_mean;   // (L, B, T)
    float *ln2_rstd;   // (L, B, T)
    floatX *fch;       // (L, B, T, 4*C)
    floatX *fch_gelu;  // (L, B, T, 4*C)
    floatX *residual3; // (L, B, T, C)
    floatX *lnf;       // (B, T, C);   if LN recomputation is enabled (-r 2 and above), will be used for _all_ layernorms
    float *lnf_mean;   // (B, T)
    float *lnf_rstd;   // (B, T)
    float *losses;     // (B, T), will be accumulated in micro-steps
    // adding these two compared to the CPU .c code, needed for attention kernel as buffers
    floatX *qkvr; // (L, B, T, 3*C)
    // in inference mode, this buffer will store the logits
    // in training mode, this buffer will contain the *gradients* of the logits.
    // during the processing of transformer blocks, we will also use this as a
    // general scratchpad buffer. Allocation is made large enough to hold (B, T, 3C),
    // (B, NH, T, T), and (B, T, V) shaped tensors.
    floatX *output;

    // some additional scratch buffers
    floatX *scratch_bt4c; // (B, T, 4*C)
    floatX *scratch_btc;  // (B, T, C)
} ActivationTensors;

enum class DType : uint8_t {
    FP32, FP16, BF16
};

struct TensorSpec
{
    void **ptr;
    size_t size;
    DType type;
};

typedef struct
{
    floatX *down_w;
    floatX *down_b;
    floatX *up_w;
    floatX *up_b;
} AdapterParams;

typedef struct
{
    floatX *h;
} AdapterActs;

typedef struct
{
    floatX *down_w;
    floatX *down_b;
    floatX *up_w;
    floatX *up_b;
} AdapterGrads;

typedef struct
{
    GPT2Config config;
    // the weights of the model, and their sizes
    ParameterTensors params;
    size_t param_elements[NUM_PARAMETER_TENSORS];
    size_t param_sizeof[NUM_PARAMETER_TENSORS];
    void *params_memory;
    size_t num_parameters;
    size_t num_parameters_bytes;
    // gradients of the weights
    ParameterTensors grads;
    void *grads_memory;
    // buffers for the AdamW optimizer
    float *m_memory;
    float *v_memory;
    float *master_weights; // is NULL unless fp32 weights is enabled.
    // the activations of the model, and their sizes
    ActivationTensors acts;
    TensorSpec acts_specs[NUM_ACTIVATION_TENSORS];
    void *acts_memory;
    // other run state configuration
    int batch_size;                           // the batch size (B) of current forward pass
    int seq_len;                              // the sequence length (T) of current forward pass
    int *inputs;                              // the input tokens for the current forward pass
    int *targets;                             // the target tokens for the current forward pass
    float mean_loss;                          // after the last backward micro-batch, will be populated with mean loss across all GPUs and micro-steps
    float *accumulated_mean_loss;             // GPU buffer used to accumulate loss across micro-steps
    float *cpu_losses;                        // CPU buffer to copy the losses to, allocated with cudaMallocHost
    unsigned long long rng_state;             // the RNG state for seeding stochastic rounding etc.
    unsigned long long rng_state_last_update; // RNG before last gpt2_update() to re-round identically from master weights
    int use_master_weights;                   // keep master weights copy in float for optim update? 0|1
    bool init_state;                          // set to true if master weights need to be initialized
    int gelu_fusion;                          // fuse gelu via cuBLASLt (0=none, 1=forward, 2=forward+backward)
    int recompute;                            // recompute gelu | layernorm forward during model backward? 0|1|2
    // todo - if other functions need cpu scratch buffers in the future, reuse as generic scratch?
    int *workload_indices; // encoder_backward, B*T*num_c_groups (int)
    int4 *bucket_info;     // encoder_backward, B*T*num_c_groups (int4) - size for worst case

    int use_adapters; 
    int adapter_dim;  
    int freeze_base;  
    AdapterParams adapter;
    AdapterGrads adapter_grads;
    AdapterActs adapter_acts;
    void *adapter_params_mem;
    void *adapter_grads_mem;
    void *adapter_acts_mem;
    size_t adapter_param_elems;
} GPT2;

void gpt2_init_common(GPT2 *model)
{
    // common inits outside of the model weights
    // memory lazily initialized in forward()
    model->acts_memory = NULL;
    model->inputs = NULL;
    model->targets = NULL;
    model->accumulated_mean_loss = NULL;
    model->cpu_losses = NULL;
    // the B,T params are determined and set, fixed on first batch in forward()
    model->batch_size = 0;
    model->seq_len = 0;
    model->mean_loss = -1.0f; // -1.0f designates no loss, set at end of forward()
    model->params_memory = NULL;
    // memory lazily initialized in backward()
    model->grads_memory = NULL;
    model->workload_indices = NULL; // on cpu, for encoder_backward
    model->bucket_info = NULL;      // on cpu, for encoder_backward
    // memory lazily initialized in update()
    model->m_memory = NULL;
    model->v_memory = NULL;
    model->master_weights = NULL;
    // other default settings
    model->rng_state = 13371337 + multi_gpu_config.process_rank; // used in stochastic rounding
    model->use_master_weights = 1;                               // safe default: do keep master weights in fp32
    model->init_state = true;
    model->recompute = 1;   // good default: recompute gelu but not layernorm
    model->gelu_fusion = 0; // deviceProp.major >= 9 ? 2 : 0; // default: off for now (default must match main())

    model->use_adapters = 0;
    model->adapter_dim = 32;
    model->freeze_base = 1;
    model->adapter_params_mem = nullptr;
    model->adapter_grads_mem = nullptr;
    model->adapter_acts_mem = nullptr;
}

void gpt2_build_from_checkpoint(GPT2 *model, const char *checkpoint_path, bool weight_init = true)
{
    // If weight_init is true, we will load the weights from this checkpoint .bin file
    // We sometimes want this to be false, if we are going to initialize these weights from
    // the master weights that are instead stored in the state .bin file.
    // In that case, this function mostly loads the model hyperparameters from the header.

    if (PRECISION_MODE == PRECISION_FP16)
    {
        // TODO for later perhaps, would require us dynamically converting the
        // model weights from fp32 to fp16 online, here in this function, or writing
        // the fp16 weights directly from Python, which we only do for fp32/bf16 atm.
        fprintf(stderr, "build_from_checkpoint() does not support fp16 right now.\n");
        exit(EXIT_FAILURE);
    }

    // read in model from a checkpoint file
    FILE *model_file = fopenCheck(checkpoint_path, "rb");
    int model_header[256];multi_gpu_config
    freadCheck(model_header, sizeof(int), 256, model_file);
    if (model_header[0] != 20240326)
    {
        printf("Bad magic model file\n");
        exit(EXIT_FAILURE);
    }
    int version = model_header[1];
    if (!(version == 3 || version == 5))
    {
        // 3 = fp32, padded vocab
        // 5 = bf16, padded vocab, layernorms also in bf16
        fprintf(stderr, "Bad version in model file\n");
        fprintf(stderr, "---> HINT: try to re-run `python train_gpt2.py`\n");
        exit(EXIT_FAILURE);
    }

    // check if the precision mode of the checkpoing matches the model precision
    if (weight_init)
    {
        if (PRECISION_MODE == PRECISION_BF16 && version != 5)
        {
            fprintf(stderr, "Precision is configured as BF16 but model at %s is not.\n", checkpoint_path);
            fprintf(stderr, "---> HINT: are you sure you're loading a _bf16.bin file?\n");
            exit(EXIT_FAILURE);
        }
        if (PRECISION_MODE == PRECISION_FP32 && version != 3)
        {
            fprintf(stderr, "Precision is configured as FP32 but model at %s is not.\n", checkpoint_path);
            fprintf(stderr, "---> HINT: to turn on FP32 you have to compile like: `make train_gpt2cu PRECISION=FP32`\n");
            fprintf(stderr, "---> HINT: are you sure you're loading a .bin file without any _bf16 in the name?\n");
            exit(EXIT_FAILURE);
        }
    }

    // read in hyperparameters
    model->config.max_seq_len = model_header[2];
    model->config.vocab_size = model_header[3];
    model->config.num_layers = model_header[4];
    model->config.num_heads = model_header[5];
    model->config.channels = model_header[6];
    model->config.padded_vocab_size = model_header[7];

    // allocate memory for the model parameters
    gpt2_allocate_weights(model);

    // read in the parameters if weight_init is true
    if (weight_init)
    {
        assert(model->params_memory != NULL);
        file_to_device(model->params_memory, model_file, model->num_parameters_bytes, IO_BUF_SIZE, main_stream);
    }
    fcloseCheck(model_file);

    // only return from this function once we are certain the params are ready on the GPU
    cudaCheck(cudaDeviceSynchronize());
}

int main(int argc, char *argv[])
{
    GPT2 model;
    gpt2_init_common(&model);

    char *model_file = NULL;
    // filename must be provided in order to load the model

    for (int i = 1; i < argc; i+=2)
    {
        if(argv[i][0] != '-')
        {
            fprintf(stderr, "Usage: %s -<option> <value>\n", argv[0]);
            return 1;
        }
        if(argv[i][1] == 'm')
        {
            model_file = argv[i+1];
        }
    }

    gpt2_build_from_checkpoint(&model, model_file);

    return 0;
}
