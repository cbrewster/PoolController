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
int32_t pcPumpOnTimeCharId;
int32_t pcPumpOffTimeCharId;
int32_t pcPumpAutoCharId;
int32_t pcHeaterAutoCharId;
int32_t pcHeaterOnTimeCharId;
int32_t pcHeaterOffTimeCharId;

// == Globals ==
int loopTime = 0;
float waterTemp = 0;
float airTemp = 0;
bool pumpManual = false;
bool heaterManual = false;
int32_t pumpTimestamp;
int32_t heaterTimestamp;
int pumpOnHour = 8;
int pumpOnMinute = 0;
int pumpOffHour = 22;
int pumpOffMinute = 0;
int heaterOnHour = 8;
int heaterOnMinute = 0;
int heaterOffHour = 22;
int heaterOffMinute = 0;
bool pumpOn = false;
bool heaterOn = false;
bool pumpAuto = false;
bool heaterAuto = false;
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
    while (1)
      ;
  }
  // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM (for low power module)
  // No encryption
  rf69.setFrequency(RF69_FREQ);

  // If you are using a high power RF69 eg RFM69HW, you *must* set a Tx power with the
  // ishighpowermodule flag set like this:
  rf69.setTxPower(20, true); // range from 14-20 for power, 2nd arg must be true for 69HCW

  // The encryption key has to be the same as the one in the server
  uint8_t key[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                   0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
  rf69.setEncryptionKey(key);
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
    updateState();
  }
  else if (charId == pcHeaterManualCharId)
  {
    heaterManual = data[0] == 1;
    updateState();
  }
  else if (charId == pcThermostatCharId)
  {
    thermostat = data[0];
    updateState();
  }
  else if (charId == pcTimeCharId)
  {
    int32_t *newTime = (int32_t *)data;
    rtc.adjust(*newTime);
  }
  else if (charId == pcPumpOnTimeCharId)
  {
    pumpOnHour = (int)data[1];
    pumpOnMinute = (int)data[0];
  }
  else if (charId == pcPumpOffTimeCharId)
  {
    pumpOffHour = (int)data[1];
    pumpOffMinute = (int)data[0];
  }
  else if (charId == pcHeaterOnTimeCharId)
  {
    heaterOnHour = (int)data[1];
    heaterOnMinute = (int)data[0];
  }
  else if (charId == pcHeaterOffTimeCharId)
  {
    heaterOffHour = (int)data[1];
    heaterOffMinute = (int)data[0];
  }
  else if (charId == pcPumpAutoCharId)
  {
    pumpAuto = data[0] == 1;
    updateState();
  }
  else if (charId == pcHeaterAutoCharId)
  {
    heaterAuto = data[0] == 1;
    updateState();
  }
}

