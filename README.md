# WLED Build For SP530E  
Prepare UART Converter  
Download `WLED_16.x.x_C3_Custom.bin` at Release page  
Download ESPtool [Here](https://github.com/espressif/esptool/releases)  

> The release binary already includes bootloader and partition table.  
> No need to download them separately.

## Connect UART Cable to board reverse side  
## Use this Command below to backup the original firmware.  
```
esptool read_flash 0 0x400000 sp530e-encrypted.bin
```

## Use this Command below to flash the custom firmware.
### Please replace `16.x.x` with the actual version number you downloaded (e.g., `16.0.0`)
```
esptool write_flash --encrypt 0x0 WLED_16.x.x_C3_Custom.bin
```

## I/O Pins:  
On Board Button GPIO 8  
On Board Mic GPIO 3  
On Board Blue LED GPIO 0 (Inverted)  
On Board Green LED GPIO 1 (Inverted)  
LED DAT Output GPIO 19  
### Analog Pins:  
R: GPIO 10  
G: GPIO 7  
B: GPIO 6  
WW: GPIO 5  
CW: GPIO 4 
