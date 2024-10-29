/*
  Cat Toy Simulator - Serial Output
  Author: David Lee
  Last Modified Date: Oct 16
*/

#define BUTTON_PIN 13
#define LED_PIN 15

int xyzPins[] = {39, 32, 33};   // x, y, z(switch) pins
void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP); // pullup resistor for button
  pinMode(LED_PIN, OUTPUT);           
  pinMode(xyzPins[2], INPUT_PULLUP);  // pullup resistor for joystick
}
void loop() {
  
  int buttonVal = digitalRead(BUTTON_PIN);
  // Sanity check to make sure the button is working
  if (!buttonVal) {
    digitalWrite(LED_PIN, HIGH);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // Joystick Values
  int xVal = analogRead(xyzPins[0]);
  int yVal = analogRead(xyzPins[1]);
  int zVal = digitalRead(xyzPins[2]);

  Serial.printf("%d,%d,%d|%d", xVal, yVal, zVal, buttonVal);
  Serial.println();
  delay(100);
}