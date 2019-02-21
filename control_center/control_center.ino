// == RELAY SETUP ==
#define PUMP_RELAY 12
#define HEATER_RELAY 11

// == RADIO SETUP ==
#define RF69_FREQ 915.0

#define RFM69_CS 8
#define RFM69_INT 7
#define RFM69_RST 4
#define LED 13

void setup()
{
    // put your setup code here, to run once:
    pinMode(PUMP_RELAY, OUTPUT);
    pinMode(HEATER_RELAY, OUTPUT);
}

void loop()
{
    // put your main code here, to run repeatedly:
    delay(3000);
    digitalWrite(PUMP_RELAY, HIGH);
    delay(3000);
    digitalWrite(HEATER_RELAY, HIGH);
    delay(3000);
    digitalWrite(PUMP_RELAY, LOW);
    delay(3000);
    digitalWrite(HEATER_RELAY, LOW);
}
