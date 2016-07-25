#ifndef __PL_AXI_DMA_DEFINE_H__
#define __PL_AXI_DMA_DEFINE_H__

#include "msgdma/msgdma.h"


#define RESERVED_BUFFER_PHYS_ADDR      (0x3fa00000)	/* in Compile.sh from kernel mem=1023M boot argument
							 * (1024 - 1)*2^20 = 0x3ff00000
							 * (1024 - 6)*2^20 = 0x3FA00000
							 * . . .
							 */

#define RESERVED_SOURCE_BUFFER_PHYS_ADDR      RESERVED_BUFFER_PHYS_ADDR
#define RESERVED_DEST_BUFFER_PHYS_ADDR      (0x3fc00000)

#define BUFFER_LENGTH_1MB		       (1024 * 1024)

#define BUFFER_LENGTH			       (0x100000)
#define NUMBER_BUFFER_RESERVED		 	4
#define RESERVED_BUFFER_LENGTH         (NUMBER_BUFFER_RESERVED * BUFFER_LENGTH)	

#define PRINT_WRAP_WIDTH               (80)

#define DMA_MM_THRESHOLD_ERROR 100

#define PL_AXI_DMA_IOCTL_BASE	'W'
#define DMA_MM_GET_DEV_MM_S				_IO(PL_AXI_DMA_IOCTL_BASE, 1)
#define DMA_MM_GET_DEV_S_MM				_IO(PL_AXI_DMA_IOCTL_BASE, 2)
#define DMA_MM_SET_DEV_MM_S				_IO(PL_AXI_DMA_IOCTL_BASE, 3)
#define DMA_MM_SET_DEV_S_MM				_IO(PL_AXI_DMA_IOCTL_BASE, 4)
#define DMA_MM_PREP_BUF					_IO(PL_AXI_DMA_IOCTL_BASE, 5)


#define DMA_MM_DEFAULT_ROW_SIZE (480)
#define DMA_MM_DEFAULT_COL_SIZE (640)
#define DMA_MM_DEFAULT_BYTE_PER_PIXEL (1*sizeof(uint8_t))

typedef enum DMA_DIRECTION_MODE_E dma_direction_mode_e;
enum DMA_DIRECTION_MODE_E
{
  DMA_MM_S, DMA_S_MM
};


typedef struct
{
	msgdma_dev msgdma;
	uint32_t transfer_size;
	uint8_t* addr;
	dma_direction_mode_e direction;

} dma_info_s;

#endif
