#include <linux/cdev.h>
#include <linux/fcntl.h>
#include <linux/init.h>
#include <linux/fs.h>		/* file structure, open read close */
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/semaphore.h>	/* Semaphore */
#include <linux/slab.h>
#include <linux/types.h>
#include <asm/atomic.h>
#include <asm/io.h>
#include <asm/uaccess.h>	/* copy_user */
#include <linux/delay.h>
#include <linux/cdev.h>		/* character device, makes cdev available */

#include "dma_mm_interface.h"
#include "hps_0.h"
#include "soc_cv_av/socal/hps.h"
#include "msgdma/msgdma.h"
#include "pl_axi_dma_define.h"


int dma_mm_interface_major = 0;	/* store the major number
						 * extracted by dev_t */
int dma_mm_interface_minor = 0;

#define DEVICE_NAME "dma_mm"
char* dma_mm_interface_name = DEVICE_NAME;

dma_mm_interface_dev dma_mm_interface;

struct file_operations dma_mm_interface_fops = {
	.owner = THIS_MODULE,
	.read = dma_mm_interface_read,
	.write = dma_mm_interface_write,
	.open = dma_mm_interface_open,
	.unlocked_ioctl = dma_mm_interface_ioctl,
	.release = dma_mm_interface_release
};

/*******************************************************************************
 *  Private API
 ******************************************************************************/
static void clear_buffer(void);
static msgdma_standard_descriptor *create_descriptor_list(msgdma_dev* msgdma, unsigned int* desc_cnt_ret, size_t frame_size, uint32_t physical_addr, dma_direction_mode_e mode);
static void free_descriptor_list(msgdma_standard_descriptor** desc_list);
static int copy_to_user_frame_buffer(msgdma_standard_descriptor* desc_list, unsigned int desc_cnt, char __user* buf);
static void print_desc(msgdma_standard_descriptor* desc, dma_direction_mode_e mode, int newline);
static void print_desc_list(msgdma_standard_descriptor * desc_list, unsigned int desc_cnt, dma_direction_mode_e mode);
static int dma_mm_interface_dev_init(dma_mm_interface_dev* dma_mm_interface);
static void dma_mm_interface_dev_del(dma_mm_interface_dev* dma_mm_interface);
static int dma_mm_interface_setup_cdev(dma_mm_interface_dev* dma_mm_interface);
static int dma_mm_interface_init(void);
static void dma_mm_interface_exit(void);


/**
* Clear the part in memory that we are going to write using the DMA
***/
static void clear_buffer(void)
{
	size_t i = 0;
	uint8_t* virt = ioremap_nocache((phys_addr_t) RESERVED_SOURCE_BUFFER_PHYS_ADDR, RESERVED_BUFFER_LENGTH);

	int j = 0;
	for (j = 0; j < NUMBER_BUFFER_RESERVED; j++) {
		printk(DEVICE_NAME  "Buffer %d - addr %08p \n", j, virt);
		// Byte to byte initialization to 0
		do {
			*virt = (uint8_t) j;
			virt += 1;
			i += 1;
		}
		while (i < BUFFER_LENGTH);
		i = 0;
	}

	iounmap(virt);
}

