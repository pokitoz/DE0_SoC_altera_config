/*
  Descriptor formats:

  Standard Format:

  Offset         |                         3                         2                         1                         0
  ------------------------------------------------------------------------------------------------------------------------
   0x0           |                                            Read Address[31..0]
   0x4           |                                           Write Address[31..0]
   0x8           |                                               Length[31..0]
   0xC           |                                              Control[31..0]

  Extended Format:

  Offset         |                         3                         2                         1                         0
  ------------------------------------------------------------------------------------------------------------------------
   0x0           |                                           Read Address[31..0]
   0x4           |                                           Write Address[31..0]
   0x8           |                                               Length[31..0]
   0xC           | Write Burst Count[7..0] |  Read Burst Count[7..0] |               Sequence Number[15..0]
   0x10          |                 Write Stride[15..0]               |                 Read Stride[15..0]
   0x14          |                                           Read Address[63..32]
   0x18          |                                          Write Address[63..32]
   0x1C          |                                              Control[31..0]

  Note:  The control register moves from offset 0xC to 0x1C depending on the format used

*/

#ifndef _MSGDMA_DESCRIPTOR_REGS_H_
#define _MSGDMA_DESCRIPTOR_REGS_H_

#if defined(__KERNEL__) || defined(MODULE)
#include <linux/types.h>
#else
#include <stdint.h>
#endif

#include "msgdma_io.h"

#define MSGDMA_DESCRIPTOR_READ_ADDRESS_REG                      (0x0)
#define MSGDMA_DESCRIPTOR_WRITE_ADDRESS_REG                     (0x4)
#define MSGDMA_DESCRIPTOR_LENGTH_REG                            (0x8)
#define MSGDMA_DESCRIPTOR_CONTROL_STANDARD_REG                  (0xc)
#define MSGDMA_DESCRIPTOR_SEQUENCE_NUMBER_REG                   (0xc)
#define MSGDMA_DESCRIPTOR_READ_BURST_REG                        (0xe)
#define MSGDMA_DESCRIPTOR_WRITE_BURST_REG                       (0xf)
#define MSGDMA_DESCRIPTOR_READ_STRIDE_REG                       (0x10)
#define MSGDMA_DESCRIPTOR_WRITE_STRIDE_REG                      (0x12)
#define MSGDMA_DESCRIPTOR_READ_ADDRESS_HIGH_REG                 (0x14)
#define MSGDMA_DESCRIPTOR_WRITE_ADDRESS_HIGH_REG                (0x18)
#define MSGDMA_DESCRIPTOR_CONTROL_ENHANCED_REG                  (0x1c)

/* masks and offsets for the sequence number and programmable burst counts */
#define MSGDMA_DESCRIPTOR_SEQUENCE_NUMBER_MASK                  (0xffff)
#define MSGDMA_DESCRIPTOR_SEQUENCE_NUMBER_OFFSET                (0)
#define MSGDMA_DESCRIPTOR_READ_BURST_COUNT_MASK                 (0x00ff0000)
#define MSGDMA_DESCRIPTOR_READ_BURST_COUNT_OFFSET               (16)
#define MSGDMA_DESCRIPTOR_WRITE_BURST_COUNT_MASK                (0xff000000)
#define MSGDMA_DESCRIPTOR_WRITE_BURST_COUNT_OFFSET              (24)

/* masks and offsets for the read and write strides */
#define MSGDMA_DESCRIPTOR_READ_STRIDE_MASK                      (0xffff)
#define MSGDMA_DESCRIPTOR_READ_STRIDE_OFFSET                    (0)
#define MSGDMA_DESCRIPTOR_WRITE_STRIDE_MASK                     (0xffff0000)
#define MSGDMA_DESCRIPTOR_WRITE_STRIDE_OFFSET                   (16)

