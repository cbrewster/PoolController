#include <SPI.h>
#include <RH_RF69.h>
#include <RHReliableDatagram.h>
#include "BluefruitConfig.h"
#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "Adafruit_BluefruitLE_UART.h"
#include "BluefruitConfig.h"
#include <Wire.h>
#include "Adafruit_MCP9808.h"

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
#define DBG_ENABLE 1

int32_t pcWaterTempCharId;
int32_t pcAirTempCharId;
int32_t pcPumpOnCharId;
int32_t pcHeaterOnCharId;
int32_t pcThermostatCharId;

// == Globals ==
unsigned long loopTime = 0;
unsigned long lastTime;
float waterTemp = 0;
float airTemp = 0;
bool pumpOn = true;
bool heaterOn = true;
int thermostat = 75;

void setup()
{
  Serial.begin(115200);
  setupAirTemp();
  setupRelays();
  setupRadio();
  setupBle();
}

void setupAirTemp()
{
  if (!airTempSensor.begin(0x18))
  {
    Serial.println(F("Couldn't find MCP9808! Check your connections and verify the address is correct."));
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

  Serial.println(F("Feather Addressed RFM69 RX Test!"));
  Serial.println();

  // manual reset
  digitalWrite(RFM69_RST, HIGH);
  delay(10);
  digitalWrite(RFM69_RST, LOW);
  delay(10);

  if (!rf69_manager.init())
  {
    Serial.println(F("RFM69 radio init failed"));
    while (1)
      ;
  }
  Serial.println(F("RFM69 radio init OK!"));
  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM (for low power module)
  // No encryption
  if (!rf69.setFrequency(RF69_FREQ))
  {
    Serial.println(F("setFrequency failed"));
  }

  // If you are using a high power RF69 eg RFM69HW, you *must* set a Tx power with the
  // ishighpowermodule flag set like this:
  rf69.setTxPower(20, true); // range from 14-20 for power, 2nd arg must be true for 69HCW

  // The encryption key has to be the same as the one in the server
  uint8_t key[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                   0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
  rf69.setEncryptionKey(key);

  Serial.print(F("RFM69 radio @"));
  Serial.print((int)RF69_FREQ);
  Serial.println(F(" MHz"));
}

// A small helper
void error(const __FlashStringHelper *err)
{
  Serial.println(err);
  while (1)
    ;
}

// Sets up a new characteristic with the given UUID, Properties, and puts the result characteristic
// id in `charId`.
void registerCharacteristic(char uuid[], char properties[], int value, int32_t *charId)
{
  boolean success;

  Serial.print(F("Adding the Pool Controller characteristic (UUID = "));
  Serial.print(uuid);
  Serial.println(F("): "));

  char command[80];
  sprintf(command, "AT+GATTADDCHAR=UUID=%s, PROPERTIES=%s, MIN_LEN=1, MAX_LEN=1, DATATYPE=3, VALUE=%d", uuid, properties, value);
  Serial.println(command);
  success = ble.sendCommandWithIntReply(command, charId);
  if (!success)
  {
    error(F("Could not add pool controller characteristic"));
  }
}

void BleGattRX(int32_t charId, uint8_t data[], uint16_t len)
{
  Serial.print(F("Got some new data! "));
  Serial.println(charId);

  if (len == 0)
  {
    return;
  }

  if (charId == pcPumpOnCharId)
  {
    pumpOn = data[0] == 1;
    if (heaterOn && !pumpOn)
    {
      heaterOn = false;
      updateChar(pcHeaterOnCharId, (int)heaterOn);
    }
  }
  else if (charId == pcHeaterOnCharId)
  {
    heaterOn = data[0] == 1;
    if (heaterOn)
    {
      pumpOn = true;
      updateChar(pcPumpOnCharId, (int)pumpOn);
    }
  }
  else if (charId == pcThermostatCharId)
  {
    thermostat = data[0];
  }
  digitalWrite(PUMP_RELAY, pumpOn);
  digitalWrite(HEATER_RELAY, heaterOn);
}

void setupBle()
{
  boolean success;

  Serial.print(F("Initialising the Bluefruit LE module: "));

  if (!ble.begin(false))
  {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }
  Serial.println(F("OK!"));

  if (FACTORYRESET_ENABLE)
  {
    /* Perform a factory reset to make sure everything is in a known state */
    Serial.println(F("Performing a factory reset: "));
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
  ble.echo(true);

  Serial.println(F("Requesting Bluefruit info:"));
  /* Print Bluefruit information */
  ble.info();

  /* Change the device name to make it easier to find */
  Serial.println(F("Setting device name to 'Pool Control Center': "));

  if (!ble.sendCommandCheckOK(F("AT+GAPDEVNAME=Pool Control Center")))
  {
    error(F("Could not set device name?"));
  }

  /* Add the Heart Rate Service definition */
  /* Service ID should be 1 */
  Serial.println(F("Adding the Pool Controller Service definition (UUID = 0x308E): "));
  success = ble.sendCommandCheckOK(F("AT+GATTADDSERVICE=UUID=0x308E"));

  /* Add the Pool Controller Water Temp characteristic */
  registerCharacteristic("0x8270", "0x12", (int)waterTemp, &pcWaterTempCharId);

  /* Add the Pool Controller Air Temp characteristic */
  registerCharacteristic("0x8271", "0x12", (int)airTemp, &pcAirTempCharId);

  /* Add the Pool Controller Pump On characteristic */
  registerCharacteristic("0x8272", "0x1E", pumpOn == 1, &pcPumpOnCharId);

  /* Add the Pool Controller Heater On characteristic */
  registerCharacteristic("0x8273", "0x1E", heaterOn == 1, &pcHeaterOnCharId);

  /* Add the Pool Controller Thermostat characteristic */
  registerCharacteristic("0x8274", "0x1E", thermostat, &pcThermostatCharId);

  /* Add the Heart Rate Service to the advertising data */
  Serial.println(F("Adding Pool Control Center Service UUID to the advertising payload: "));
  ble.sendCommandCheckOK(F("AT+GAPSETADVDATA=03-02-8E-30"));
  /* Reset the device for the new service setting changes to take effect */
  Serial.println(F("Performing a SW reset (service changes require a reset): "));
  ble.reset();

  ble.setBleGattRxCallback(pcPumpOnCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterOnCharId, BleGattRX);
  ble.setBleGattRxCallback(pcThermostatCharId, BleGattRX);
}

void getAirTemp()
{
  airTemp = airTempSensor.readTempF();
  Serial.println(airTemp);
}

void updateChar(int32_t charId, int value)
{
  ble.print(F("AT+GATTCHAR="));
  ble.print(charId);
  ble.print(F(","));
  ble.println((int)value);

  if (!ble.waitForOK())
  {
    Serial.println(F("Failed to get response!"));
  }
}

void sendData()
{
  Serial.println("Sending new data!");

  updateChar(pcWaterTempCharId, (int)waterTemp);
  updateChar(pcAirTempCharId, (int)airTemp);
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

      Serial.print(F("Got packet from #"));
      Serial.print(from);
      Serial.print(F(" [RSSI :"));
      Serial.print(rf69.lastRssi());
      Serial.print(F("] Temp: "));
      memcpy((uint8_t *)&waterTemp, buf, 4);
      Serial.print(waterTemp);
      Serial.println();

      // Send a reply back to the originator client
      if (!rf69_manager.sendtoWait(data, sizeof(data), from))
        Serial.println(F("Sending failed (no ack)"));
    }
  }

  loopTime += millis() - lastTime;
  lastTime = millis();
  if (loopTime > 3000)
  {
    loopTime = 0;
    getAirTemp();
    sendData();
  }

  ble.update(200);
}