/**
 * Create a descriptor for the DMA
*/
static msgdma_standard_descriptor* create_descriptor_list(msgdma_dev * msgdma, unsigned int *desc_cnt_ret, size_t frame_size, uint32_t physical_addr, dma_direction_mode_e mode)
{

	size_t max_desc_transfer_size = msgdma->max_byte;
	/*
	 * nb_desc = ceil(frame_size / max_desc_transfer_size)
	 */
	uint32_t desc_cnt = 1 + ((frame_size - 1) / max_desc_transfer_size);
	*desc_cnt_ret = desc_cnt;

	size_t last_desc_transfer_size = frame_size - ((desc_cnt - 1) * max_desc_transfer_size);

	/*
	 * create descriptors
	 */
	msgdma_standard_descriptor *desc_list = kmalloc(desc_cnt * sizeof(msgdma_standard_descriptor), GFP_KERNEL);
	if (!desc_list) {
		printk(KERN_WARNING DEVICE_NAME  " dma_mm_interface: create_descriptor_list could not allocate memory for desc_list\n");
	}

	uint8_t* _address_descriptor = (uint8_t *) physical_addr;
	size_t _length_descriptor = max_desc_transfer_size;
	
	unsigned int i = 0;
	for (i = 0; i < desc_cnt; i++) {
		if (i == desc_cnt - 1) {
			_length_descriptor = last_desc_transfer_size;
		}

		if (mode == DMA_S_MM) {
			printk(DEVICE_NAME  "create_descriptor_list: DMA_S_MM descriptors\n");
			if(msgdma_construct_standard_st_to_mm_descriptor(msgdma, desc_list + i, (uint32_t *) _address_descriptor, _length_descriptor, 0)){
				printk(DEVICE_NAME  " create_descriptor_list: DMA_S_MM invalid argument\n");				
				free_descriptor_list(&desc_list);
				return NULL;
			}
			
		} else {
			printk(DEVICE_NAME  " create_descriptor_list: DMA_MM_S descriptors\n");
			if(msgdma_construct_standard_mm_to_st_descriptor(msgdma, desc_list + i, (uint32_t *) _address_descriptor, _length_descriptor, 0)){
				printk(DEVICE_NAME  " create_descriptor_list: DMA_MM_S invalid argument\n");								
				free_descriptor_list(&desc_list);
				return NULL;
			}
		}
		

		_address_descriptor += _length_descriptor;
	}

	printk(DEVICE_NAME  " create_descriptor_list: loop done\n");	
	print_desc_list(desc_list, desc_cnt, mode);


	printk(KERN_WARNING "dma_mm_interface: create_descriptor_list end\n");
	return desc_list;
}

static void free_descriptor_list(msgdma_standard_descriptor ** desc_list)
{
	kfree(*desc_list);
	*desc_list = NULL;
}


static int copy_to_user_frame_buffer(msgdma_standard_descriptor * desc_list, unsigned int desc_cnt, char __user * buf)
{
	int error = 0;
	char* user_buf = buf;

	unsigned int i = 0;
	// For all the descriptor, copy to user space
	do {
		void* virt = ioremap_nocache((phys_addr_t) (desc_list + i)->write_address, (desc_list + i)->transfer_length);
		size_t length = (desc_list + i)->transfer_length;
		
		if (virt == NULL) {
			printk(DEVICE_NAME  " virt is null\n");
			error = -EFAULT;
		} else if (user_buf == NULL) {
			printk(DEVICE_NAME  " User buffer null\n");
			error = -EFAULT;
		} else if (copy_to_user(user_buf, virt, length)) {
			printk(DEVICE_NAME  " copy to user fail \n");
			error = -EFAULT;
		}

		user_buf += length;
		i += 1;
		iounmap(virt);
	}
	while (i < desc_cnt && !error);

	return error;
}

static void print_desc(msgdma_standard_descriptor * desc, dma_direction_mode_e mode, int newline)
{
	unsigned int i = 0;
	void* virt = NULL;

	if(mode == DMA_S_MM){
		virt = ioremap_nocache((phys_addr_t) desc->write_address, desc->transfer_length);
	}else{
		virt = ioremap_nocache((phys_addr_t) desc->read_address, desc->transfer_length);
	}

	if(virt == NULL){
		printk(DEVICE_NAME  " print_desc: virt is NULL.. \n");
		return;
	}	
	

 	printk(DEVICE_NAME  " print_desc: read %08x - write %08x - length %u.. \n", (unsigned int) desc->read_address, 
																				(unsigned int) desc->write_address, 
																				(unsigned int) desc->transfer_length
		  );

	uint32_t number_of_print = 10;
	if(desc->transfer_length < number_of_print ){
		number_of_print = desc->transfer_length;
	}
	for (i = 0; i < number_of_print ; i++) {
		uint8_t value = *((uint8_t *) virt + i);
		printk("%02x ", value);
	}

	printk("\n");

	iounmap(virt);
}

