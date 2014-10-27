#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/i2c.h>
#include <linux/interrupt.h>
#include <linux/vmalloc.h>
#include <linux/fb.h>
#include <linux/delay.h>
#include <linux/uaccess.h>

#define ADDRESS 0x46

struct ledhat_dev_t {
	struct i2c_client *ledhat_client;
	void *vmem;
	u32 vmemsize;
	u8 gamma[32];
};

static int ledhat_init(void);
static void ledhat_exit(void);

static int ledhatfb_probe(struct i2c_client *client,
			  const struct i2c_device_id *id);
static int ledhatfb_remove(struct i2c_client *client);

static void ledhatfb_deferred_io(struct fb_info *info,
				struct list_head *pagelist);
ssize_t ledhatfb_write(struct fb_info *info,
		       const char __user *buf, size_t count, loff_t *ppos);
void ledhatfb_fillrect(struct fb_info *info, const struct fb_fillrect *rect);
void ledhatfb_copyarea(struct fb_info *info, const struct fb_copyarea *area);
void ledhatfb_imageblit(struct fb_info *info, const struct fb_image *image);

static void *rvmalloc(unsigned long size);
static void rvfree(void *mem, unsigned long size);

struct ledhat_dev_t ledhat_dev = {
	.ledhat_client = NULL,
	.vmem= NULL,
	.vmemsize =  128,
	.gamma = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
		  0x02, 0x02, 0x03, 0x03, 0x04, 0x05, 0x06, 0x07,
		  0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0E, 0x0F, 0x11,
		  0x12, 0x14, 0x15, 0x17, 0x19, 0x1B, 0x1D, 0x1F, },
};

static const struct i2c_device_id ledhat_i2c_id[] = {
	{ "ledhatfb", 0 },
	{},
};

static struct i2c_board_info ledhat_info = {
	I2C_BOARD_INFO("ledhatfb", ADDRESS),
};

static struct i2c_driver ledhatfb_driver = {
	.probe = ledhatfb_probe,
	.remove = ledhatfb_remove,
	.id_table = ledhat_i2c_id,
	.driver = {
		.name = "ledhatfb",
		.owner = THIS_MODULE,
	},
};

static struct fb_ops ledhatfb_ops = {
	.fb_read        = fb_sys_read,
	.fb_write       = ledhatfb_write,
	.fb_fillrect	= ledhatfb_fillrect,
	.fb_copyarea	= ledhatfb_copyarea,
	.fb_imageblit	= ledhatfb_imageblit,
};


static struct fb_var_screeninfo ledhatfb_default = {
	.xres		= 8,
	.yres		= 8,
	.xres_virtual	= 8,
	.yres_virtual	= 8,
	.bits_per_pixel = 16,
	.red		= {11, 5, 0},
      	.green		= {5, 6, 0},
      	.blue		= {0, 5, 0},
};

static struct fb_fix_screeninfo ledhatfb_fix = {
	.id =		"LEDHat FB",
	.type =		FB_TYPE_PACKED_PIXELS,
	.visual =	FB_VISUAL_TRUECOLOR,
	.xpanstep =	0,
	.ypanstep =	0,
	.ywrapstep =	0,
	.accel =	FB_ACCEL_NONE,
	.line_length =	16,
};

static struct fb_deferred_io ledhatfb_defio = {
	.delay		= HZ/100,
	.deferred_io	= ledhatfb_deferred_io,
};

static int ledhat_init(void)
{
	int result = 0;
	struct i2c_adapter *i2c_adap;
	i2c_adap = i2c_get_adapter(1);
	if (!i2c_adap){
		pr_err("Failed to get I2C adapter 1.\n");
		result = -EINVAL;
		goto err;
	}

	ledhat_dev.ledhat_client = i2c_new_device(i2c_adap, &ledhat_info);
	if (!ledhat_dev.ledhat_client){
		pr_err("Failed to register i2c device.\n");
		result = -EINVAL;
		goto end;
	}
	result = i2c_add_driver(&ledhatfb_driver);
	if (result){
		pr_err("Failed to register i2c driver.\n");
		result = -EINVAL;
		goto err_dev;
	}

	goto end;
err_dev:
	i2c_unregister_device(ledhat_dev.ledhat_client);
end:
	i2c_put_adapter(i2c_adap);
err:
	return result;
}

static void ledhat_exit(void)
{
	i2c_unregister_device(ledhat_dev.ledhat_client);
	i2c_del_driver(&ledhatfb_driver);
}

