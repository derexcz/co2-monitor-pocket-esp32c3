/*
  ============================================================================
  Přenosný monitor kvality ovzduší
  ----------------------------------------------------------------------------
  Hardware : ESP32-C3 SuperMini
             OLED 0.96" 128x64 (SSD1306, I2C 0x3C)
             Sensirion SCD41  (CO2, I2C 0x62)
             Bosch BME280     (teplota + vlhkost, I2C 0x76 nebo 0x77)
  Sběrnice : sdílená I2C  ->  SDA = GPIO 8, SCL = GPIO 9

  Knihovny (Arduino IDE -> Správce knihoven / Library Manager):
    1. "Adafruit GFX Library"        (Adafruit)
    2. "Adafruit SSD1306"            (Adafruit)
    3. "Adafruit BME280 Library"     (Adafruit)
    4. "Adafruit Unified Sensor"     (Adafruit)  - závislost BME280
    5. "Sensirion I2C SCD4x"         (Sensirion) - verze 1.x, header SensirionI2cScd4x.h
       (při instalaci potvrď i závislosti: Adafruit BusIO, Sensirion Core)

  Nastavení desky:
    Board: "ESP32C3 Dev Module"  (balíček "esp32" od Espressif Systems)
    USB CDC On Boot: "Enabled"   (jinak nefunguje výpis na Serial Monitor)

  Chování:
    1) Start: "Zahrivani..." + odpočet 30 -> 0 s (SCD41 mezitím už měří).
    2) Hlavní obrazovka: CO2 velkým písmem + "ppm", vlevo dole teplota,
       vpravo dole vlhkost. Obnova při každém novém vzorku SCD41 (~5 s).
    3) Chyby: při selhání inicializace se na displeji vypíše, který senzor
       selhal ("Chyba SCD41" / "Chyba BME280"). Stejné hlášení se zobrazí,
       pokud senzor přestane za běhu odpovídat.
  ============================================================================
*/

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_BME280.h>
#include <SensirionI2cScd4x.h>

// ============================================================================
//  KONFIGURACE
// ============================================================================
constexpr uint8_t  PIN_SDA            = 8;       // I2C data
constexpr uint8_t  PIN_SCL            = 9;       // I2C hodiny

constexpr uint8_t  OLED_WIDTH         = 128;
constexpr uint8_t  OLED_HEIGHT        = 64;
constexpr uint8_t  OLED_ADDR          = 0x3C;    // některé moduly mají 0x3D

constexpr uint32_t WARMUP_MS          = 30000;   // doba zahřívání po startu
constexpr uint32_t POLL_INTERVAL_MS   = 250;     // jak často se ptáme SCD41 "máš data?"
constexpr uint32_t FALLBACK_REDRAW_MS = 5500;    // překreslení, když SCD41 data nedodává
constexpr uint8_t  MAX_READ_FAILS     = 3;       // tolik chyb po sobě = hlášení "Chyba ..."

// true  = po chybě inicializace zůstane na displeji chybová obrazovka (ladění)
// false = chyba se ukáže na 5 s a zařízení pokračuje s tím, co funguje
constexpr bool     HALT_ON_INIT_ERROR = true;

// Korekce teploty z BME280 (°C). Uvnitř krabičky bývá teplota nadsazená
// (baterie, ESP32). Porovnej s kvalitním teploměrem a případně nastav
// např. -1.5f. Vlhkost se touto korekcí NEpřepočítává.
constexpr float    TEMP_OFFSET_C      = 0.0f;

// ============================================================================
//  OBJEKTY A STAV
// ============================================================================
// Poslední dva parametry konstruktoru (clkDuring/clkAfter) nechávám výchozí:
// 400 kHz při zápisu do displeje a po něm zpět 100 kHz pro ostatní senzory.
Adafruit_SSD1306  display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
Adafruit_BME280   bme;
SensirionI2cScd4x scd4x;

bool     scdInitOk  = false;   // proběhla inicializace SCD41 v pořádku?
bool     bmeInitOk  = false;   // proběhla inicializace BME280 v pořádku?
uint8_t  scdFails   = 0;       // počet chyb čtení SCD41 po sobě
uint8_t  bmeFails   = 0;       // počet chyb čtení BME280 po sobě

uint16_t co2ppm       = 0;     // poslední platná hodnota CO2
bool     haveCo2      = false;
float    temperatureC = NAN;   // poslední platná teplota
float    humidityPct  = NAN;   // poslední platná vlhkost
bool     haveBme      = false;

