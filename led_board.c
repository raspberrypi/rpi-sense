#define F_CPU 8000000UL // 12 MHz
#include <avr/interrupt.h>
#include <avr/io.h>
#include <util/twi.h>
#include <stdio.h>
#include <stdlib.h>

#define GYRO_INT		(1 << PA0)
#define ACCEL_MAG_INT1		(1 << PA1)
#define ACCEL_MAG_INT2		(1 << PA2)

#define ROE_N			(1 << PB0)
#define GOE_N			(1 << PB1)
#define BOE_N			(1 << PB2)
#define OE_N			(ROE_N | GOE_N | BOE_N)
#define LED_SDI			(1 << PB3)
#define LED_SDO			(1 << PB4)
#define LED_CLK			(1 << PB5)
#define LED_LE			(1 << PB6)

#define COLUMN_INT		(1 << PC0)
#define FRAME_INT		(1 << PC1)
#define GPIO2_SDA1		(1 << PC4)
#define GPIO3_SCL1		(1 << PC5)

#define ACK_WRITE		0x60
#define ACK_READ		0xA8
#define DATA_RX			0x80
#define DATA_TX_ACK		0xb8
#define DATA_TX_NAK		0xc0

#define set(port,x) port |= (x)
#define clr(port,x) port &= ~(x)

extern void draw_loop(uint8_t *data);
extern void clear_gain(void);
extern void delay(uint8_t ticks);

//static void write_cfg(uint32_t cfg);

enum REG_ADDR {
	REG_ID = 192,
	REG_CFG_LOW,
	REG_CFG_HIGH,
};

typedef enum {
	DAT_LATCH = 22,
	CONF_WRITE = 20,
	CONF_READ  = 18,
	GAIN_WRITE = 16,
	GAIN_READ = 14,
	DET_OPEN = 13,
	DET_SHORT = 12,
	DET_OPEN_SHORT = 11,
	THERM_READ = 10,
} le_key;

uint8_t intensity[192] = {
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,

	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
	0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F,
};

//static void set_gain(uint32_t gain);

/* TODO: Get rid of C, just use ASM? */
int main(void)
{
	PORTA = 0;
	PORTB = 0;
	PORTC = 0;
	PORTD = 0;
	DDRA = GYRO_INT | ACCEL_MAG_INT1 | ACCEL_MAG_INT2;
	DDRB = ROE_N | GOE_N | BOE_N | LED_SDI | LED_CLK | LED_LE;
	DDRC = COLUMN_INT | FRAME_INT | GPIO2_SDA1;
	DDRD = 0xFF;

	TCCR0A = (1<<CS12);

	TWBR = 0xff;
	TWAR = 0x46 << 1;
	TWCR = (1 << TWEA) | (1 << TWEN) | (1 << TWINT) | (1 << TWIE);
	delay(255);
	clear_gain();
	//write_cfg(0xE00000);
	//set_gain(0);
	sei();
	draw_loop(intensity);
	for(;;);
}
/*
static void set_gain(uint32_t gain)
{
	int i;
	for (i = 0; i < 24; i++) { // 24 bits
		if ((gain>>=1)&0x1)
			set(PORTB, LED_SDI);
		else
			clr(PORTB, LED_SDI);
		set(PORTB, LED_CLK);
		clr(PORTB, LED_CLK);
		if (i==GAIN_WRITE)
			set(PORTB, LED_LE);
	}
	clr(PORTB, LED_LE);
}

static void write_cfg(uint32_t cfg)
{
	int i;
	for (i = 0; i < 24; i++) { // 24 bits
		if (cfg & 0x1)
			set(PORTB, LED_SDI);
		else
			clr(PORTB, LED_SDI);
		set(PORTB, LED_CLK);
		clr(PORTB, LED_CLK);
		if (i==CONF_WRITE)
			set(PORTB, LED_LE);
		cfg>>=1;
	}
	clr(PORTB, LED_LE);
}

// Function to implement read register interface
char do_function_r(int addr)
{
	if(addr < REG_ID)
		return intensity[addr];
	switch(addr){
	case REG_ID:
		return 0x00;
	case REG_CFG_LOW:
		write_cfg(0x00);
		break;
	case REG_CFG_HIGH:
		write_cfg(0xE00000);
		break;
	}
	return 0;
}

// Function to implement write register interface
void do_function_w(int addr, int val)
{
	if(addr < REG_ID)
		intensity[addr] = val;
	switch(addr){
	case REG_ID:
		break;
	case REG_CFG_LOW:
		break;
	}	
}

volatile uint8_t reg_address;
ISR(TWI_vect)
{
	uint8_t data;
	if( (TWSR & 0xF8) == TW_SR_SLA_ACK ){
		reg_address = 0xFF;
		TWCR |= (1<<TWIE) | (1<<TWINT) | (1<<TWEA) | (1<<TWEN);
	}
	else if( (TWSR & 0xF8) == TW_SR_DATA_ACK ){
		data = TWDR;
		if(reg_address == 0xFF){
			reg_address = data;
			TWCR |= (1<<TWIE) | (1<<TWINT) | (1<<TWEA) | (1<<TWEN);
		} else {
			do_function_w(reg_address, data);
			reg_address++;
			if(reg_address < 0xFF){
				TWCR |= (1<<TWIE) | (1<<TWINT) | (1<<TWEA) | (1<<TWEN);
			} else {
				TWCR |= (1<<TWIE) | (1<<TWINT) | (0<<TWEA) | (1<<TWEN);
			}
		}
	}
	else if( (TWSR & 0xF8) == TW_ST_DATA_ACK ){
		data = TWDR;
		if (reg_address == 0xFF ){
			reg_address = data;
		}
		TWDR = do_function_r(reg_address);
		reg_address++;
		if(reg_address < 0xFF){
			TWCR |= (1<<TWIE) | (1<<TWINT) | (1<<TWEA) | (1<<TWEN);
		} else {
			TWCR |= (1<<TWIE) | (1<<TWINT) | (0<<TWEA) | (1<<TWEN);
		}
	} else {
		TWCR |= (1<<TWIE) | (1<<TWEA) | (1<<TWEN);
	}
}*/