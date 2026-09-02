/*
 * Copyright (c) 2019, NVIDIA CORPORATION.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 */

#ifndef __PICOEVB_RDMA_IOCTL_H__
#define __PICOEVB_RDMA_IOCTL_H__

#include <linux/types.h>
#include <linux/ioctl.h>

/* Standard PicoEVB RDMA Structures */
struct picoevb_rdma_pin_cuda {
	__u64 va;
	__u64 size;
	__s32 handle;
};

struct picoevb_rdma_unpin_cuda {
	__s32 handle;
};

struct picoevb_rdma_h2c2h_dma {
	__u64 src;
	__u64 dst;
	__u64 len;
	__u32 flags;
	__u64 dma_time_ns;
};
#define PICOEVB_H2C2H_DMA_FLAG_SRC_IS_CUDA (1 << 0)
#define PICOEVB_H2C2H_DMA_FLAG_DST_IS_CUDA (1 << 1)

struct picoevb_rdma_card_info {
	__u64 fpga_ram_size;
};

struct picoevb_rdma_h2c_dma {
	__u64 src;
	__u64 dst;
	__u64 len;
	__u32 flags;
	__u64 dma_time_ns;
};
#define PICOEVB_H2C_DMA_FLAG_SRC_IS_CUDA (1 << 0)

struct picoevb_rdma_c2h_dma {
	__u64 src;
	__u64 dst;
	__u64 len;
	__u32 flags;
	__u64 dma_time_ns;
};
#define PICOEVB_C2H_DMA_FLAG_DST_IS_CUDA (1 << 1)


/* =================================================================
 * CUSTOM ADAPTER STRUCTURE (Added for FFN Hardware Acceleration)
 * ================================================================= */
struct picoevb_rdma_adapter {
	__u32 input[97];
	__u32 output[32];
};


/* =================================================================
 * IOCTL Commands
 * ================================================================= */
#define PICOEVB_IOC_LED			_IOW('P', 0, __u32)
#define PICOEVB_IOC_PIN_CUDA		_IOWR('P', 1, struct picoevb_rdma_pin_cuda)
#define PICOEVB_IOC_UNPIN_CUDA		_IOW('P', 2, struct picoevb_rdma_unpin_cuda)
#define PICOEVB_IOC_H2C2H_DMA		_IOWR('P', 3, struct picoevb_rdma_h2c2h_dma)
#define PICOEVB_IOC_CARD_INFO		_IOR('P', 4, struct picoevb_rdma_card_info)
#define PICOEVB_IOC_H2C_DMA		_IOWR('P', 5, struct picoevb_rdma_h2c_dma)
#define PICOEVB_IOC_C2H_DMA		_IOWR('P', 6, struct picoevb_rdma_c2h_dma)

/* Custom Adapter IOCTL Command */
#define PICOEVB_IOC_ADAPTER		_IOWR('P', 7, struct picoevb_rdma_adapter)

#endif