static void print_desc_list(msgdma_standard_descriptor * desc_list, unsigned int desc_cnt, dma_direction_mode_e mode)
{
	unsigned int i = 0;
	printk(DEVICE_NAME  " print_desc_list: Start printing descriptors :%u \n", desc_cnt);

	for (i = 0; i < desc_cnt; i++) {
		print_desc(desc_list + i, mode, 0);
	}

	printk(KERN_INFO "print_desc_list: end priting descriptors\n");
}



static int dma_mm_interface_dev_init(dma_mm_interface_dev * dma_mm_interface)
{
	int result = 0;

	memset(dma_mm_interface, 0, sizeof(dma_mm_interface_dev));

	atomic_set(&dma_mm_interface->available, 1);
	sema_init(&dma_mm_interface->sem, 1);


	off_t h2f_lw_bridge_ofst = (off_t) ALT_LWFPGASLVS_OFST;
    size_t h2f_lw_bridge_span = (size_t) (((uintptr_t) ALT_LWFPGASLVS_UB_ADDR) - ((uintptr_t) ALT_LWFPGASLVS_LB_ADDR) + 1);

	void* bus_vbase = ioremap_nocache(h2f_lw_bridge_ofst, h2f_lw_bridge_span);
	if(bus_vbase == NULL){
		printk(DEVICE_NAME": user_input_module_init: Impossible to ioremap_nocache \n");
	}

	// Need to map without cache the bus address base
	//off_t h2f_lw_bridge_ofst = (off_t) ALT_LWFPGASLVS_OFST;
    //size_t h2f_lw_bridge_span = (size_t) (((uintptr_t) ALT_LWFPGASLVS_UB_ADDR) - ((uintptr_t) ALT_LWFPGASLVS_LB_ADDR) + 1);
	//dma_mm_interface->bus_vbase = ioremap_nocache(h2f_lw_bridge_ofst, h2f_lw_bridge_span);

	dma_mm_interface->bus_vbase = bus_vbase;
	

	// Here should be used all the address extended by the base of the bus

	dma_mm_interface->row_size = DMA_MM_DEFAULT_ROW_SIZE;
	dma_mm_interface->col_size = DMA_MM_DEFAULT_COL_SIZE;
	dma_mm_interface->byte_per_pixel = DMA_MM_DEFAULT_BYTE_PER_PIXEL;


	dma_mm_interface->msgdma_mm_s.transfer_size = DMA_MM_DEFAULT_ROW_SIZE * DMA_MM_DEFAULT_COL_SIZE * DMA_MM_DEFAULT_BYTE_PER_PIXEL;
	dma_mm_interface->msgdma_mm_s.addr = RESERVED_SOURCE_BUFFER_PHYS_ADDR;
	dma_mm_interface->msgdma_mm_s.direction = DMA_MM_S;

	dma_mm_interface->msgdma_mm_s.msgdma = msgdma_csr_descriptor_inst(
											((uint8_t *) dma_mm_interface->bus_vbase) + __VAR (DMA_MM_S_BASE_NAME, CSR_BASE),
											((uint8_t *) dma_mm_interface->bus_vbase) + __VAR(DMA_MM_S_BASE_NAME, DESCRIPTOR_SLAVE_BASE),
											__VAR(DMA_MM_S_BASE_NAME, DESCRIPTOR_SLAVE_DESCRIPTOR_FIFO_DEPTH),
											__VAR(DMA_MM_S_BASE_NAME, CSR_BURST_ENABLE),
											__VAR(DMA_MM_S_BASE_NAME, CSR_BURST_WRAPPING_SUPPORT),
											__VAR(DMA_MM_S_BASE_NAME, CSR_DATA_FIFO_DEPTH),
											__VAR(DMA_MM_S_BASE_NAME, CSR_DATA_WIDTH),
											__VAR(DMA_MM_S_BASE_NAME, CSR_MAX_BURST_COUNT),
											__VAR(DMA_MM_S_BASE_NAME, CSR_MAX_BYTE),
											__VAR(DMA_MM_S_BASE_NAME, CSR_MAX_STRIDE),
											__VAR(DMA_MM_S_BASE_NAME, CSR_PROGRAMMABLE_BURST_ENABLE),
											__VAR(DMA_MM_S_BASE_NAME, CSR_STRIDE_ENABLE),
											__VAR(DMA_MM_S_BASE_NAME, CSR_ENHANCED_FEATURES),
											__VAR(DMA_MM_S_BASE_NAME, CSR_RESPONSE_PORT)
									);
	msgdma_init(&dma_mm_interface->msgdma_mm_s.msgdma);

	dma_mm_interface->msgdma_s_mm.transfer_size = DMA_MM_DEFAULT_ROW_SIZE * DMA_MM_DEFAULT_COL_SIZE * DMA_MM_DEFAULT_BYTE_PER_PIXEL;
	dma_mm_interface->msgdma_s_mm.addr = RESERVED_DEST_BUFFER_PHYS_ADDR;
	dma_mm_interface->msgdma_s_mm.direction = DMA_S_MM;

	dma_mm_interface->msgdma_s_mm.msgdma = msgdma_csr_descriptor_inst(
											((uint8_t*) dma_mm_interface->bus_vbase) + __VAR(DMA_S_MM_BASE_NAME, CSR_BASE),
					                        ((uint8_t*) dma_mm_interface->bus_vbase) + __VAR (DMA_S_MM_BASE_NAME, DESCRIPTOR_SLAVE_BASE),
	           			                    __VAR(DMA_S_MM_BASE_NAME, DESCRIPTOR_SLAVE_DESCRIPTOR_FIFO_DEPTH),
	           		                     	__VAR(DMA_S_MM_BASE_NAME, CSR_BURST_ENABLE),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_BURST_WRAPPING_SUPPORT),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_DATA_FIFO_DEPTH),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_DATA_WIDTH),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_MAX_BURST_COUNT),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_MAX_BYTE),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_MAX_STRIDE),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_PROGRAMMABLE_BURST_ENABLE),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_STRIDE_ENABLE),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_ENHANCED_FEATURES),
					                        __VAR(DMA_S_MM_BASE_NAME, CSR_RESPONSE_PORT)
									);
	msgdma_init(&dma_mm_interface->msgdma_s_mm.msgdma);


	




	return result;
}