void setupBle()
{
  boolean success;

  ble.begin(false);

  if (FACTORYRESET_ENABLE)
  {
    /* Perform a factory reset to make sure everything is in a known state */
    ble.factoryReset();
  }

  // if (!ble.isVersionAtLeast(MINIMUM_FIRMWARE_VERSION))
  // {
  //   error(F("Callback requires at least 0.7.0"));
  // }

  /* Disable command echo from Bluefruit */
  ble.echo(false);

  /* Print Bluefruit information */
  // ble.info();

  /* Change the device name to make it easier to find */
  ble.sendCommandCheckOK(F("AT+GAPDEVNAME=Pool Control Center"));

  /* Add the Heart Rate Service definition */
  /* Service ID should be 1 */
  success = ble.sendCommandCheckOK(F("AT+GATTADDSERVICE=UUID=0x308E"));

  /* Add the Pool Controller Water Temp characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8270, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcWaterTempCharId);

  /* Add the Pool Controller Air Temp characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8271, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1"), &pcAirTempCharId);

  /* Add the Pool Controller Pump Manual characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8272, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcPumpManualCharId);

  /* Add the Pool Controller Heater Manual characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8273, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcHeaterManualCharId);

  /* Add the Pool Controller Thermostat characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8274, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=75"), &pcThermostatCharId);

  /* Add the Pool Controller Pump Status characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8275, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcPumpStatusCharId);

  /* Add the Pool Controller Heater Status characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8276, PROPERTIES=0x12, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcHeaterStatusCharId);

  /* Add the Pool Controller Pump Timestamp characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8277, PROPERTIES=0x12, MIN_LEN=4, MAX_LEN=4"), &pcPumpTimestampCharId);

  /* Add the Pool Controller Heater Timestamp characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8278, PROPERTIES=0x12, MIN_LEN=4, MAX_LEN=4"), &pcHeaterTimerstampCharId);

  /* Add the Pool Controller Current Time characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8279, PROPERTIES=0x1E, MIN_LEN=4, MAX_LEN=4"), &pcTimeCharId);

  /* Add the Pool Controller Pump On Time characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827A, PROPERTIES=0x1E, MIN_LEN=2, MAX_LEN=2"), &pcPumpOnTimeCharId);

  /* Add the Pool Controller Pump Off Time characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827B, PROPERTIES=0x1E, MIN_LEN=2, MAX_LEN=2"), &pcPumpOffTimeCharId);

  /* Add the Pool Controller Pump Auto characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827C, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcPumpAutoCharId);

  /* Add the Pool Controller Heater Auto characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827D, PROPERTIES=0x1E, MIN_LEN=1, MAX_LEN=1, VALUE=0"), &pcHeaterAutoCharId);

  /* Add the Pool Controller Heater On Time characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827E, PROPERTIES=0x1E, MIN_LEN=2, MAX_LEN=2"), &pcHeaterOnTimeCharId);

  /* Add the Pool Controller Heater Off Time characteristic */
  ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x827F, PROPERTIES=0x1E, MIN_LEN=2, MAX_LEN=2"), &pcHeaterOffTimeCharId);

  /* Add the Heart Rate Service to the advertising data */
  ble.sendCommandCheckOK(F("AT+GAPSETADVDATA=03-02-8E-30"));
  /* Reset the device for the new service setting changes to take effect */
  ble.reset();

  // Update initial timestamps
  pumpTimestamp = rtc.now().unixtime();
  heaterTimestamp = rtc.now().unixtime();
  updateChar(pcPumpTimestampCharId, pumpTimestamp);
  updateChar(pcHeaterTimerstampCharId, heaterTimestamp);
  updateScheduleChar(pcPumpOnTimeCharId, pumpOnHour, pumpOnMinute);
  updateScheduleChar(pcPumpOffTimeCharId, pumpOffHour, pumpOffMinute);
  updateScheduleChar(pcHeaterOnTimeCharId, heaterOnHour, heaterOnMinute);
  updateScheduleChar(pcHeaterOffTimeCharId, heaterOffHour, heaterOffMinute);

  ble.setBleGattRxCallback(pcPumpManualCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterManualCharId, BleGattRX);
  ble.setBleGattRxCallback(pcThermostatCharId, BleGattRX);
  ble.setBleGattRxCallback(pcTimeCharId, BleGattRX);
  ble.setBleGattRxCallback(pcPumpOnTimeCharId, BleGattRX);
  ble.setBleGattRxCallback(pcPumpOffTimeCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterOnTimeCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterOffTimeCharId, BleGattRX);
  ble.setBleGattRxCallback(pcPumpAutoCharId, BleGattRX);
  ble.setBleGattRxCallback(pcHeaterAutoCharId, BleGattRX);
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

  ble.waitForOK();
}

void updateScheduleChar(int32_t charId, int hour, int minute)
{
  char buffer[22];
  sprintf(buffer, "AT+GATTCHAR=%d,%02x-%02x", charId, hour, minute);

  ble.println(buffer);

  ble.waitForOK();
}

