// The sensor module reads the water temp and depth and
// transmits the values to the control center via a radio
//
// This code is designed to run on an Adafruit 32u4 RFM69HCW.

#include <OneWire.h>
#include <DallasTemperature.h>
#include <SPI.h>
#include <RH_RF69.h>
#include <RHReliableDatagram.h>

// == Radio ==
#define RF69_FREQ 915.0
// Make sure the control center has this address
#define DEST_ADDRESS 1
#define MY_ADDRESS 2

// Setup for Feather 32u4 with Radio
#define RFM69_CS 8
#define RFM69_INT 7
#define RFM69_RST 4

RH_RF69 rf69(RFM69_CS, RFM69_INT);
RHReliableDatagram rf69_manager(rf69, MY_ADDRESS);

// This increments every time a packet is transmitted
int16_t packet_num = 0;

// Buffers for sending messages
uint8_t buf[RH_RF69_MAX_MESSAGE_LEN];
uint8_t data[] = " OK";

// == Water Temp ==
#define WATER_TEMP_PIN 13

OneWire oneWire(WATER_TEMP_PIN);
DallasTemperature sensors(&oneWire);
DeviceAddress waterThermometer;

void setup() {
  // Setup serial baud rate
  Serial.begin(9600);

  setupTempSensor();
  setupRadio();
}

// Sets up the radio on the Feather
void setupRadio() {
  pinMode(RFM69_RST, OUTPUT);
  digitalWrite(RFM69_RST, LOW);

  digitalWrite(RFM69_RST, HIGH);
  delay(10);
  digitalWrite(RFM69_RST, LOW);
  delay(10);

  if (!rf69_manager.init()) {
    Serial.println("Radio init failed");
    // Stop if radio init failed
    while (1);
  }

  if (!rf69.setFrequency(RF69_FREQ)) {
    Serial.println("Could not set frequency");
  }

  // Power can be 14-20. Starting with 20, may adjust later.
  rf69.setTxPower(20, true);

  // The encryption key has to be the same as the one in the server
  uint8_t key[] = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
                  };
  rf69.setEncryptionKey(key);
}

// Connects to the DS18B20 temp sensor
void setupTempSensor() {
  Serial.println("Looking for temperature sensor");
  sensors.begin();

  if (sensors.getAddress(waterThermometer, 0)) {
    Serial.println("Connected to thermometer");
  }

  sensors.setResolution(waterThermometer, 9);
}

void loop() {
  // Wait 3 seconds
  delay(3000);

  // Request temp from sensor
  sensors.requestTemperatures();

  // Print current temp
  float temp = sensors.getTempF(waterThermometer);
  Serial.print("Temp: ");
  Serial.println(temp);
  transmitTemperature(temp, 10.0);
}

void transmitTemperature(float temp, float depth) {
  char packet[8];
  memcpy(packet, (char*)(&temp), 4);
  memcpy(packet+4, (char*)(&depth), 4);
  
  Serial.print("Sending Temp: ");
  Serial.print(*(float*)packet);
  Serial.print(" Depth: ");
  Serial.println(*(float*)(packet + 4));

  if (rf69_manager.sendtoWait((uint8_t *)packet, strlen(packet), DEST_ADDRESS)) {
    uint8_t len = sizeof(buf);
    uint8_t from;
    if (rf69_manager.recvfromAckTimeout(buf, &len, 2000, &from)) {
      Serial.println("Got reply!");
    } else {
      Serial.println("No Reply");
    }
  } else {
    Serial.println("Sending Failed :(");
  }
}