static void dma_mm_interface_dev_del(dma_mm_interface_dev * dma_mm_interface)
{
	iounmap(dma_mm_interface->bus_vbase);
}

static int dma_mm_interface_setup_cdev(dma_mm_interface_dev * dma_mm_interface)
{
	int error = 0;
	dev_t devno = MKDEV(dma_mm_interface_major, dma_mm_interface_minor);

	cdev_init(&dma_mm_interface->cdev, &dma_mm_interface_fops);
	dma_mm_interface->cdev.owner = THIS_MODULE;
	dma_mm_interface->cdev.ops = &dma_mm_interface_fops;
	error = cdev_add(&dma_mm_interface->cdev, devno, 1);

	return error;
}

static int dma_mm_interface_init(void)
{
	dev_t           devno = 0;
	int             result = 0;

	dma_mm_interface_dev_init(&dma_mm_interface);

	/*
	 * register char device
	 */
	/*
	 * we will get the major number dynamically this is recommended see
	 * book : ldd3
	 */
	result = alloc_chrdev_region(&devno, dma_mm_interface_minor, 1, dma_mm_interface_name);
	dma_mm_interface_major = MAJOR(devno);
	if (result < 0) {
		printk(KERN_WARNING
		       "dma_mm_interface: can't get major number %d\n",
		       dma_mm_interface_major);
		goto fail;
	}

	result = dma_mm_interface_setup_cdev(&dma_mm_interface);
	if (result < 0) {
		printk(KERN_WARNING
		       "dma_mm_interface: error %d adding dma_mm_interface",
		       result);
		goto fail;
	}

	printk(KERN_INFO "dma_mm_interface: module loaded\n");
	return 0;

fail:
	dma_mm_interface_exit();
	return result;
}

static void
dma_mm_interface_exit(void)
{
	dev_t devno = MKDEV(dma_mm_interface_major, dma_mm_interface_minor);

	cdev_del(&dma_mm_interface.cdev);
	unregister_chrdev_region(devno, 1);
	dma_mm_interface_dev_del(&dma_mm_interface);

	printk(KERN_INFO "dma_mm_interface: module unloaded\n");
}