bool     warmupDone      = false;
uint32_t warmupStartMs   = 0;
int32_t  lastShownSecond = -1; // abychom odpočet nepřekreslovali zbytečně
bool     newCo2Sample    = false;
uint32_t lastPollMs      = 0;
uint32_t lastDrawMs      = 0;

// SCD41 nebo BME280 považujeme za vadný, pokud selhala inicializace
// nebo se čtení nepovedlo MAX_READ_FAILS-krát po sobě.
bool scdError() { return !scdInitOk || scdFails >= MAX_READ_FAILS; }
bool bmeError() { return !bmeInitOk || bmeFails >= MAX_READ_FAILS; }

// ============================================================================
//  POMOCNÉ FUNKCE
// ============================================================================

// Vypíše na Serial všechna zařízení nalezená na I2C (pomůcka pro ladění).
void scanI2C() {
  Serial.println(F("I2C scan:"));
  uint8_t found = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  nalezeno zarizeni na 0x%02X\n", addr);
      found++;
    }
  }
  if (found == 0) {
    Serial.println(F("  nic nenalezeno - zkontroluj zapojeni, napajeni a pull-up odpory"));
  }
}

// Vypíše text na vodorovný střed displeje (y = horní okraj textu).
void drawCentered(const char *text, int16_t y, uint8_t textSize) {
  int16_t  x1, y1;
  uint16_t w, h;
  display.setTextSize(textSize);
  display.getTextBounds(text, 0, y, &x1, &y1, &w, &h);
  display.setCursor((OLED_WIDTH - (int16_t)w) / 2, y);
  display.print(text);
}

// ============================================================================
//  INICIALIZACE SENZORŮ
// ============================================================================

// SCD41: probuzení -> stop případného měření -> reinit -> start periodického měření.
// Funkce stopPeriodicMeasurement() slouží zároveň jako test, že senzor odpovídá.
bool initSCD41() {
  char    msg[64];
  int16_t err;

  scd4x.begin(Wire, SCD41_I2C_ADDR_62);

  delay(30);                 // SCD41 po zapnutí napájení potřebuje až 30 ms
  scd4x.wakeUp();            // pokud nespí, nevadí; odpověď ignorujeme
  delay(30);

  err = scd4x.stopPeriodicMeasurement();   // trvá ~0,5 s
  if (err) {
    errorToString(err, msg, sizeof msg);
    Serial.printf("SCD41: stopPeriodicMeasurement selhalo: %s\n", msg);
    return false;
  }

  err = scd4x.reinit();      // čistý stav (načte uživatelské nastavení ze senzoru)
  if (err) {
    errorToString(err, msg, sizeof msg);
    Serial.printf("SCD41: reinit selhalo: %s\n", msg);
    return false;
  }

  err = scd4x.startPeriodicMeasurement();  // nové data každých ~5 s
  if (err) {
    errorToString(err, msg, sizeof msg);
    Serial.printf("SCD41: startPeriodicMeasurement selhalo: %s\n", msg);
    return false;
  }

  Serial.println(F("SCD41: OK, periodicke mereni spusteno"));
  return true;
}

// BME280: zkusí adresu 0x76 a pak 0x77. Používá "forced mode" (měří jen na
// požádání) - méně se tím zahřívá a teplota je přesnější.
bool initBME280() {
  uint8_t usedAddr = 0x76;
  bool ok = bme.begin(0x76, &Wire);
  if (!ok) {
    usedAddr = 0x77;
    ok = bme.begin(0x77, &Wire);
  }
  if (!ok) {
    Serial.printf("BME280: nenalezen na 0x76 ani 0x77 (ID cipu: 0x%02X; "
                  "BME280 = 0x60, BMP280 = 0x56-0x58 - ten vlhkost neumi)\n",
                  (unsigned)bme.sensorID());
    return false;
  }

  bme.setSampling(Adafruit_BME280::MODE_FORCED,
                  Adafruit_BME280::SAMPLING_X1,     // teplota
                  Adafruit_BME280::SAMPLING_NONE,   // tlak (nepotřebujeme)
                  Adafruit_BME280::SAMPLING_X1,     // vlhkost
                  Adafruit_BME280::FILTER_OFF);

  Serial.printf("BME280: OK na adrese 0x%02X\n", usedAddr);
  return true;
}

// ============================================================================
//  ČTENÍ SENZORŮ
// ============================================================================

