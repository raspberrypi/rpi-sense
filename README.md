# RPi-Sense

WIP LED HAT firmware and driver

## Prerequisites

`sudo apt-get install gcc-avr avr-libc`

https://github.com/kcuzner/avrdude

## Compiling

`make`

## Flashing

Ensure SPI is enabled.

`make flash`

## Using the board

Enable I2C in `raspi-config`

Enable the rpi-sense overlay in config.txt:

`dtoverlay=rpi-sense`

Add the following modules to `/etc/modules`:

```
ledhatfb
st_pressure_i2c
```

## Using IIO

https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-iio

https://archive.fosdem.org/2012/schedule/event/693/127_iio-a-new-subsystem.pdf

http://wiki.analog.com/software/linux/docs/iio/iio-trig-sysfs
