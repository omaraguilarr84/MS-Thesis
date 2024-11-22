import serial
import time

# Replace this with your Nano's port
port = "/dev/cu.usbserial-14110"

# List of common baud rates to test
baud_rates = [9600, 19200, 38400, 57600, 115200]

print("Starting auto-baud detection...\n")

for baud in baud_rates:
    try:
        print(f"Testing baud rate: {baud}")
        ser = serial.Serial(port, baudrate=baud, timeout=1)
        print(f"Connected to port at {baud}.")
        ser.write(b'\x55\x55')
        print(f"Message sent at {baud}.")
        response = ser.readline().decode('utf-8').strip()
        print(f"Response: {response}")
        ser.close()
    except Exception as e:
        print(f"Error at {baud}: {e}")

print("Auto-baud detection complete.")
