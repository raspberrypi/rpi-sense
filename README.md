# RPi-Sense

WIP LED HAT firmware and driver

## Prerequisites

`sudo apt-get install gcc-avr avr-libc avrdude`

## Compiling

`make`

## Flashing

Ensure SPI is enabled.

`make flash`

## Using the board

Enable I2C in `raspi-config`

Boards with a programmed EEPROM will have nodes populated in the device tree automatically.

Add the following module to `/etc/modules`:

```
i2c-dev
```

## Using IIO

https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-iio

https://archive.fosdem.org/2012/schedule/event/693/127_iio-a-new-subsystem.pdf

http://wiki.analog.com/software/linux/docs/iio/iio-trig-sysfs
