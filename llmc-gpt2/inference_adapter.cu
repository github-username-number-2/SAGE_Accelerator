#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/types.h>

#include <assert.h>

#include <sys/ioctl.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"


#include "llmc/cuda_common.h"

#include "llmc/cuda_utils.cuh"

#include "llmc/rand.h"

#include "llmc/cublas_common.h"

#include "llmc/tokenizer.h"

#include "llmc/zero.cuh"

#include "llmc/sampler.h"
// ----------- Layer implementations in CUDA -----------
// defines: encoder_forward, encoder_backward
#include "llmc/encoder.cuh"
// defines: layernorm_forward, residual_forward, fused_residual_forward5, layernorm_backward
#include "llmc/layernorm.cuh"
// defines: matmul_cublaslt, matmul_forward, matmul_backward, gelu_forward, gelu_backward_inplace
#include "llmc/matmul.cuh"

#include "llmc/attention.cuh"
// ----------------------------------------------------------------------------
// global vars for I/O
char filename_buffer[512];

// ----------------------------------------------------------------------------
// global vars containing information about the GPU this process is running on
cudaDeviceProp deviceProp; // fills in common_start()
cudaStream_t main_stream;
// buffer size to use for device <-> disk io
constexpr const size_t IO_BUF_SIZE = 32 * 1024 * 1024;
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
// allocate memory for the parameters and point the individual tensors to the right places
void *malloc_and_point_parameters(ParameterTensors *params, size_t *param_elements, size_t *param_sizeof)
{
    // calculate the total number of parameters and bytes across all tensors
    size_t num_parameters_bytes = 0;
    for (int i = 0; i < NUM_PARAMETER_TENSORS; i++)
    {
        num_parameters_bytes += param_elements[i] * param_sizeof[i];
    }
    // malloc all parameters all at once on the device
    void *params_memory;
    cudaCheck(cudaMalloc((void **)&params_memory, num_parameters_bytes));
    // assign all the tensors their place in the array
    floatX **ptrs[] = {
        &params->wte, &params->wpe, &params->ln1w, &params->ln1b, &params->qkvw, &params->qkvb,
        &params->attprojw, &params->attprojb, &params->ln2w, &params->ln2b, &params->fcw, &params->fcb,
        &params->fcprojw, &params->fcprojb, &params->lnfw, &params->lnfb};
    char *params_memory_iterator = (char *)params_memory;
    for (int i = 0; i < NUM_PARAMETER_TENSORS; i++)
    {
        *(ptrs[i]) = (floatX *)params_memory_iterator;
        params_memory_iterator += param_elements[i] * param_sizeof[i];
    }
    return params_memory;
}
void gpt2_allocate_weights(GPT2 *model)
{
    // fill in all the parameter tensor dimensions and types
    fill_in_parameter_sizes(model->param_elements, model->param_sizeof, model->config);
    model->num_parameters = 0;
    model->num_parameters_bytes = 0;
    for (int i = 0; i < NUM_PARAMETER_TENSORS; i++)
    {
        model->num_parameters += model->param_elements[i];
        model->num_parameters_bytes += model->param_elements[i] * model->param_sizeof[i];
    }
    // create memory for model parameters on the device
    assert(model->params_memory == nullptr);
    model->params_memory = malloc_and_point_parameters(&model->params, model->param_elements, model->param_sizeof);
}