void sendData()
{
  updateChar(pcWaterTempCharId, (int32_t)waterTemp);
  updateChar(pcAirTempCharId, (int32_t)airTemp);
}

bool timeIsAfter(DateTime t, int hour, int minute)
{
  int minutes = hour * 60 + minute;
  // Adjust for time zone!
  int timeInMinutes = ((t.hour() + 19) % 24) * 60 + t.minute();
  return timeInMinutes >= minutes;
}

bool timeIsBefore(DateTime t, int hour, int minute)
{
  int minutes = hour * 60 + minute;
  // Adjust for time zone!
  int timeInMinutes = ((t.hour() + 19) % 24) * 60 + t.minute();
  return timeInMinutes < minutes;
}

void updateState()
{
  bool oldPumpOn = pumpOn;
  bool oldHeaterOn = heaterOn;

  bool pumpOnAuto = false;
  bool heaterOnAuto = false;

  if (pumpAuto)
  {
    DateTime now = rtc.now();
    int timeOn = pumpOnHour * 60 + pumpOnMinute;
    int timeOff = pumpOffHour * 60 + pumpOffMinute;

    if (timeOn < timeOff)
    {
      pumpOnAuto = timeIsAfter(now, pumpOnHour, pumpOnMinute) && timeIsBefore(now, pumpOffHour, pumpOffMinute);
    }
    else if (timeOn > timeOff)
    {
      pumpOnAuto = timeIsAfter(now, pumpOnHour, pumpOnMinute) || timeIsBefore(now, pumpOffHour, pumpOffMinute);
    }
  }

  if (heaterAuto)
  {
    DateTime now = rtc.now();
    int timeOn = heaterOnHour * 60 + heaterOnMinute;
    int timeOff = heaterOffHour * 60 + heaterOffMinute;

    if (timeOn < timeOff)
    {
      heaterOnAuto = timeIsAfter(now, heaterOnHour, heaterOnMinute) && timeIsBefore(now, heaterOffHour, heaterOffMinute);
    }
    else if (timeOn > timeOff)
    {
      heaterOnAuto = timeIsAfter(now, heaterOnHour, heaterOnMinute) || timeIsBefore(now, heaterOffHour, heaterOffMinute);
    }
  }

  bool heaterEnabled = (!heaterAuto && heaterManual) || (heaterAuto && heaterOnAuto);

  if (heaterOn)
  {
    // If the heater has been on, wait to heat until the thermostat temperature is met.
    heaterOn = heaterEnabled && (waterTemp < thermostat);
  }
  else
  {
    // If the heater has been off, wait until we are at least 2 degrees below the set temperature
    // to turn back on.
    heaterOn = heaterEnabled && (waterTemp < thermostat - 1);
  }

  // Pump will be on if the manual control is set or if the heater is enabled.
  pumpOn = (!pumpAuto && pumpManual) || (pumpAuto && pumpOnAuto) || heaterOn;

  // Check if state changed
  if (oldPumpOn != pumpOn)
  {
    pumpTimestamp = rtc.now().unixtime();
    updateChar(pcPumpTimestampCharId, pumpTimestamp);
    updateChar(pcPumpStatusCharId, (int32_t)pumpOn);

    digitalWrite(PUMP_RELAY, pumpOn);
  }

  // Check if state changed
  if (oldHeaterOn != heaterOn)
  {
    heaterTimestamp = rtc.now().unixtime();
    updateChar(pcHeaterTimerstampCharId, heaterTimestamp);
    updateChar(pcHeaterStatusCharId, (int32_t)heaterOn);

    digitalWrite(HEATER_RELAY, heaterOn);
  }
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
      getAirTemp();
      updateState();
      sendData();

      // Send a reply back to the originator client
      rf69_manager.sendtoWait(data, sizeof(data), from);
    }
  }

  // Must call update to process the Rx callbacks.
  ble.update(200);

  updateState();
  delay(1);
}
