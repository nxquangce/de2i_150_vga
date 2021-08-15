\[Updating\]
# DE2i-150 VGA
This is a sample project on DE2i-150 FPGA to display graphic on monitor through VGA interface. Moreover, this project is included some mini projects for demonstrating.  

## General design
VGA controller read data in memory (RAM) to generate signals to VGA port. User writes data to that memory to display. There are drawing modules take responsibility to do that job. Control commands to instruct these modules is issued from a FIFO. After all, works to do are write reasonable commands to the FIFO.  

### Drawing modules
- draw_superpixel: Draw a square (superpixel) at a logic position.  
- draw_rectangle_sp: Draw a rectangle from a top-left superpixel to bottom-right superpixel.  
- draw_rectangle: Draw a rectangle with physical pixel addresses.
- draw_char: Draw a characacter at a physical position with size, background, foreground, character code in ASCII (some are different) as inputs.

### Commands
Format: {opcode, params}  
Bitwidth: 32 bit - 4 bit opcode  

- draw_superpixel: 
```
4'h0, x logic, y logic, color, reserved
```  
- draw_rectangle_sp:
```
4'h1, top-left x logic, top-left y logic, bottom-right x logic, bottom-right y logic, color
```
- draw_rectangle: 2 consecutive commands  
```
4'h9, top-left x physic, top-left y physic, color, 1'b0  
4'h9, bottom-right x physic, bottom-right y physic, color, 1'b0
```
- draw_char: 2 consecutive commands  
```
4'ha, top-left x physic, top-left y physic, character code, 1'b0  
4'ha, foreground color, background color, size, 1'b1
```

## Demo Proejcts
### Snake game
Source: snake_*.v  
Control:  
- Reset game: SW[1] & (~KEY[1])
- KEY[3:0]: Left, Up, Down, Right
