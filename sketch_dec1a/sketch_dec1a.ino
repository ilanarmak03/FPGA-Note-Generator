void setup() {
  Serial.begin(115200);   // USB serial to laptop
}

void loop() {

  if (Serial.available()) {
    Serial.write(Serial.read());
  }
}
