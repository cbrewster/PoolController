// The sensor module reads the water temp and depth and
// transmits the values to the control center via a radio
//
// This code is designed to run on an Adafruit 32u4 RFM69HCW.

#include <OneWire.h>
#include <DallasTemperature.h>

#define WATER_TEMP_PIN 13

OneWire oneWire(WATER_TEMP_PIN);

DallasTemperature sensors(&oneWire);

DeviceAddress waterThermometer;

void setup() {
  // Setup serial baud rate
  Serial.begin(9600);

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
}
