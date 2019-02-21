#include <SPI.h>
#include <RH_RF69.h>
#include <RHReliableDatagram.h>

// == RELAY SETUP ==
#define PUMP_RELAY 12
#define HEATER_RELAY 11

// == RADIO SETUP ==
#define RF69_FREQ 915.0

#define MY_ADDRESS 1

#define RFM69_CS 8
#define RFM69_INT 7
#define RFM69_RST 4
#define LED 13

// Singleton instance of the radio driver
RH_RF69 rf69(RFM69_CS, RFM69_INT);

// Class to manage message delivery and receipt, using the driver declared above
RHReliableDatagram rf69_manager(rf69, MY_ADDRESS);

int16_t packetnum = 0; // packet counter, we increment per xmission
float waterDepth = 0;
float waterTemp = 0;

unsigned long loopTime = 0;
unsigned long lastTime;
boolean status = true;

void setup()
{
    Serial.begin(115200);
    setupRelays();
    setupRadio();
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
    pinMode(LED, OUTPUT);
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

    pinMode(LED, OUTPUT);

    Serial.print("RFM69 radio @");
    Serial.print((int)RF69_FREQ);
    Serial.println(" MHz");
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
    if (loopTime > 3000)
    {
        loopTime = 0;
        status = !status;
        digitalWrite(PUMP_RELAY, status);
        digitalWrite(HEATER_RELAY, status);
    }

    delay(1);
}
