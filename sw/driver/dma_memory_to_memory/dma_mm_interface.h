#ifndef __dma_mm_interface_H__
#define __dma_mm_interface_H__

#include <linux/cdev.h>
#include <linux/semaphore.h>
#include "msgdma/msgdma.h"
#include "pl_axi_dma_define.h"




#define __DEF_CONCAT_REG(prefix, suffix) prefix##_##suffix
#define __VAR(prefix, suffix) __DEF_CONCAT_REG(prefix, suffix)



#define DMA_S_MM_BASE_NAME BASIC_0_MSGDMA_WRITE_MM
#define DMA_MM_S_BASE_NAME BASIC_0_MSGDMA_READ_MM

/*
 * Helper macro for easily constructing device structures. The user needs to
 * provide the component's prefix, and the corresponding device structure is
 * returned.
 */
#define MSGDMA_CSR_DESCRIPTOR_INST(base, prefix)                                        \
    msgdma_csr_descriptor_inst(((void *) (uint8_t *) base + prefix ## _CSR_BASE),                    \
                               ((void *) (uint8_t *) base + prefix ## _DESCRIPTOR_SLAVE_BASE),       \
                               prefix ## _DESCRIPTOR_SLAVE_DESCRIPTOR_FIFO_DEPTH, \
                               prefix ## _CSR_BURST_ENABLE,                       \
                               prefix ## _CSR_BURST_WRAPPING_SUPPORT,             \
                               prefix ## _CSR_DATA_FIFO_DEPTH,                    \
                               prefix ## _CSR_DATA_WIDTH,                         \
                               prefix ## _CSR_MAX_BURST_COUNT,                    \
                               prefix ## _CSR_MAX_BYTE,                           \
                               prefix ## _CSR_MAX_STRIDE,                         \
                               prefix ## _CSR_PROGRAMMABLE_BURST_ENABLE,          \
                               prefix ## _CSR_STRIDE_ENABLE,                      \
                               prefix ## _CSR_ENHANCED_FEATURES,                  \
                               prefix ## _CSR_RESPONSE_PORT)




typedef struct
{
	atomic_t available;
	struct semaphore sem;
	struct cdev cdev;

	void *bus_vbase;


	dma_info_s msgdma_s_mm;
	dma_info_s msgdma_mm_s;

//	msgdma_dev msgdma_s_mm;
//	msgdma_dev msgdma_mm_s;

	uint16_t row_size;
	uint16_t col_size;
	uint16_t byte_per_pixel;

} dma_mm_interface_dev;

int dma_mm_interface_open (struct inode *inode, struct file *filp);
int dma_mm_interface_release (struct inode *inode, struct file *filp);
ssize_t dma_mm_interface_read (struct file *filp, char __user * buf, size_t count, loff_t * f_pos);
ssize_t dma_mm_interface_write (struct file *filp, const char __user * buf, size_t count, loff_t * f_pos);
long dma_mm_interface_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);

#endif /* __dma_mm_interface_H__ */