// Zeptá se SCD41, zda má nový vzorek, a pokud ano, přečte ho.
void pollSCD41() {
  if (!scdInitOk) return;

  char    msg[64];
  bool    ready = false;
  int16_t err   = scd4x.getDataReadyStatus(ready);

  if (err) {
    if (scdFails < 255) scdFails++;
    errorToString(err, msg, sizeof msg);
    Serial.printf("SCD41: getDataReadyStatus chyba: %s\n", msg);
    return;
  }
  if (!ready) return;                      // nový vzorek ještě není

  uint16_t co2;
  float    tScd, rhScd;                    // teplotu a vlhkost ze SCD41 nepoužíváme
  err = scd4x.readMeasurement(co2, tScd, rhScd);

  if (err || co2 == 0) {                   // CO2 = 0 ppm znamená neplatný vzorek
    if (scdFails < 255) scdFails++;
    if (err) {
      errorToString(err, msg, sizeof msg);
      Serial.printf("SCD41: readMeasurement chyba: %s\n", msg);
    }
    return;
  }

  co2ppm       = co2;
  haveCo2      = true;
  scdFails     = 0;
  newCo2Sample = true;
  Serial.printf("CO2: %u ppm\n", co2ppm);
}

// Přečte teplotu a vlhkost z BME280 (jedno vynucené měření).
void readBME280() {
  if (!bmeInitOk) return;

  if (!bme.takeForcedMeasurement()) {
    if (bmeFails < 255) bmeFails++;
    Serial.println(F("BME280: takeForcedMeasurement selhalo"));
    return;
  }

  float t = bme.readTemperature();
  float h = bme.readHumidity();
  if (isnan(t) || isnan(h)) {
    if (bmeFails < 255) bmeFails++;
    Serial.println(F("BME280: neplatna data"));
    return;
  }

  temperatureC = t + TEMP_OFFSET_C;
  humidityPct  = h;
  haveBme      = true;
  bmeFails     = 0;
  Serial.printf("T: %.1f C, RH: %.0f %%\n", temperatureC, humidityPct);
}

// ============================================================================
//  VYKRESLOVÁNÍ
// ============================================================================

// Chybová obrazovka po neúspěšné inicializaci.
void showInitErrors() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);

  display.setCursor(0, 0);
  display.print(F("CHYBA INICIALIZACE"));
  display.drawFastHLine(0, 10, OLED_WIDTH, SSD1306_WHITE);

  display.setCursor(0, 16);
  if (!scdInitOk) display.println(F("Chyba SCD41"));
  if (!bmeInitOk) display.println(F("Chyba BME280"));

  display.setCursor(0, 46);
  display.println(F("Zkontroluj zapojeni"));
  display.print(F("SDA=GPIO8 SCL=GPIO9"));
  display.display();
}

// Úvodní obrazovka: "Zahrivani..." + odpočet + ukazatel průběhu.
void drawWarmup(uint32_t remainingSec, uint32_t elapsedMs) {
  char num[8];
  snprintf(num, sizeof num, "%lu", (unsigned long)remainingSec);

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  drawCentered("Zahrivani...", 2, 1);

  // velké číslo odpočtu + malé "s" vedle něj
  const int numW  = (int)strlen(num) * 6 * 4;       // písmo 4x: 24 px na znak
  const int total = numW + 4 + 12;                  // číslo + mezera + "s" (písmo 2x)
  const int x0    = (OLED_WIDTH - total) / 2;
  display.setTextSize(4);
  display.setCursor(x0, 16);
  display.print(num);
  display.setTextSize(2);
  display.setCursor(x0 + numW + 4, 16 + 32 - 16);
  display.print(F("s"));

  // ukazatel průběhu dole
  display.drawRect(0, 56, OLED_WIDTH, 8, SSD1306_WHITE);
  const int fill = (int)((uint64_t)(OLED_WIDTH - 4) * elapsedMs / WARMUP_MS);
  display.fillRect(2, 58, fill, 4, SSD1306_WHITE);

  display.display();
}

