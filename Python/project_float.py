# Code taken from lab5 and modified to fit our project usecase

import RPi.GPIO as GPIO
from time import sleep
import spidev

MyARM_ResetPin = 19  # Pin 4 of the connector = BCM19 = GPIO[1]

# Initialize the SPI device for communication with the FPGA
MySPI_FPGA = spidev.SpiDev()
MySPI_FPGA.open(0, 0)  # Open SPI bus
MySPI_FPGA.max_speed_hz = 500000  # Set SPI communication speed

# Configure GPIO settings
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)
GPIO.setup(MyARM_ResetPin, GPIO.OUT)

# Reset the FPGA
GPIO.output(MyARM_ResetPin, GPIO.HIGH)
sleep(0.1)
GPIO.output(MyARM_ResetPin, GPIO.LOW)
sleep(0.1)

to_continue = True
SCALE_FACTOR = 65536.0  # we use Q16.16 fixed point for float representation, this is just a scale factor for it

while to_continue:
    try:
        user_input = input("Enter a number to calculate SQRT (0.0 to exit) : ")
        if user_input == "0":
            break
        number = float(user_input)
        if number < 0.0:
            print("Please enter a positive number")
            continue
    except ValueError:
        print("Please enter a valid number.")
        continue

    if number == 0:
        to_continue = False

    # ==========================================
    # 1. Convert Float to Q16.16 Integer
    # ==========================================
    # Example: 4.0 becomes 262144 (0x00040000)
    fixed_point_val = int(number * SCALE_FACTOR)

    # Pack into 4 bytes (Big Endian).
    data_bytes = list(fixed_point_val.to_bytes(4, 'big', signed=False))

    # Send Write Command (0x80, address 0x400) + 4 Data Bytes
    ToSPI = [0x80] + data_bytes
    FromSPI = MySPI_FPGA.xfer2(ToSPI)
    sleep(0.1)

    # Reset, this was used in the lab 5, in our case it is not 100% necessary but it's always good to clean after ourselves
    GPIO.output(MyARM_ResetPin, GPIO.HIGH)
    sleep(0.1)
    GPIO.output(MyARM_ResetPin, GPIO.LOW)

    # Send SPI packet to request the Result (address 0x404)
    ToSPI = [0x01, 0x00, 0x00, 0x00, 0x00]
    FromSPI = MySPI_FPGA.xfer2(ToSPI)

    print("SPI Packet return :", [hex(x) for x in FromSPI])

    # ==========================================
    # 2. Convert Q16.16 Integer back to Float
    # ==========================================
    # We skip FromSPI[0] because it corresponds to the Command byte exchange
    result_raw = int.from_bytes(FromSPI[1:], byteorder='big')
    final_result = result_raw / 256.0
    print(f"Root is: {final_result:.2f}")

    # Final reset sequence for the FPGA
    GPIO.output(MyARM_ResetPin, GPIO.HIGH)
    sleep(0.1)
    GPIO.output(MyARM_ResetPin, GPIO.LOW)