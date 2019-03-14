#include <SPI.h>
#include <RH_RF69.h>
#include <RHReliableDatagram.h>
#include "BluefruitConfig.h"
#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "BluefruitConfig.h"
#include "Adafruit_MCP9808.h"
#include "RTClib.h"

// == RTC ==
RTC_PCF8523 rtc;

// == AIR TEMP SETUP ==
Adafruit_MCP9808 airTempSensor = Adafruit_MCP9808();

// == RELAY SETUP ==
#define PUMP_RELAY 12
#define HEATER_RELAY 11

// == RADIO SETUP ==
#define RF69_FREQ 915.0

#define MY_ADDRESS 1

#define RFM69_CS 8
#define RFM69_INT 7
#define RFM69_RST 4

// Singleton instance of the radio driver
RH_RF69 rf69(RFM69_CS, RFM69_INT);

// Class to manage message delivery and receipt, using the driver declared above
RHReliableDatagram rf69_manager(rf69, MY_ADDRESS);

int16_t packetnum = 0; // packet counter, we increment per xmission

// == BLE Setup ==
Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);

// Disable this in production
#define FACTORYRESET_ENABLE 1
#define MINIMUM_FIRMWARE_VERSION "0.7.0"

int32_t pcWaterTempCharId;
int32_t pcAirTempCharId;
int32_t pcPumpManualCharId;
int32_t pcHeaterManualCharId;
int32_t pcThermostatCharId;
int32_t pcPumpStatusCharId;
int32_t pcHeaterStatusCharId;
int32_t pcPumpTimestampCharId;
int32_t pcHeaterTimerstampCharId;
int32_t pcTimeCharId;

// == Globals ==
unsigned long loopTime = 0;
unsigned long lastTime;
float waterTemp = 0;
float airTemp = 0;
bool pumpManual = true;
bool heaterManual = true;
int32_t pumpTimestamp;
int32_t heaterTimestamp;

bool pumpOn = true;
bool heaterOn = true;
uint8_t thermostat = 75;

void setup()
{
  // while (!Serial)
  //   ;
  Serial.begin(115200);
  setupAirTemp();
  setupRelays();
  setupRadio();
  setupRTC();
  setupBle();
}

void setupRTC()
{
  if (!rtc.begin())
  {
    while (1)
      ;
  }

  if (!rtc.initialized())
  {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }
}

void setupAirTemp()
{
  if (!airTempSensor.begin(0x18))
  {
    error(F("Couldn't find MCP9808! Check your connections and verify the address is correct."));
    while (1)
      ;
  }

  airTempSensor.setResolution(3);

  airTempSensor.wake();
}

void setupRelays()
{
  pinMode(PUMP_RELAY, OUTPUT);
  pinMode(HEATER_RELAY, OUTPUT);

  digitalWrite(PUMP_RELAY, pumpOn);
  digitalWrite(HEATER_RELAY, heaterOn);
}