/*******************************************************************************
 *  Public API
 ******************************************************************************/

/*
 * inode reffers to the actual file on disk
 */
int
dma_mm_interface_open(struct inode *inode, struct file *filp)
{
	dma_mm_interface_dev *dma_mm_interface;

	dma_mm_interface =
	    container_of(inode->i_cdev, dma_mm_interface_dev, cdev);
	filp->private_data = dma_mm_interface;

	if (!atomic_dec_and_test(&dma_mm_interface->available)) {
		atomic_inc(&dma_mm_interface->available);
		printk(KERN_ALERT
		       "open dma_mm_interface : the device has been opened by some other device, unable to open lock\n");
		return -EBUSY;		/* already open */
	}

	return 0;
}

int
dma_mm_interface_release(struct inode *inode, struct file *filp)
{
	dma_mm_interface_dev *dma_mm_interface = filp->private_data;
	atomic_inc(&dma_mm_interface->available);	/* release the device */
	return 0;
}

ssize_t dma_mm_interface_read(struct file * filp, char __user * buf, size_t count, loff_t * f_pos)
{

	ssize_t retval = 0;

	// Get the structure of the interface from the device file
	if (filp == NULL) {
		printk(DEVICE_NAME  " dma_mm_interface_read file NULL\n");
		return retval;
	}

	dma_mm_interface_dev *dma_mm_interface = filp->private_data;
	if (dma_mm_interface == NULL) {
		printk(DEVICE_NAME  " dma_mm_interface_read dma_mm_interface NULL\n");
		return retval;
	}


	if (down_interruptible(&dma_mm_interface->sem)) {
		return -ERESTARTSYS;
	}

	msgdma_standard_descriptor *desc_list_s_mm;
	msgdma_standard_descriptor *desc_list_mm_s;

	unsigned int desc_cnt_s_mm = 0;
	unsigned int desc_cnt_mm_s = 0;
	uint32_t transfer_size_byte = dma_mm_interface->byte_per_pixel * dma_mm_interface->row_size * dma_mm_interface->col_size;
	desc_list_mm_s = create_descriptor_list(&dma_mm_interface->msgdma_mm_s.msgdma,	&desc_cnt_mm_s, transfer_size_byte, dma_mm_interface->msgdma_mm_s.addr, dma_mm_interface->msgdma_mm_s.direction);
	desc_list_s_mm = create_descriptor_list(&dma_mm_interface->msgdma_s_mm.msgdma, &desc_cnt_s_mm, transfer_size_byte, dma_mm_interface->msgdma_s_mm.addr, dma_mm_interface->msgdma_s_mm.direction);
	// Check if the creation worked (descriptor not NULL)
	if (!desc_list_mm_s || !desc_list_s_mm) {
		printk(DEVICE_NAME  " dma_mm_interface_read: msgdma descriptor desc_list_s_mm or desc_list_mm_s = NULL\n");
		retval = -ETIME;
		goto fail_no_free;
	}

	printk(DEVICE_NAME  " Number of descriptors desc_cnt_s_mm=%d and desc_cnt_mm_s=%d \n", desc_cnt_s_mm, desc_cnt_mm_s);


	/*
	 * start acquisition
	 */
	int result = 0;

 	printk(DEVICE_NAME  " dma_mm_interface_read: wait for mm_s dma before\n");
	msgdma_wait_until_idle(&dma_mm_interface->msgdma_mm_s.msgdma);

	unsigned int i_s_mm = 0;
	unsigned int i_mm_s = 0;
	unsigned int error_dma = 0;

	while (i_mm_s < desc_cnt_mm_s) {

		result = msgdma_standard_descriptor_async_transfer(&dma_mm_interface->msgdma_mm_s.msgdma, desc_list_mm_s + i_mm_s);
		// result = msgdma_standard_descriptor_sync_transfer(&dma_mm_interface->msgdma_mm_s, desc_list_mm_s + i_mm_s);

		if ((result == -ENOSPC)) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read : descriptor buffer is full\n");
		} else if (result == -ETIME) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read: timeout\n");
		} else if (result == -EPERM) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read: operation not permitted due to descriptor type conflict\n");
		} else {
			i_mm_s++;
			printk(DEVICE_NAME  " dma_mm_interface_read: sending msgdma descriptor mm_s=%d \n", i_mm_s);
		}

		if (error_dma == DMA_MM_THRESHOLD_ERROR) {
			printk(DEVICE_NAME  " dma_mm_interface_read: too many errors %d \n", error_dma);
			retval = -ETIME;
			goto fail;
		}

	}

	
	error_dma = 0;
	while (i_s_mm < desc_cnt_s_mm) {

		result = msgdma_standard_descriptor_async_transfer(&dma_mm_interface->msgdma_s_mm.msgdma, desc_list_s_mm + i_s_mm);
		// result = msgdma_standard_descriptor_sync_transfer(&dma_mm_interface->msgdma_mm_s, desc_list_mm_s + i_mm_s);

		if ((result == -ENOSPC)) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read : s_mm descriptor buffer is full\n");
		} else if (result == -ETIME) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read: s_mm timeout\n");
		} else if (result == -EPERM) {
			error_dma++;
			printk(DEVICE_NAME  " dma_mm_interface_read: s_mm operation not permitted due to descriptor type conflict\n");
		} else {
			i_s_mm++;
			printk(DEVICE_NAME  " dma_mm_interface_read: s_mm sending msgdma descriptor s_mm=%d \n", i_s_mm);
		}

		if (error_dma == DMA_MM_THRESHOLD_ERROR) {
			printk(DEVICE_NAME  " dma_mm_interface_read: too many errors %d \n", error_dma);
			retval = -ETIME;
			goto fail;
		}

	}

	printk(DEVICE_NAME  " dma_mm_interface_read: wait for s_mm dma\n");

	msgdma_wait_until_idle(&dma_mm_interface->msgdma_mm_s.msgdma);
	msgdma_wait_until_idle(&dma_mm_interface->msgdma_s_mm.msgdma);


	// Merged
	/*
	 * while (i_s_mm < desc_cnt_s_mm && i_mm_s < desc_cnt_mm_s ) {
	 *
	 * result =
	 * msgdma_standard_descriptor_async_transfer(&dma_mm_interface->msgdma_mm_s,
	 * desc_list_mm_s + i_mm_s); if ((result != -ENOSPC) && (result !=
	 * -ETIME)) { i_mm_s++; }
	 *
	 * result =
	 * msgdma_standard_descriptor_async_transfer(&dma_mm_interface->msgdma_s_mm,
	 * desc_list_s_mm + i_s_mm); if ((result != -ENOSPC) && (result !=
	 * -ETIME)) { i_s_mm++; }
	 *
	 * printk("Sending msgdma descriptor s_mm=%d and mm_s=%d \n", i_s_mm,
	 * i_mm_s); }
	 */

	print_desc_list(desc_list_s_mm, desc_cnt_s_mm, dma_mm_interface->msgdma_s_mm.direction);

	// copy to user
	retval = copy_to_user_frame_buffer(desc_list_s_mm, desc_cnt_s_mm, buf);
	if (retval) {
		printk(DEVICE_NAME  " dma_mm_interface: dma_mm_interface_read Fail to copy to user space\n");
		goto fail;
	}