static int ledhatfb_probe(struct i2c_client *client,
			const struct i2c_device_id *id)
{
	struct fb_info *info;
	int result = -ENOMEM;

	if (!(ledhat_dev.vmem = rvmalloc(ledhat_dev.vmemsize))){
		dev_err(&ledhat_dev.ledhat_client->dev, "Could not allocate video memory.\n");
		return result;
	}

	info = framebuffer_alloc(0, &client->dev);
	if (!info){
		dev_err(&ledhat_dev.ledhat_client->dev, "Could not allocate fb_info.\n");
		goto err_vmem;
	}


	ledhatfb_fix.smem_start = (unsigned long)ledhat_dev.vmem;
	ledhatfb_fix.smem_len = ledhat_dev.vmemsize;
	
	info->fbops = &ledhatfb_ops;
	info->var = ledhatfb_default;
	info->fbdefio = &ledhatfb_defio;
	info->fix = ledhatfb_fix;
	info->flags = FBINFO_FLAG_DEFAULT | FBINFO_VIRTFB;
	info->screen_base = (char __iomem *)ledhat_dev.vmem;
	info->screen_size = ledhat_dev.vmemsize;

	fb_deferred_io_init(info);

	result = register_framebuffer(info);
	if (result < 0){
		dev_err(&ledhat_dev.ledhat_client->dev, "Could not register framebuffer.\n");
		goto err_fb;
	}
	schedule_delayed_work(&info->deferred_work, ledhatfb_defio.delay);

	dev_info(&ledhat_dev.ledhat_client->dev,
	       "fb%d, using %u bytes of video memory\n",
	       info->node, ledhat_dev.vmemsize);
	
	i2c_set_clientdata(client, info);

	return result;
err_fb:
	framebuffer_release(info);
err_vmem:
	rvfree(ledhat_dev.vmem, ledhat_dev.vmemsize);
	return result;
}

static int ledhatfb_remove(struct i2c_client *client)
{
	struct fb_info *info = i2c_get_clientdata(client);
	i2c_set_clientdata(client, NULL);
	unregister_framebuffer(info);
	fb_deferred_io_cleanup(info);
	rvfree(ledhat_dev.vmem, ledhat_dev.vmemsize);
	framebuffer_release(info);
	return 0;
}

static void ledhatfb_deferred_io(struct fb_info *info,
				struct list_head *pagelist)
{
	int i;
	int j;
	u8 *array;
	u16 *mem = ledhat_dev.vmem;
	
	array = kzalloc(ledhat_dev.vmemsize, GFP_KERNEL);
	if (!array)
		return;

	for (j=0; j<8; j++){
		for (i=0; i<8; i++){
			array[(j*24)+(i)] = ledhat_dev.gamma[(mem[(j*8)+i] >> 11) & 0x1F];
			array[(j*24)+(i+8)] = ledhat_dev.gamma[(mem[(j*8)+i] >> 6) & 0x1F];
			array[(j*24)+(i+16)] = ledhat_dev.gamma[(mem[(j*8)+i]) & 0x1F];
		}
	}
							
	i2c_master_send(ledhat_dev.ledhat_client, array, 192);
	kfree(array);
}

ssize_t ledhatfb_write(struct fb_info *info,
		       const char __user *buf, size_t count, loff_t *ppos)
{
	ssize_t res;
	res = fb_sys_write(info, buf, count, ppos);
	schedule_delayed_work(&info->deferred_work, ledhatfb_defio.delay);
	return res;
}

void ledhatfb_fillrect(struct fb_info *info, const struct fb_fillrect *rect)
{
	sys_fillrect(info, rect);
	schedule_delayed_work(&info->deferred_work, ledhatfb_defio.delay);
}

void ledhatfb_copyarea(struct fb_info *info, const struct fb_copyarea *area)
{
	sys_copyarea(info, area);
	schedule_delayed_work(&info->deferred_work, ledhatfb_defio.delay);
}

void ledhatfb_imageblit(struct fb_info *info, const struct fb_image *image)
{
	sys_imageblit(info, image);
	schedule_delayed_work(&info->deferred_work, ledhatfb_defio.delay);
}

static void *rvmalloc(unsigned long size)
{
	void *mem;
	unsigned long adr;
	size = PAGE_ALIGN(size);
	mem = vmalloc_32(size);
	if (!mem)
		return NULL;

	memset(mem, 0, size); /* Clear the ram out, no junk to the user */
	adr = (unsigned long) mem;
	while (size > 0) {
		SetPageReserved(vmalloc_to_page((void *)adr));
		adr += PAGE_SIZE;
		size -= PAGE_SIZE;
	}

	return mem;
}

static void rvfree(void *mem, unsigned long size)
{
	unsigned long adr;
	if (!mem)
		return;

	adr = (unsigned long) mem;
	while ((long) size > 0) {
		ClearPageReserved(vmalloc_to_page((void *)adr));
		adr += PAGE_SIZE;
		size -= PAGE_SIZE;
	}
	vfree(mem);
}

module_init(ledhat_init);
module_exit(ledhat_exit);
MODULE_DESCRIPTION("FB driver for the Raspberry Pi LEDHat");
MODULE_AUTHOR("Serge Schneider <serge@raspberrypi.org>");
MODULE_LICENSE("GPL");