void setupRadio()
{
  pinMode(RFM69_RST, OUTPUT);
  digitalWrite(RFM69_RST, LOW);

  // manual reset
  digitalWrite(RFM69_RST, HIGH);
  delay(10);
  digitalWrite(RFM69_RST, LOW);
  delay(10);

  if (!rf69_manager.init())
  {
    error(F("RFM69 radio init failed"));
    while (1)
      ;
  }
  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM (for low power module)
  // No encryption
  if (!rf69.setFrequency(RF69_FREQ))
  {
    error(F("setFrequency failed"));
  }

  // If you are using a high power RF69 eg RFM69HW, you *must* set a Tx power with the
  // ishighpowermodule flag set like this:
  rf69.setTxPower(20, true); // range from 14-20 for power, 2nd arg must be true for 69HCW

  // The encryption key has to be the same as the one in the server
  uint8_t key[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                   0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
  rf69.setEncryptionKey(key);
}

// A small helper
void error(const __FlashStringHelper *err)
{
  // Serial.println(err);
  while (1)
    ;
}

void BleGattRX(int32_t charId, uint8_t data[], uint16_t len)
{
  if (len == 0)
  {
    return;
  }

  if (charId == pcPumpManualCharId)
  {
    pumpManual = data[0] == 1;
  }
  else if (charId == pcHeaterManualCharId)
  {
    heaterManual = data[0] == 1;
  }
  else if (charId == pcThermostatCharId)
  {
    thermostat = data[0];
  }
  else if (charId == pcTimeCharId)
  {
    int32_t *newTime = (int32_t *)data;
    rtc.adjust(*newTime);
  }
}

void setupBle()
{
  boolean success;

  if (!ble.begin(false))
  {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }

  if (FACTORYRESET_ENABLE)
  {
    /* Perform a factory reset to make sure everything is in a known state */
    if (!ble.factoryReset())
    {
      error(F("Couldn't factory reset"));
    }
  }

  if (!ble.isVersionAtLeast(MINIMUM_FIRMWARE_VERSION))
  {
    error(F("Callback requires at least 0.7.0"));
  }

  /* Disable command echo from Bluefruit */
  ble.echo(false);

  /* Print Bluefruit information */
  // ble.info();

  /* Change the device name to make it easier to find */
  if (!ble.sendCommandCheckOK(F("AT+GAPDEVNAME=Pool Control Center")))
  {
    error(F("Could not set device name?"));
  }

  /* Add the Heart Rate Service definition */
  /* Service ID should be 1 */
  success = ble.sendCommandCheckOK(F("AT+GATTADDSERVICE=UUID=0x308E"));

  /* Add the Pool Controller Water Temp characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8270, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcWaterTempCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Air Temp characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8271, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcAirTempCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Pump Manual characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8272, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=1"), &pcPumpManualCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Heater Manual characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8273, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=1"), &pcHeaterManualCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Thermostat characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8274, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=75"), &pcThermostatCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Pump Status characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8275, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcPumpStatusCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Heater Status characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8276, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcHeaterStatusCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Pump Timestamp characteristic */
  pumpTimestamp = rtc.now().unixtime();
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8277, PROPERTIES=0x12, MIN_LEN=4, MAX_LEN=4"), &pcPumpTimestampCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Heater Timestamp characteristic */
  heaterTimestamp = rtc.now().unixtime();
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8278, PROPERTIES=0x12, MIN_LEN=4, MAX_LEN=4"), &pcHeaterTimerstampCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Pool Controller Current Time characteristic */
  if (!ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8279, PROPERTIES=0x1E, MIN_LEN=4, MAX_LEN=4"), &pcTimeCharId))
  {
    error(F("Could not add pool controller characteristic"));
  }

  /* Add the Heart Rate Service to the advertising data */
  ble.sendCommandCheckOK(F("AT+GAPSETADVDATA=03-02-8E-30"));
  /* Reset the device for the new service setting changes to take effect */
  ble.reset();

  ble.setBleGattRxCallback(pcPumpManualCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterManualCharId, BleGattRX);
  ble.setBleGattRxCallback(pcThermostatCharId, BleGattRX);
  ble.setBleGattRxCallback(pcTimeCharId, BleGattRX);
}

void getAirTemp()
{
  airTemp = airTempSensor.readTempF();
}

void updateChar(int32_t charId, int32_t value)
{
  ble.print(F("AT+GATTCHAR="));
  ble.print(charId);
  ble.print(F(","));
  ble.println(value);

  if (!ble.waitForOK())
  {
    error(F("Failed to get response!"));
  }
}

void sendData()
{
  updateChar(pcWaterTempCharId, (int32_t)waterTemp);
  updateChar(pcAirTempCharId, (int32_t)airTemp);
  updateChar(pcPumpStatusCharId, (int32_t)pumpOn);
  updateChar(pcHeaterStatusCharId, (int32_t)heaterOn);
  updateChar(pcPumpTimestampCharId, pumpTimestamp);
  updateChar(pcHeaterTimerstampCharId, heaterTimestamp);
  Serial.println(pumpTimestamp);
}

void updateState()
{
  bool oldPumpOn = pumpOn;
  bool oldHeaterOn = heaterOn;

  if (heaterOn)
  {
    // If the heater has been on, wait to heat until the thermostat temperature is met.
    heaterOn = heaterManual && (waterTemp < thermostat);
  }
  else
  {
    // If the heater has been off, wait until we are at least 2 degrees below the set temperature
    // to turn back on.
    heaterOn = heaterManual && (waterTemp < thermostat - 1);
  }

  // Pump will be on if the manual control is set or if the heater is enabled.
  pumpOn = pumpManual || heaterOn;

  // Check if state changed
  if (oldPumpOn != pumpOn)
  {
    pumpTimestamp = rtc.now().unixtime();
    Serial.print("Pump Timestamp: ");
    Serial.println(pumpTimestamp);
  }

  // Check if state changed
  if (oldHeaterOn != heaterOn)
  {
    heaterTimestamp = rtc.now().unixtime();
    Serial.print("Heater Timestamp: ");
    Serial.println(heaterTimestamp);
  }

  digitalWrite(PUMP_RELAY, pumpOn);
  digitalWrite(HEATER_RELAY, heaterOn);
}

uint8_t data[] = "ack";
uint8_t buf[RH_RF69_MAX_MESSAGE_LEN];

void loop()
{
  if (rf69_manager.available())
  {
    // Wait for a message addressed to us from the client
    uint8_t len = sizeof(buf);
    uint8_t from;
    if (rf69_manager.recvfromAck(buf, &len, &from))
    {
      buf[len] = 0; // zero out remaining string

      memcpy((uint8_t *)&waterTemp, buf, 4);

      // Send a reply back to the originator client
      if (!rf69_manager.sendtoWait(data, sizeof(data), from))
        error(F("Sending failed (no ack)"));
    }
  }

  loopTime += millis() - lastTime;
  lastTime = millis();
  if (loopTime > 500)
  {
    loopTime = 0;
    getAirTemp();
    updateState();
    sendData();
  }

  // Must call update to process the Rx callbacks.
  ble.update(200);
  delay(1);
}
