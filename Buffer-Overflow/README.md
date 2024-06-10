## Overview
1. Spiking
2. Fuzzing
3. Finding the Offset
4. Overwriting the EIP
5. Finding bad characters
6. Finding the right module
7. Generating shellcode

# 1. Spiking
Spiking allows us to find the functions/commands within a program that are vulnerable.

First, we attach the process unto our Debugger and then connect to it:

```bash
nc -nv PROCESS PORT
```
![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/9b63dcf6-11cb-4b21-996e-4deb42329361)

In our case, we see multiple functions that we could spike using:
```
generic_send_tcp 0.0.0.0 PORT spike.spk 0 0
```
![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/d2219e12-8268-4dd9-813c-7d9650f7d33f)