fail:
	/*
	 * destroy descriptors
	 */
	if(desc_list_s_mm != NULL){
		free_descriptor_list(&desc_list_s_mm);
	}
	
	if(desc_list_mm_s != NULL){
		free_descriptor_list(&desc_list_mm_s);
	}

fail_no_free:
	up(&dma_mm_interface->sem);
	return retval;
}


long dma_mm_interface_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{


	dma_mm_interface_dev *dma_mm_interface = filp->private_data;
	dma_info_s dma_info_input;

	switch (cmd) {
		// Get the number of channel found
		case DMA_MM_GET_DEV_MM_S:
			printk(KERN_INFO "<%s> ioctl: DMA_MM_DEV_MM_S\n", DEVICE_NAME);
			if (copy_to_user((uint32_t*) arg, &dma_mm_interface->msgdma_s_mm, sizeof(dma_info_s))){
				return -EFAULT;
			}
			break;

		case DMA_MM_GET_DEV_S_MM:
			printk(KERN_INFO "<%s> ioctl: DMA_MM_DEV_S_MM\n", DEVICE_NAME);
			if (copy_to_user((uint32_t*) arg, &dma_mm_interface->msgdma_s_mm, sizeof(dma_info_s))){
				return -EFAULT;
			}
			break;

		case DMA_MM_SET_DEV_MM_S:
			printk(KERN_INFO "<%s> ioctl: DMA_MM_DEV_MM_S\n", DEVICE_NAME);
			if (copy_from_user((void *)&dma_info_input, (const void __user *)arg, sizeof(dma_info_s))){
				return -EFAULT;
			}

			dma_mm_interface->msgdma_mm_s.msgdma = dma_info_input.msgdma ;
			dma_mm_interface->msgdma_mm_s.transfer_size = dma_info_input.transfer_size;
			dma_mm_interface->msgdma_mm_s.addr = dma_info_input.addr ;
			dma_mm_interface->msgdma_mm_s.direction = dma_info_input.direction;

			break;

		case DMA_MM_SET_DEV_S_MM:
			printk(KERN_INFO "<%s> ioctl: DMA_MM_DEV_S_MM\n", DEVICE_NAME);
			if (copy_from_user((void *)&dma_info_input, (const void __user *)arg, sizeof(dma_info_s))){
				return -EFAULT;
			}

			dma_mm_interface->msgdma_s_mm.msgdma = dma_info_input.msgdma ;
			dma_mm_interface->msgdma_s_mm.transfer_size = dma_info_input.transfer_size;
			dma_mm_interface->msgdma_s_mm.addr = dma_info_input.addr ;
			dma_mm_interface->msgdma_s_mm.direction = dma_info_input.direction;

			break;

		case DMA_MM_PREP_BUF:
			printk(KERN_INFO "<%s> ioctl: XDMA_PREP_BUF\n", DEVICE_NAME);

		   	uint8_t *virt = ioremap_nocache((phys_addr_t) dma_mm_interface->msgdma_mm_s.addr, dma_mm_interface->msgdma_mm_s.transfer_size);

			if (copy_from_user((void *)virt, (const void __user *)arg, dma_mm_interface->msgdma_mm_s.transfer_size)){
				return -EFAULT;
			}
			
			iounmap(virt);

			break;

		default:
			break;
	}

	return 0;
}