void gpt2_build_from_checkpoint(GPT2 *model, const char *checkpoint_path, bool weight_init = true)
{
    // read in model from a checkpoint file
    FILE *model_file = fopenCheck(checkpoint_path, "rb");
    int model_header[256];
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
void common_start(bool override_enable_tf32 = true, bool print_device_info = true)
{

    // get CUDA device infos
    cudaCheck(cudaGetDeviceProperties(&deviceProp, multi_gpu_config.local_device_idx));
    if (print_device_info)
    {
        printf("[System]\n");
        printf("Device %d: %s\n", multi_gpu_config.local_device_idx, deviceProp.name);
    }

    // set up the cuda streams. atm everything is on the single main stream
    cudaCheck(cudaStreamCreate(&main_stream));
    nvtxNameCudaStreamA(main_stream, "main stream");

    // set up cuBLAS and cuBLASLt
    cublasCheck(cublasLtCreate(&cublaslt_handle));
    cudaCheck(cudaMalloc(&cublaslt_workspace, cublaslt_workspace_size));

    // TF32 precision is equivalent to torch.set_float32_matmul_precision('high')
    bool enable_tf32 = PRECISION_MODE == PRECISION_FP32 && deviceProp.major >= 8 && override_enable_tf32;
    cublas_compute = enable_tf32 ? CUBLAS_COMPUTE_32F_FAST_TF32 : CUBLAS_COMPUTE_32F;

#ifdef ENABLE_CUDNN
    create_cudnn();
#endif
}


#define TENSOR_SPEC(pointer, size) TensorSpec{(void **)(&pointer), (size), dtype_of(pointer)};

void fill_in_activation_sizes(const ActivationTensors *data, TensorSpec (&tensors)[NUM_ACTIVATION_TENSORS], size_t B, size_t T, GPT2Config config, int recompute)
{
    size_t Vp = config.padded_vocab_size;
    size_t L = config.num_layers;
    size_t NH = config.num_heads;
    size_t C = config.channels;
    tensors[0] = TENSOR_SPEC(data->encoded, B * T * C);
    // if recompute >= 1 then we will recompute the layernorm forward activation during backward pass
    tensors[1] = TENSOR_SPEC(data->ln1, (recompute < 2) ? L * B * T * C : 0);
    tensors[2] = TENSOR_SPEC(data->ln1_mean, L * B * T);
    tensors[3] = TENSOR_SPEC(data->ln1_rstd, L * B * T);
    tensors[4] = TENSOR_SPEC(data->atty, L * B * T * C);
#ifdef ENABLE_CUDNN
    // FP32 stats tensor for cuDNN to be passed to backward pass
    tensors[5] = TENSOR_SPEC(data->att, L * B * NH * T);
#else
    tensors[5] = TENSOR_SPEC(data->att, L * B * NH * T * T);
#endif
    tensors[6] = TENSOR_SPEC(data->residual2, L * B * T * C);
    // if recompute >= 1 then we will recompute the layernorm forward activation during backward pass
    tensors[7] = TENSOR_SPEC(data->ln2, (recompute < 2) ? L * B * T * C : 0);
    tensors[8] = TENSOR_SPEC(data->ln2_mean, L * B * T);
    tensors[9] = TENSOR_SPEC(data->ln2_rstd, L * B * T);
    tensors[10] = TENSOR_SPEC(data->fch, L * B * T * 4 * C);
    // if recompute >= 1 then we will recompute gelu_forward during backward and use this as scratch buffer
    tensors[11] = TENSOR_SPEC(data->fch_gelu, (recompute < 1) ? L * B * T * 4 * C : B * T * 4 * C);
    tensors[12] = TENSOR_SPEC(data->residual3, L * B * T * C);
    tensors[13] = TENSOR_SPEC(data->lnf, B * T * C);
    tensors[14] = TENSOR_SPEC(data->lnf_mean, B * T);
    tensors[15] = TENSOR_SPEC(data->lnf_rstd, B * T);
    tensors[16] = TENSOR_SPEC(data->losses, B * T);
    tensors[17] = TENSOR_SPEC(data->qkvr, L * B * T * 3 * C);
    tensors[18] = TENSOR_SPEC(data->output, B * T * max(3 * C, max(NH * T, Vp)));

    tensors[19] = TENSOR_SPEC(data->scratch_bt4c, B * T * 4 * C);
    tensors[20] = TENSOR_SPEC(data->scratch_btc, B * T * C);
}


void *malloc_and_point_activations(TensorSpec (&tensors)[NUM_ACTIVATION_TENSORS])
{
    size_t bytes = 0;
    for (size_t i = 0; i < NUM_ACTIVATION_TENSORS; i++)
    {
        bytes += tensors[i].size * sizeof_dtype(tensors[i].type);
    }

    printf0("allocating %d MiB for activations\n", (int)round(bytes / (1024 * 1024)));

    void *acts_memory;
    cudaCheck(cudaMalloc((void **)&acts_memory, bytes));

    // cudaMalloc does not guarantee initial memory values so we memset the allocation here
    // this matters because e.g. non-cuDNN attention assumes the attention buffer is zeroed
    // todo - up to ~100ms on slow GPUs, could theoretically be more selective, but this is safer
    cudaCheck(cudaMemset(acts_memory, 0, bytes));

    char *acts_memory_iterator = (char *)acts_memory;
    for (size_t i = 0; i < NUM_ACTIVATION_TENSORS; i++)
    {
        // extra protection so we don't accidentally use an empty buffer
        if (tensors[i].size == 0)
        {
            *(tensors[i].ptr) = NULL;
        }
        else
        {
            *(tensors[i].ptr) = acts_memory_iterator;
            acts_memory_iterator += tensors[i].size * sizeof_dtype(tensors[i].type);
        }
    }
    return acts_memory;
}
void gpt2_allocate_state(GPT2 *model, int B, int T)
{
    printf0("allocating %d MiB for parameter gradients\n", (int)round(model->num_parameters * sizeof(floatX) / (1024 * 1024)));
    assert(model->grads_memory == nullptr);
    model->grads_memory = malloc_and_point_parameters(&model->grads, model->param_elements, model->param_sizeof);

    // record the current B,T as well
    model->batch_size = B;
    model->seq_len = T;

    // allocate the space
    fill_in_activation_sizes(&model->acts, model->acts_specs, B, T, model->config, model->recompute);
    model->acts_memory = malloc_and_point_activations(model->acts_specs);
    // also create memory for caching inputs and targets
    cudaCheck(cudaMalloc((void **)&model->inputs, B * T * sizeof(int)));
    cudaCheck(cudaMalloc((void **)&model->targets, B * T * sizeof(int)));
    cudaCheck(cudaMalloc(((void **)&model->accumulated_mean_loss), sizeof(float)));
    cudaCheck(cudaMallocHost((void **)&model->cpu_losses, B * T * sizeof(float)));

    // initialise cpu scratch buffers for encoder backward
    size_t num_c_groups = CEIL_DIV(model->config.channels, (WARP_SIZE * x128::size));
    assert((size_t)(model->batch_size * model->seq_len) * num_c_groups < (1ULL << 31ULL)); // todo - maybe an issue for llama3-400B(?)
    model->workload_indices = (int *)mallocCheck(sizeof(int) * model->batch_size * model->seq_len * num_c_groups);
    model->bucket_info = (int4 *)mallocCheck(sizeof(int4) * model->batch_size * model->seq_len * num_c_groups);

    // cudaMallocConditionallyManaged can fall back to cudaMallocManaged if not enough memory on device
    // and returns a status code of 1 if it had to fall back, in that case we want to print warning.
    int memory_status = 0;

    // we will now init the optimizer states and master weights
    // this is usually a substantial amount of memory allocation right here.
    size_t shard_num_parameters = multi_gpu_config.shard_num_parameters; // num parameters we are responsible for
    printf0("allocating %zu MiB for AdamW optimizer state m\n", (shard_num_parameters * sizeof(float)) >> 20);
    printf0("allocating %zu MiB for AdamW optimizer state v\n", (shard_num_parameters * sizeof(float)) >> 20);
    assert(model->m_memory == nullptr);
    assert(model->v_memory == nullptr);
    memory_status |= cudaMallocConditionallyManaged((void **)&model->m_memory, shard_num_parameters * sizeof(float));
    memory_status |= cudaMallocConditionallyManaged((void **)&model->v_memory, shard_num_parameters * sizeof(float));

    if (model->use_master_weights == 1)
    {
        assert(model->master_weights == nullptr);
        printf0("allocating %zu MiB for master copy of params\n", (shard_num_parameters * sizeof(float)) >> 20);
        memory_status |= cudaMallocConditionallyManaged((void **)&model->master_weights, shard_num_parameters * sizeof(float));
    }

    // report on mixed memory allocation status (re-using our float reduce function, bit awk ok)
    int reduced_memory_status = (int)multi_gpu_cpu_float_sum((float)memory_status, &multi_gpu_config);
    if (reduced_memory_status >= 1)
    {
        printf0("WARNING: Fell back to cudaMallocManaged when initializing m,v,master_weights on %d GPUs\n", reduced_memory_status);
        printf0("         Prevents an OOM, but code may run much slower due to device <-> host memory movement\n");
    }
    // report on device memory usage
    size_t free, total;
    cudaCheck(cudaMemGetInfo(&free, &total));
    printf0("device memory usage: %zd MiB / %zd MiB\n", (total - free) / 1024 / 1024, total / 1024 / 1024);
    // give an estimate of the maximum batch size
    size_t bytes_per_sequence = 0;
    for (size_t i = 0; i < NUM_ACTIVATION_TENSORS; i++)
    {
        bytes_per_sequence += model->acts_specs[i].size * sizeof_dtype(model->acts_specs[i].type) / B;
    }
    printf0("memory per sequence: %zu MiB\n", bytes_per_sequence / 1024 / 1024);
    printf0(" -> estimated maximum batch size: %zu\n", B + free / bytes_per_sequence);
}
static void allocate_adapters(GPT2 *model, int B, int T)
{
    if (!model->use_adapters)
        return;
    int L = model->config.num_layers;
    int C = model->config.channels;
    int r = model->adapter_dim;
    size_t ne_down_w = (size_t)L * C * r;
    size_t ne_down_b = (size_t)L * r;
    size_t ne_up_w = (size_t)L * r * C;
    size_t ne_up_b = (size_t)L * C;
    model->adapter_param_elems = ne_down_w + ne_down_b + ne_up_w + ne_up_b;
    size_t bytes = model->adapter_param_elems * sizeof(floatX);
    cudaCheck(cudaMalloc(&model->adapter_params_mem, bytes));
    cudaCheck(cudaMalloc(&model->adapter_grads_mem, bytes));
    cudaCheck(cudaMemset(model->adapter_grads_mem, 0, bytes));

    char *p = (char *)model->adapter_params_mem;
    model->adapter.down_w = (floatX *)p;
    p += ne_down_w * sizeof(floatX);
    model->adapter.down_b = (floatX *)p;
    p += ne_down_b * sizeof(floatX);
    model->adapter.up_w = (floatX *)p;
    p += ne_up_w * sizeof(floatX);
    model->adapter.up_b = (floatX *)p;

    p = (char *)model->adapter_grads_mem;
    model->adapter_grads.down_w = (floatX *)p;
    p += ne_down_w * sizeof(floatX);
    model->adapter_grads.down_b = (floatX *)p;
    p += ne_down_b * sizeof(floatX);
    model->adapter_grads.up_w = (floatX *)p;
    p += ne_up_w * sizeof(floatX);
    model->adapter_grads.up_b = (floatX *)p;

    // activations
    size_t ne_h = (size_t)L * B * T * r;
    cudaCheck(cudaMalloc(&model->adapter_acts_mem, ne_h * sizeof(floatX)));
    model->adapter_acts.h = (floatX *)model->adapter_acts_mem;

    {
        floatX *tmp_down = (floatX *)mallocCheck(ne_down_w * sizeof(floatX));
        float *tmp_down_f32 = (float *)mallocCheck(ne_down_w * sizeof(float));
        mt19937_state rng;
        manual_seed(&rng, 123);
        normal_(tmp_down_f32, ne_down_w, 0.0f, 0.02f, &rng);
        // Convert float to floatX
        for (size_t i = 0; i < ne_down_w; i++) {
            tmp_down[i] = (floatX)tmp_down_f32[i];
        }
        cudaCheck(cudaMemcpy(model->adapter.down_w, tmp_down, ne_down_w * sizeof(floatX), cudaMemcpyHostToDevice));
        free(tmp_down_f32);
        free(tmp_down);

        cudaCheck(cudaMemset(model->adapter.down_b, 0, ne_down_b * sizeof(floatX)));
        cudaCheck(cudaMemset(model->adapter.up_w, 0, ne_up_w * sizeof(floatX)));
        cudaCheck(cudaMemset(model->adapter.up_b, 0, ne_up_b * sizeof(floatX)));
    }
    printf0("adapters: r=%d params=%.2fM (%.2f MiB)\n",
            r, model->adapter_param_elems / 1e6,
            (double)bytes / 1024.0 / 1024.0);
}

void read_adapter_header(const char *filename, GPT2 *model, int *B, int *L, int *C, int *r, int *T)
{
    FILE *adapter_file = fopenCheck(filename, "rb");
    freadCheck(B, sizeof(int), 1, adapter_file);
    freadCheck(L, sizeof(int), 1, adapter_file);
    freadCheck(C, sizeof(int), 1, adapter_file);
    freadCheck(r, sizeof(int), 1, adapter_file);
    freadCheck(T, sizeof(int), 1, adapter_file);
    model->adapter_dim = *r;
    fcloseCheck(adapter_file);
}

void load_adapter(const char *filename, GPT2 *model, int *B, int *L, int *C, int *r, int *T)
{
    FILE *adapter_file = fopenCheck(filename, "rb");
    freadCheck(B, sizeof(int), 1, adapter_file);
    freadCheck(L, sizeof(int), 1, adapter_file);
    freadCheck(C, sizeof(int), 1, adapter_file);
    freadCheck(r, sizeof(int), 1, adapter_file);
    freadCheck(T, sizeof(int), 1, adapter_file);
    // model->adapter_dim = *r;
    size_t nelements = (size_t)(*L) * (*C) * (*r);
    printf("Inside load_adapter: B=%d, L=%d, C=%d, r=%d, T=%d\n", *B, *L, *C, *r, *T);

    file_to_device(model->adapter.down_w, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    nelements = (size_t)(*L) * (*r);
    file_to_device(model->adapter.down_b, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    nelements = (size_t)(*L) * (*r) * (*C);
    file_to_device(model->adapter.up_w, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    nelements = (size_t)(*L) * (*C);
    file_to_device(model->adapter.up_b, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    // nelements = (size_t)(*L) * (*C) * (*r);
    // file_to_device(model->adapter_grads.down_w, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    // nelements = (size_t)(*L) * (*r);
    // file_to_device(model->adapter_grads.down_b, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    // nelements = (size_t)(*L) * (*r) * (*C);
    // file_to_device(model->adapter_grads.up_w, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    // nelements = (size_t)(*L) * (*C);
    // file_to_device(model->adapter_grads.up_b, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    // nelements = (size_t)(*B) * (*L) * (*T) * (*r);
    // file_to_device(model->adapter_acts.h, adapter_file, nelements * sizeof(floatX), IO_BUF_SIZE, main_stream);
    cudaCheck(cudaStreamSynchronize(main_stream));

    // printf0("Loaded adapter\n");
    // print_adapter_params<<<1, 32>>>(model->adapter_acts.h, 10, "h");
    // print_adapter_params<<<1, 32>>>(model->adapter.down_w, 10, "down_w");
    // print_adapter_params<<<1, 32>>>(model->adapter.down_b, 10, "down_b");
    // print_adapter_params<<<1, 32>>>(model->adapter.up_w, 10, "up_w");
    // print_adapter_params<<<1, 32>>>(model->adapter.up_b, 10, "up_b");
    // print_adapter_params<<<1, 32>>>(model->adapter_grads.down_w, 10, "down_w_grad");
    // print_adapter_params<<<1, 32>>>(model->adapter_grads.down_b, 10, "down_b_grad");
    // print_adapter_params<<<1, 32>>>(model->adapter_grads.up_w, 10, "up_w_grad");
    // print_adapter_params<<<1, 32>>>(model->adapter_grads.up_b, 10, "up_b_grad");
    // cudaCheck(cudaStreamSynchronize(main_stream));
    fcloseCheck(adapter_file);
}
void adapter_forward_add(
    floatX *out_btc, // (B,T,C) output, added to existing value
    floatX *in_btc,  // (B,T,C) input
    floatX *h_btr, // (B,T,r) scratch
    floatX *scratch_btc, // (B,T,C) scratch
    floatX *down_w, floatX *down_b,
    floatX *up_w, floatX *up_b,
    int B, int T, int C, int r)
{
    // printf0("adapter_forward_add B=%d T=%d C=%d r=%d\n", B, T, C, r);
    // Down: (B,T,C)->(B,T,r)
    matmul_forward_cublaslt(h_btr, in_btc, down_w, down_b, B, T, C, r, main_stream);
    printf("inside adapter_forward_add: B=%d T=%d C=%d r=%d\n", B, T, C, r);
    gelu_forward(h_btr, h_btr, B * T * r, main_stream);
    // Up: (B,T,r)->scratch (B,T,C)
    matmul_forward_cublaslt(scratch_btc, h_btr, up_w, up_b, B, T, r, C, main_stream);
    // out += scratch
    residual_forward(out_btc, out_btc, scratch_btc, B * T * C, main_stream);
}
void gpt2_forward(GPT2 *model, const int *inputs, size_t B, size_t T)
{
    NVTX_RANGE_FN();
    // we must be careful and use size_t instead of int, otherwise
    // we could overflow int. E.g. l * B * NH * T * T overflows int at B 16.

    // ensure the model was initialized or error out
    if (model->params_memory == NULL)
    {
        printf("Error: model was not initialized properly.\n");
        exit(EXIT_FAILURE);
    }

    // convenience parameters
    const size_t V = model->config.vocab_size;
    const size_t Vp = model->config.padded_vocab_size;
    const size_t L = model->config.num_layers;
    const size_t NH = model->config.num_heads;
    const size_t C = model->config.channels;

    // validate B,T are not larger than the values used at initialisation
    // (smaller B,T are okay for inference only)
    if (B > model->batch_size || T > model->seq_len)
    {
        printf("Model: B=%d T=%d, Desired: B=%d T=%d\n", model->batch_size, model->seq_len, (int)B, (int)T);
        exit(EXIT_FAILURE);
    }

    // copy inputs/targets to the model
    cudaCheck(cudaMemcpy(model->inputs, inputs, B * T * sizeof(int), cudaMemcpyHostToDevice));
    // validate inputs, all indices must be in the range [0, V)
    // we can do this while the copies are already underway
    tokenCheck(inputs, B * T, V);

    // forward pass
    ParameterTensors params = model->params; // for brevity
    ActivationTensors acts = model->acts;
    encoder_forward(acts.encoded, model->inputs, params.wte, params.wpe, B, T, C, main_stream); // encoding goes into residual[0]

    // first layernorm isn't fused
    layernorm_forward((model->recompute < 2) ? acts.ln1 : acts.lnf, acts.ln1_mean, acts.ln1_rstd, acts.encoded, params.ln1w, params.ln1b, B, T, C, main_stream);

    for (int l = 0; l < L; l++)
    {
        NvtxRange layer_range("Layer", l);

        floatX *residual = l == 0 ? acts.encoded : acts.residual3 + (l - 1) * B * T * C;

        // get the pointers of the weights for this layer
        floatX *l_qkvw = params.qkvw + l * 3 * C * C;
        floatX *l_qkvb = params.qkvb + l * 3 * C;
        floatX *l_attprojw = params.attprojw + l * C * C;
        floatX *l_attprojb = params.attprojb + l * C;
        floatX *l_ln2w = params.ln2w + l * C;
        floatX *l_ln2b = params.ln2b + l * C;
        floatX *l_fcw = params.fcw + l * 4 * C * C;
        floatX *l_fcb = params.fcb + l * 4 * C;
        floatX *l_fcprojw = params.fcprojw + l * C * 4 * C;
        floatX *l_fcprojb = params.fcprojb + l * C;

        // get the pointers of the activations for this layer
        floatX *l_ln1 = (model->recompute < 2) ? acts.ln1 + l * B * T * C : acts.lnf;
        floatX *l_qkvr = acts.qkvr + l * B * T * 3 * C;
        floatX *l_atty = acts.atty + l * B * T * C;
        floatX *l_residual2 = acts.residual2 + l * B * T * C;
        floatX *l_ln2 = (model->recompute < 2) ? acts.ln2 + l * B * T * C : acts.lnf;
        float *l_ln2_mean = acts.ln2_mean + l * B * T;
        float *l_ln2_rstd = acts.ln2_rstd + l * B * T;
        floatX *l_fch = acts.fch + l * B * T * 4 * C;
        // reuse the same activation buffer at each layer, as we'll re-compute the gelu during backward
        // very useful because we dramatically reduce VRAM usage, and may be able to fit larger batch size
        floatX *l_fch_gelu = (model->recompute < 1) ? acts.fch_gelu + l * B * T * 4 * C : acts.fch_gelu;
        floatX *l_residual3 = acts.residual3 + l * B * T * C;
        floatX *scratch = (floatX *)acts.output; // used for non-cudnn attention, fcproj, attproj, etc.

// now do the forward pass
#ifdef ENABLE_CUDNN
        float *l_att = (float *)acts.att + l * B * NH * T; // cuDNN needs a smaller FP32 tensor
        matmul_forward_cublaslt(l_qkvr, l_ln1, l_qkvw, l_qkvb, B, T, C, 3 * C, main_stream);
        attention_forward_cudnn(l_atty, (float *)l_att, l_qkvr, B, T, NH, C, main_stream);
#else
        floatX *l_att = acts.att + l * B * NH * T * T;
        if (T != model->seq_len)
        { // unused parts of attention buffer must be zeroed (T-dependent)
            cudaCheck(cudaMemset(l_att, 0, B * NH * T * T * sizeof(floatX)));
        }
        // these are only needed as scratchpads for the forward pass, but
        // need not be stored for backward
        matmul_forward_cublaslt(scratch, l_ln1, l_qkvw, l_qkvb, B, T, C, 3 * C, main_stream);
        attention_forward(l_atty, l_qkvr, l_att, scratch, B, T, C, NH, main_stream);
#endif
        matmul_forward_cublaslt(scratch, l_atty, l_attprojw, l_attprojb, B, T, C, C, main_stream);
        
        // print_adapter_params<<<1,32>>>(scratch, 10, "sc1");
        if (model->use_adapters)
        {
            // adapter. input is l_ln1, output is added to scratch
            int r = model->adapter_dim;
            floatX *h = model->adapter_acts.h + (size_t)l * B * model->seq_len * r;
            floatX *dw = model->adapter.down_w + (size_t)l * C * r;
            floatX *db = model->adapter.down_b + (size_t)l * r;
            floatX *uw = model->adapter.up_w + (size_t)l * r * C;
            floatX *ub = model->adapter.up_b + (size_t)l * C;


            adapter_forward_add(scratch, l_ln1, h, acts.scratch_btc, dw, db, uw, ub, B, T, C, r);
        }

        if (model->use_adapters)
        {
            // residual add
            residual_forward(l_residual2, residual, scratch, B * T * C, main_stream);
            layernorm_forward(l_ln2, l_ln2_mean, l_ln2_rstd, l_residual2, l_ln2w, l_ln2b, B, T, C, main_stream);
        }
        else
        {
            fused_residual_forward5(l_residual2, l_ln2, l_ln2_mean, l_ln2_rstd,
                                    residual, scratch, l_ln2w, l_ln2b, B * T, C, main_stream);
        }

        // print_adapter_params<<<1,32>>>(scratch, 10, "sc2");
        matmul_forward_cublaslt(l_fch_gelu, l_ln2, l_fcw, l_fcb, B, T, C, 4 * C, main_stream, l_fch, model->gelu_fusion);
        matmul_forward_cublaslt(scratch, l_fch_gelu, l_fcprojw, l_fcprojb, B, T, 4 * C, C, main_stream);
        // OK, fusion across blocks.
        if (l + 1 != L)
        {
            floatX *l_ln1 = (model->recompute < 2) ? acts.ln1 + (l + 1) * B * T * C : acts.lnf;
            float *l_ln1_mean = acts.ln1_mean + (l + 1) * B * T;
            float *l_ln1_rstd = acts.ln1_rstd + (l + 1) * B * T;
            const floatX *l_ln1w = params.ln1w + (l + 1) * C;
            const floatX *l_ln1b = params.ln1b + (l + 1) * C;
            fused_residual_forward5(l_residual3, l_ln1, l_ln1_mean, l_ln1_rstd, l_residual2, scratch, l_ln1w, l_ln1b,
                                    B * T, C, main_stream);
        }
        else
        {
            fused_residual_forward5(l_residual3, acts.lnf, acts.lnf_mean, acts.lnf_rstd, l_residual2, scratch,
                                    params.lnfw, params.lnfb,
                                    B * T, C, main_stream);
        }
    }

    matmul_forward_cublaslt(acts.output, acts.lnf, params.wte, NULL, B, T, C, Vp, main_stream);
    cudaCheck(cudaDeviceSynchronize());
}

void common_free(GPT2 &model)
{
    cudaCheck(cudaStreamDestroy(main_stream));
    cudaCheck(cudaFree(cublaslt_workspace));
    cublasCheck(cublasLtDestroy(cublaslt_handle));
#ifdef ENABLE_CUDNN
    destroy_cudnn();
#endif
}

int main(int argc, char *argv[]) {
    const char *model_path = "model.bin";
    const char *adapter_path = "adapter_params.bin";
    int genT = 64;
    int B = 16;
    int T = 1024;

    for (int i = 1; i < argc; i += 2) {
        if (i + 1 >= argc) break;
        if (strcmp(argv[i], "-e") == 0) model_path = argv[i + 1];
        else if (strcmp(argv[i], "-a") == 0) adapter_path = argv[i + 1];
        else if (strcmp(argv[i], "-g") == 0) genT = atoi(argv[i + 1]);
        else if (strcmp(argv[i], "-t") == 0) T = atoi(argv[i + 1]);
    }

    common_start();

    GPT2 model;
    gpt2_init_common(&model);
    gpt2_build_from_checkpoint(&model, model_path);

    model.use_adapters = 1;

    // allocate_adapters(&model, B, T);
    // printf("Hello!\n");
    int a_B = 0, a_L = 0, a_C = 0, a_r = 0, a_T = 0;
    read_adapter_header(adapter_path, &model, &a_B, &a_L, &a_C, &a_r, &a_T);

    gpt2_allocate_state(&model, B, T);
    allocate_adapters(&model, model.batch_size, model.seq_len);
    load_adapter(adapter_path, &model, &a_B, &a_L, &a_C, &a_r, &a_T);
    printf("Loaded adapters: dim=%d, layers=%d, channels=%d\n", a_r, a_L, a_C);

    Tokenizer tokenizer;
    tokenizer_init(&tokenizer, "gpt2_tokenizer.bin");

    int *gen_tokens = (int *)mallocCheck(B * T * sizeof(int));
    floatX *cpu_logits_raw = (floatX *)mallocCheck(model.config.vocab_size * sizeof(floatX));
    float *cpu_logits = (float *)mallocCheck(model.config.vocab_size * sizeof(float));

    unsigned long long sample_rng_state = 1337;
    int eot_token = tokenizer.init_ok ? tokenizer.eot_token : 50256;
    for (int i = 0; i < B * T; ++i) gen_tokens[i] = eot_token;

    printf("Generating tokens:\n---\n");
    for (int t = 1; t < genT; t++) {
        int current_seq_len = CEIL_DIV(t, 512) * 512;
        gpt2_forward(&model, gen_tokens, B, current_seq_len);

        floatX *logits = model.acts.output + (t - 1) * model.config.padded_vocab_size;
        cudaCheck(cudaMemcpy(cpu_logits_raw, logits, model.config.vocab_size * sizeof(floatX), cudaMemcpyDeviceToHost));

        for (int i = 0; i < model.config.vocab_size; i++) {
            cpu_logits[i] = (float)cpu_logits_raw[i];
        }

        float coin = random_f32(&sample_rng_state);
        int next_token = sample_softmax(cpu_logits, model.config.vocab_size, coin);
        gen_tokens[t] = next_token;

        if (tokenizer.init_ok) {
            safe_printf(tokenizer_decode(&tokenizer, next_token));
        } else {
            printf("%d ", next_token);
        }
        fflush(stdout);
    }
    printf("\n---\n");

    free(gen_tokens);
    free(cpu_logits_raw);
    free(cpu_logits);
    tokenizer_free(&tokenizer);
    common_free(model);

    return 0;
}