/* masks and offsets for the bits in the descriptor control field */
#define MSGDMA_DESCRIPTOR_CONTROL_TRANSMIT_CHANNEL_MASK         (0xff)
#define MSGDMA_DESCRIPTOR_CONTROL_TRANSMIT_CHANNEL_OFFSET       (0)
#define MSGDMA_DESCRIPTOR_CONTROL_GENERATE_SOP_MASK             (1 << 8)
#define MSGDMA_DESCRIPTOR_CONTROL_GENERATE_SOP_OFFSET           (8)
#define MSGDMA_DESCRIPTOR_CONTROL_GENERATE_EOP_MASK             (1 << 9)
#define MSGDMA_DESCRIPTOR_CONTROL_GENERATE_EOP_OFFSET           (9)
#define MSGDMA_DESCRIPTOR_CONTROL_PARK_READS_MASK               (1 << 10)
#define MSGDMA_DESCRIPTOR_CONTROL_PARK_READS_OFFSET             (10)
#define MSGDMA_DESCRIPTOR_CONTROL_PARK_WRITES_MASK              (1 << 11)
#define MSGDMA_DESCRIPTOR_CONTROL_PARK_WRITES_OFFSET            (11)
#define MSGDMA_DESCRIPTOR_CONTROL_END_ON_EOP_MASK               (1 << 12)
#define MSGDMA_DESCRIPTOR_CONTROL_END_ON_EOP_OFFSET             (12)
#define MSGDMA_DESCRIPTOR_CONTROL_TRANSFER_COMPLETE_IRQ_MASK    (1 << 14)
#define MSGDMA_DESCRIPTOR_CONTROL_TRANSFER_COMPLETE_IRQ_OFFSET  (14)
#define MSGDMA_DESCRIPTOR_CONTROL_EARLY_TERMINATION_IRQ_MASK    (1 << 15)
#define MSGDMA_DESCRIPTOR_CONTROL_EARLY_TERMINATION_IRQ_OFFSET  (15)
#define MSGDMA_DESCRIPTOR_CONTROL_ERROR_IRQ_MASK                (0xff << 16) /* the read master will use this as the transmit error, the dispatcher will use this to generate an interrupt if any of the error bits are asserted by the write master */
#define MSGDMA_DESCRIPTOR_CONTROL_ERROR_IRQ_OFFSET              (16)
#define MSGDMA_DESCRIPTOR_CONTROL_EARLY_DONE_ENABLE_MASK        (1 << 24)
#define MSGDMA_DESCRIPTOR_CONTROL_EARLY_DONE_ENABLE_OFFSET      (24)
#define MSGDMA_DESCRIPTOR_CONTROL_GO_MASK                       (1 << 31)    /* at a minimum you always have to write '1' to this bit as it commits the descriptor to the dispatcher */
#define MSGDMA_DESCRIPTOR_CONTROL_GO_OFFSET                     (31)

/* Each register is byte lane accessible so the some of the values that are
 * less than 32 bits wide are written to according to the field width.
 */
#define MSGDMA_WR_DESCRIPTOR_READ_ADDRESS(base, data)           msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_READ_ADDRESS_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_WRITE_ADDRESS(base, data)          msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_WRITE_ADDRESS_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_LENGTH(base, data)                 msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_LENGTH_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_CONTROL_STANDARD(base, data)       msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_CONTROL_STANDARD_REG, (data))   /* this pushes the descriptor into the read/write FIFOs when standard descriptors are used */
#define MSGDMA_WR_DESCRIPTOR_SEQUENCE_NUMBER(base, data)        msgdma_write_hword((uint8_t *) (base) + MSGDMA_DESCRIPTOR_SEQUENCE_NUMBER_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_READ_BURST(base, data)             msgdma_write_byte((uint8_t *) (base) + MSGDMA_DESCRIPTOR_READ_BURST_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_WRITE_BURST(base, data)            msgdma_write_byte((uint8_t *) (base) + MSGDMA_DESCRIPTOR_WRITE_BURST_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_READ_STRIDE(base, data)            msgdma_write_hword((uint8_t *) (base) + MSGDMA_DESCRIPTOR_READ_STRIDE_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_WRITE_STRIDE(base, data)           msgdma_write_hword((uint8_t *) (base) + MSGDMA_DESCRIPTOR_WRITE_STRIDE_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_READ_ADDRESS_HIGH(base, data)      msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_READ_ADDRESS_HIGH_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_WRITE_ADDRESS_HIGH(base, data)     msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_WRITE_ADDRESS_HIGH_REG, (data))
#define MSGDMA_WR_DESCRIPTOR_CONTROL_ENHANCED(base, data)       msgdma_write_word((uint8_t *) (base) + MSGDMA_DESCRIPTOR_CONTROL_ENHANCED_REG, (data))   /* this pushes the descriptor into the read/write FIFOs when the extended descriptors are used */

#endif /* _MSGDMA_DESCRIPTOR_REGS_H_ */