ssize_t
dma_mm_interface_write(struct file * filp, const char __user * buf,
                       size_t count, loff_t * f_pos)
{
	dma_mm_interface_dev *dma_mm_interface = filp->private_data;
	uint16_t        frame_dimensions[3];
	ssize_t         retval = 0;

	if (down_interruptible(&dma_mm_interface->sem)) {
		return -ERESTARTSYS;
	}

	if (copy_from_user(&frame_dimensions, buf, count)) {
		retval = -EFAULT;
		goto fail;
	}
	retval = count;

	dma_mm_interface->row_size = frame_dimensions[0];
	dma_mm_interface->col_size = frame_dimensions[1];
	dma_mm_interface->byte_per_pixel = frame_dimensions[2];

	printk(DEVICE_NAME  " New Row Size %d\n", dma_mm_interface->row_size);
	printk(DEVICE_NAME  " New Col Size %d\n", dma_mm_interface->col_size);
	printk(DEVICE_NAME  " New Byte Pr pixel %d\n", dma_mm_interface->byte_per_pixel);


	printk(DEVICE_NAME  " dma_mm_interface_write: wait for s_mm dma\n");
	msgdma_wait_until_idle(&dma_mm_interface->msgdma_s_mm.msgdma);
	printk(DEVICE_NAME  " dma_mm_interface_write: wait for mm_s dma\n");
	msgdma_wait_until_idle(&dma_mm_interface->msgdma_mm_s.msgdma);

	clear_buffer();

fail:
	up(&dma_mm_interface->sem);
	return retval;
}


module_init(dma_mm_interface_init);
module_exit(dma_mm_interface_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Florian Depraz <florian.depraz@sensefly.com>");
MODULE_DESCRIPTION("MSGDMA Interface driver");
MODULE_VERSION("1.5");