// Hlavní obrazovka.
void drawMain() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // ---------------- CO2 (horní část, y = 0..40) ----------------
  if (scdError()) {
    display.setTextSize(2);
    display.setCursor(0, 4);
    display.print(F("Chyba"));
    display.setCursor(0, 22);
    display.print(F("SCD41"));
  } else {
    char num[8];
    if (haveCo2) snprintf(num, sizeof num, "%u", (unsigned)co2ppm);
    else         snprintf(num, sizeof num, "----");

    const uint8_t size = (strlen(num) <= 4) ? 4 : 3;   // 5 číslic = menší písmo
    const int numW  = (int)strlen(num) * 6 * size;
    const int numH  = 8 * size;
    const int total = numW + 4 + 18;                   // číslo + mezera + "ppm"
    const int x0    = (OLED_WIDTH - total) / 2;
    const int y0    = (40 - numH) / 2;

    display.setTextSize(size);
    display.setCursor(x0, y0);
    display.print(num);

    display.setTextSize(1);                            // "ppm" zarovnané se spodkem čísla
    display.setCursor(x0 + numW + 4, y0 + numH - 8);
    display.print(F("ppm"));
  }

  display.drawFastHLine(0, 43, OLED_WIDTH, SSD1306_WHITE);

  // ---------------- teplota + vlhkost (spodní řádek) ----------------
  if (bmeError()) {
    drawCentered("Chyba BME280", 52, 1);
  } else {
    char tBuf[12], hBuf[12];
    if (haveBme) {
      snprintf(tBuf, sizeof tBuf, "%.1f C", temperatureC);   // např. "23.5 C"
      snprintf(hBuf, sizeof hBuf, "%.0f %%", humidityPct);   // např. "45 %"
    } else {
      snprintf(tBuf, sizeof tBuf, "--.- C");
      snprintf(hBuf, sizeof hBuf, "-- %%");
    }
    const int lenT = (int)strlen(tBuf);
    const int lenH = (int)strlen(hBuf);

    // Písmo 2x se vejde, jen když se obě hodnoty vejdou vedle sebe;
    // jinak (např. "-10.5 C" a "100 %") se přepne na písmo 1x.
    const uint8_t size = ((lenT + lenH) * 12 + 6 <= OLED_WIDTH) ? 2 : 1;
    const int y = (size == 2) ? 47 : 52;

    display.setTextSize(size);
    display.setCursor(0, y);                                  // vlevo dole
    display.print(tBuf);
    display.setCursor(OLED_WIDTH - lenH * 6 * size, y);       // vpravo dole
    display.print(hBuf);
  }

  display.display();
}

// ============================================================================
//  SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println(F("\n=== Monitor kvality ovzdusi ==="));

  Wire.begin(PIN_SDA, PIN_SCL);

  // periphBegin = false -> knihovna znovu nevolá Wire.begin() a nepřepíše naše piny
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR, true, false)) {
    // Displej nefunguje, takže chybu můžeme ukázat jen přes Serial.
    Serial.printf("Chyba OLED: displej na 0x%02X neodpovida\n", OLED_ADDR);
    scanI2C();
    while (true) delay(1000);
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  drawCentered("Inicializace...", 28, 1);
  display.display();

  scdInitOk = initSCD41();
  bmeInitOk = initBME280();

  if (!scdInitOk || !bmeInitOk) {
    scanI2C();
    showInitErrors();
    if (HALT_ON_INIT_ERROR) {
      while (true) delay(1000);
    }
    delay(5000);
  }

  warmupStartMs = millis();
}

// ============================================================================
//  LOOP
// ============================================================================
void loop() {
  const uint32_t now = millis();

  // 1) Pravidelně se ptáme SCD41, zda má nový vzorek.
  if (now - lastPollMs >= POLL_INTERVAL_MS) {
    lastPollMs = now;
    pollSCD41();
  }

  // 2) Fáze zahřívání: odpočet 30 -> 0 s.
  if (!warmupDone) {
    const uint32_t elapsed = now - warmupStartMs;

    if (elapsed >= WARMUP_MS) {
      warmupDone = true;
      readBME280();
      drawMain();
      lastDrawMs   = millis();
      newCo2Sample = false;
    } else {
      const int32_t remaining = (WARMUP_MS - elapsed) / 1000;   // 30 ... 0
      if (remaining != lastShownSecond) {
        lastShownSecond = remaining;
        drawWarmup((uint32_t)remaining, elapsed);
      }
    }
    return;
  }

  // 3) Hlavní obrazovka: překreslit při novém vzorku CO2 (~každých 5 s),
  //    případně záložně, když SCD41 data nedodává (aby se aktualizoval
  //    BME280 a chybová hlášení).
  if (newCo2Sample || (now - lastDrawMs >= FALLBACK_REDRAW_MS)) {
    readBME280();
    drawMain();
    lastDrawMs   = millis();
    newCo2Sample = false;
  }
}
