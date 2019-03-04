#include <SPI.h>
#include <RH_RF69.h>
#include <RHReliableDatagram.h>
#include "BluefruitConfig.h"
#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "Adafruit_BluefruitLE_UART.h"
#include "Adafruit_BLEBattery.h"
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

int32_t pcServiceId;
int32_t pcWaterTempCharId;
int32_t pcAirTempCharId;
int32_t pcPumpOnCharId;
int32_t pcHeaterOnCharId;

// == Globals ==
unsigned long loopTime = 0;
unsigned long lastTime;
float waterTemp = 0;
float airTemp = 0;
int pumpOn = 0;
int heaterOn = 0;

void setup()
{
    // while (!Serial)
    //     ; // disable in production
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
        Serial.println("Couldn't find MCP9808! Check your connections and verify the address is correct.");
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

    digitalWrite(PUMP_RELAY, LOW);
    digitalWrite(HEATER_RELAY, LOW);
}

void setupRadio()
{
    pinMode(RFM69_RST, OUTPUT);
    digitalWrite(RFM69_RST, LOW);

    Serial.println("Feather Addressed RFM69 RX Test!");
    Serial.println();

    // manual reset
    digitalWrite(RFM69_RST, HIGH);
    delay(10);
    digitalWrite(RFM69_RST, LOW);
    delay(10);

    if (!rf69_manager.init())
    {
        Serial.println("RFM69 radio init failed");
        while (1)
            ;
    }
    Serial.println("RFM69 radio init OK!");
    // Defaults after init are 434.0MHz, modulation GFSK_Rb250Fd250, +13dbM (for low power module)
    // No encryption
    if (!rf69.setFrequency(RF69_FREQ))
    {
        Serial.println("setFrequency failed");
    }

    // If you are using a high power RF69 eg RFM69HW, you *must* set a Tx power with the
    // ishighpowermodule flag set like this:
    rf69.setTxPower(20, true); // range from 14-20 for power, 2nd arg must be true for 69HCW

    // The encryption key has to be the same as the one in the server
    uint8_t key[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                     0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
    rf69.setEncryptionKey(key);

    Serial.print("RFM69 radio @");
    Serial.print((int)RF69_FREQ);
    Serial.println(" MHz");
}

// A small helper
void error(const __FlashStringHelper *err)
{
    Serial.println(err);
    while (1)
        ;
}

void setupBle()
{
    boolean success;

    Serial.print(F("Initialising the Bluefruit LE module: "));

    if (!ble.begin(VERBOSE_MODE))
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

    /* Disable command echo from Bluefruit */
    ble.echo(false);

    Serial.println("Requesting Bluefruit info:");
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
    success = ble.sendCommandWithIntReply(F("AT+GATTADDSERVICE=UUID=0x308E"), &pcServiceId);
    if (!success)
    {
        error(F("Could not add Pool Controller service"));
    }

    /* Add the Pool Controller Water Temp characteristic */
    Serial.println(F("Adding the Pool Controller characteristic (UUID = 0x8270): "));
    success = ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8270, PROPERTIES=0x10, MIN_LEN=1, MAX_LEN=1, VALUE=00"), &pcWaterTempCharId);
    if (!success)
    {
        error(F("Could not add HRM characteristic"));
    }

    /* Add the Pool Controller Air Temp characteristic */
    Serial.println(F("Adding the Pool Controller characteristic (UUID = 0x8271): "));
    success = ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8271, PROPERTIES=0x10, MIN_LEN=1, MAX_LEN=1, VALUE=00"), &pcAirTempCharId);
    if (!success)
    {
        error(F("Could not add HRM characteristic"));
    }

    /* Add the Pool Controller Pump On characteristic */
    Serial.println(F("Adding the Pool Controller characteristic (UUID = 0x8272): "));
    success = ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8272, PROPERTIES=0x18, MIN_LEN=1, MAX_LEN=1, VALUE=00"), &pcPumpOnCharId);
    if (!success)
    {
        error(F("Could not add HRM characteristic"));
    }

    /* Add the Pool Controller Heater On characteristic */
    Serial.println(F("Adding the Pool Controller characteristic (UUID = 0x8273): "));
    success = ble.sendCommandWithIntReply(F("AT+GATTADDCHAR=UUID=0x8273, PROPERTIES=0x18, MIN_LEN=1, MAX_LEN=1, VALUE=00"), &pcHeaterOnCharId);
    if (!success)
    {
        error(F("Could not add HRM characteristic"));
    }

    /* Add the Heart Rate Service to the advertising data */
    Serial.print(F("Adding Pool Control Center Service UUID to the advertising payload: "));
    ble.sendCommandCheckOK(F("AT+GAPSETADVDATA=03-02-8E-30"));

    /* Reset the device for the new service setting changes to take effect */
    Serial.print(F("Performing a SW reset (service changes require a reset): "));
    ble.reset();

    Serial.println();
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
    updateChar(pcPumpOnCharId, (int)pumpOn);
    updateChar(pcHeaterOnCharId, (int)heaterOn);
}

int readData(int32_t charId)
{
    int32_t reply;
    boolean success;
    char command[20];
    sprintf(command, "AT+GATTCHAR=%d", charId);
    success = ble.sendCommandWithIntReply(command, &reply);
    if (!success)
    {
        error(F("Could not add HRM characteristic"));
    }
    return (int)reply;
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

            Serial.print("Got packet from #");
            Serial.print(from);
            Serial.print(" [RSSI :");
            Serial.print(rf69.lastRssi());
            Serial.print("] Temp: ");
            memcpy((uint8_t *)&waterTemp, buf, 4);
            Serial.print(waterTemp);
            Serial.println();

            // Send a reply back to the originator client
            if (!rf69_manager.sendtoWait(data, sizeof(data), from))
                Serial.println("Sending failed (no ack)");
        }
    }

    loopTime += millis() - lastTime;
    lastTime = millis();
    if (loopTime > 500)
    {
        loopTime = 0;
        digitalWrite(PUMP_RELAY, pumpOn);
        digitalWrite(HEATER_RELAY, heaterOn);
        pumpOn = readData(pcPumpOnCharId);
        heaterOn = readData(pcHeaterOnCharId);
        getAirTemp();
        sendData();
    }

    delay(1);
}
