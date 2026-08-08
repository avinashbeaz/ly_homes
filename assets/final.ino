#include <ESP8266WiFi.h>
#include <WiFiClientSecureBearSSL.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <ESP8266WebServer.h>
#include <LittleFS.h>

// ---------- Config ----------
const char* AP_SSID     = "LY-HOME";   // Hotspot the phone connects to
const char* AP_PASSWORD = "12345678";         // Must be 8+ chars, or "" for open AP
const char* CONFIG_FILE = "/config.json";
const unsigned long STA_CONNECT_TIMEOUT_MS = 15000; // 15s to try joining a network
const unsigned long BOOT_CONNECT_TIMEOUT_MS = 10000; // 10s to try saved creds on boot

ESP8266WebServer server(80);
bool apMode = false;

// ---------- Helpers: load / save / clear credentials ----------

bool loadCredentials(String &ssid, String &password) {
  if (!LittleFS.exists(CONFIG_FILE)) return false;

  File f = LittleFS.open(CONFIG_FILE, "r");
  if (!f) return false;

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  if (err) return false;

  ssid = doc["ssid"].as<String>();
  password = doc["password"].as<String>();
  return ssid.length() > 0;
}

bool saveCredentials(const String &ssid, const String &password) {
  StaticJsonDocument<256> doc;
  doc["ssid"] = ssid;
  doc["password"] = password;

  File f = LittleFS.open(CONFIG_FILE, "w");
  if (!f) return false;
  serializeJson(doc, f);
  f.close();
  return true;
}

void clearCredentials() {
  if (LittleFS.exists(CONFIG_FILE)) {
    LittleFS.remove(CONFIG_FILE);
  }
}

// ---------- CORS (so the Flutter app / a browser can call the API) ----------

void sendCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleOptions() {
  sendCORSHeaders();
  server.send(204);
}

// ---------- Route handlers ----------

void handleScan() {
  sendCORSHeaders();

  int n = WiFi.scanNetworks();
  DynamicJsonDocument doc(2048);
  JsonArray networks = doc.createNestedArray("networks");

  for (int i = 0; i < n; i++) {
    JsonObject net = networks.createNestedObject();
    net["ssid"] = WiFi.SSID(i);
    net["rssi"] = WiFi.RSSI(i);
    net["secure"] = (WiFi.encryptionType(i) != ENC_TYPE_NONE);
  }
  WiFi.scanDelete();

  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleStatus() {
  sendCORSHeaders();

  StaticJsonDocument<256> doc;
  bool connected = (WiFi.status() == WL_CONNECTED);
  doc["mode"] = apMode ? "ap" : "sta";
  doc["connected"] = connected;
  doc["ssid"] = connected ? WiFi.SSID() : "";
  doc["ip"] = connected ? WiFi.localIP().toString() : "";

  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// Attempts to join the given network. Returns true on success.
bool tryConnect(const String &ssid, const String &password) {
  WiFi.mode(WIFI_AP_STA); // keep AP alive while we try, in case it fails
  WiFi.begin(ssid.c_str(), password.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < STA_CONNECT_TIMEOUT_MS) {
    delay(250);
  }
  return WiFi.status() == WL_CONNECTED;
}

void handleConnect() {
  sendCORSHeaders();

  if (server.method() != HTTP_POST) {
    server.send(405, "application/json", "{\"error\":\"POST required\"}");
    return;
  }

  StaticJsonDocument<256> body;
  DeserializationError err = deserializeJson(body, server.arg("plain"));
  if (err || !body.containsKey("ssid")) {
    server.send(400, "application/json", "{\"error\":\"Expected JSON {ssid,password}\"}");
    return;
  }

  String ssid = body["ssid"].as<String>();
  String password = body.containsKey("password") ? body["password"].as<String>() : "";

  bool ok = tryConnect(ssid, password);

  StaticJsonDocument<256> resp;
  resp["success"] = ok;

  if (ok) {
    saveCredentials(ssid, password);
    resp["ip"] = WiFi.localIP().toString();
    resp["message"] = "Connected and credentials saved.";
  } else {
    resp["message"] = "Failed to connect. Check password and try again.";
    // Fall back to AP-only so we don't leave WiFi in a half-joined state.
    WiFi.disconnect();
    WiFi.mode(WIFI_AP);
  }

  String out;
  serializeJson(resp, out);
  server.send(ok ? 200 : 400, "application/json", out);
}

void handleReset() {
  sendCORSHeaders();
  clearCredentials();
  StaticJsonDocument<128> resp;
  resp["success"] = true;
  resp["message"] = "Credentials cleared. Restarting into config mode.";
  String out;
  serializeJson(resp, out);
  server.send(200, "application/json", out);
  delay(500);
  ESP.restart();
}

void handleRoot() {
  sendCORSHeaders();
  server.send(200, "text/plain",
    "ESP8266 WiFi Config API\n"
    "GET  /scan\n"
    "GET  /status\n"
    "POST /connect  {\"ssid\":\"...\",\"password\":\"...\"}\n"
    "POST /reset\n");
}

// ---------- AP + server startup ----------

void startConfigPortal() {
  apMode = true;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  delay(100);
  Serial.print("AP started. Connect to WiFi: ");
  Serial.println(AP_SSID);
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP()); // normally 192.168.4.1
}

void setupServerRoutes() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/scan", HTTP_GET, handleScan);
  server.on("/scan", HTTP_OPTIONS, handleOptions);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/status", HTTP_OPTIONS, handleOptions);
  server.on("/connect", HTTP_POST, handleConnect);
  server.on("/connect", HTTP_OPTIONS, handleOptions);
  server.on("/reset", HTTP_POST, handleReset);
  server.on("/reset", HTTP_OPTIONS, handleOptions);
  server.begin();
  Serial.println("HTTP server started.");
}
const int devicePins[4] = { D1, D2, D3, D4 };
const int NUM_DEVICES = 4;

unsigned long lastPoll = 0;
const unsigned long POLL_INTERVAL_MS = 2000;

void setup() {
  Serial.begin(115200);
  delay(200);
   for (int i = 0; i < NUM_DEVICES; i++) {
    pinMode(devicePins[i], OUTPUT);
    digitalWrite(devicePins[i], LOW);
  }
  

  if (!LittleFS.begin()) {
    Serial.println("LittleFS mount failed, formatting...");
    LittleFS.format();
    LittleFS.begin();
  }

  String savedSsid, savedPassword;
  bool haveCreds = loadCredentials(savedSsid, savedPassword);

  if (haveCreds) {
    Serial.print("Found saved credentials for: ");
    Serial.println(savedSsid);
    WiFi.mode(WIFI_STA);
    WiFi.begin(savedSsid.c_str(), savedPassword.c_str());

    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < BOOT_CONNECT_TIMEOUT_MS) {
      delay(250);
      Serial.print(".");
    }
    Serial.println();
  }

  if (WiFi.status() == WL_CONNECTED) {
    apMode = false;
    Serial.print("Connected! IP address: ");

    Serial.println(WiFi.localIP());
    
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");

Serial.println("Waiting for NTP...");

time_t now = time(nullptr);

while (now < 1000000000) {
  delay(500);
  Serial.print(".");
  now = time(nullptr);
}

Serial.println();
Serial.println("NTP synchronized");
  } else {
    Serial.println("Could not connect with saved credentials (or none saved).");
    startConfigPortal();
  }

  setupServerRoutes();
}

void loop() {
  server.handleClient();

  // If we're in AP+STA mode after a successful /connect call, we can drop
  // the AP once we're confident the STA link is stable. Simple approach:
  // once connected and not in pure AP-only mode, switch to STA-only after
  // a short grace period so the ESP fully joins the home network.
  static unsigned long connectedSince = 0;
  if (WiFi.status() == WL_CONNECTED && WiFi.getMode() == WIFI_AP_STA) {
    if (connectedSince == 0) connectedSince = millis();
    if (millis() - connectedSince > 5000) {
      WiFi.mode(WIFI_STA);
      apMode = false;
      Serial.println("Switched fully to STA mode.");
          configTime(0, 0, "pool.ntp.org", "time.nist.gov");

Serial.println("Waiting for NTP...");

time_t now = time(nullptr);

while (now < 1000000000) {
  delay(500);
  Serial.print(".");
  now = time(nullptr);
}

Serial.println();
Serial.println("NTP synchronized");
       
  
    }
  } else {
    connectedSince = 0;
  }
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastPoll >= POLL_INTERVAL_MS) {
    lastPoll = millis();
    if (WiFi.status() == WL_CONNECTED) {
      pollRoomDevices();
    } else {
      Serial.println("WiFi not connected");
    }
  }

if (millis() - lastHeartbeat >= 10000) { // every 30 seconds
  lastHeartbeat = millis();
  updateLastSeen();
}
}

// ---------------- Firebase ----------------
String projectId = "roseday-5d662";
String apiKey = "AIzaSyC49pQVsdfVxT3-DoS_fPSDfgr3RZMVnF8";


// This ESP8266 controls ONE room. Put that room's Firestore doc ID here.
// (Find it in the Firebase console under the "rooms" collection.)
String roomId = "pX0L7bSHnFAW1Olqgupl";

// ---------------- Relay / device pins ----------------
// Devices are read from Firestore ordered by "name" (same order the Flutter
// app uses), and mapped in that order to these 4 pins.


// Queries rooms/{roomId}/devices ordered by name, and sets each of the
// first NUM_DEVICES devices' "isOn" value onto the matching pin.
void pollRoomDevices() {
  BearSSL::WiFiClientSecure client;
  client.setInsecure();  // NOTE: skips TLS cert validation (fine for a hobby project)

  HTTPClient https;

  String url = "https://firestore.googleapis.com/v1/projects/" + projectId +
               "/databases/(default)/documents/rooms/" + roomId +
               ":runQuery?key=" + apiKey;

  // structuredQuery reproduces: collection('devices').orderBy('name')
  String body =
    "{\"structuredQuery\":{"
    "\"from\":[{\"collectionId\":\"devices\"}],"
    "\"orderBy\":[{\"field\":{\"fieldPath\":\"name\"},\"direction\":\"ASCENDING\"}]"
    "}}";

  https.begin(client, url);
  https.addHeader("Content-Type", "application/json");

  int code = https.POST(body);

  if (code == HTTP_CODE_OK) {
    String payload = https.getString();

    // runQuery returns a JSON array, so give the doc extra room.
    DynamicJsonDocument doc(4096);
    DeserializationError err = deserializeJson(doc, payload);

    if (err) {
      Serial.print("JSON parse failed: ");
      Serial.println(err.c_str());
      https.end();
      return;
    }

    // Start every pin LOW; only turn on pins for devices we actually see
    // and that report isOn == true. Any missing/extra devices just stay off.
    bool desiredState[NUM_DEVICES] = { false, false, false, false };

    int deviceIndex = 0;
    JsonArray arr = doc.as<JsonArray>();
    for (JsonObject entry : arr) {
      if (!entry.containsKey("document")) continue;   // empty-result entries have no "document"
      if (deviceIndex >= NUM_DEVICES) break;

      JsonObject fields = entry["document"]["fields"];
      bool isOn = fields["isOn"]["booleanValue"] | false;
      const char* name = fields["name"]["stringValue"] | "?";

      desiredState[deviceIndex] = isOn;

      Serial.print("Device ");
      Serial.print(deviceIndex + 1);
      Serial.print(" (");
      Serial.print(name);
      Serial.print(") -> ");
      Serial.println(isOn ? "ON" : "OFF");

      deviceIndex++;
    }

    for (int i = 0; i < NUM_DEVICES; i++) {
      digitalWrite(devicePins[i], desiredState[i] ? HIGH : LOW);
    }

  } else {
    Serial.print("runQuery failed, HTTP code: ");
    Serial.println(code);
    Serial.println(https.getString());
  }

  https.end();
}
 

void updateLastSeen() {
  BearSSL::WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;
  time_t now = time(nullptr);

Serial.print("time = ");
Serial.println((unsigned long)now);

  String url = "https://firestore.googleapis.com/v1/projects/" + projectId +
               "/databases/(default)/documents/rooms/" + roomId +
               "?updateMask.fieldPaths=lastSeen&key=" + apiKey;

  uint64_t lastSeen = (uint64_t)time(nullptr) * 1000;
  Serial.print("lastSeen = ");
Serial.println((unsigned long long)lastSeen);

  String body =
      "{\"fields\":{"
      "\"lastSeen\":{\"integerValue\":\"" + String(lastSeen) + "\"}"
      "}}";

  https.begin(client, url);
  https.addHeader("Content-Type", "application/json");

  int code = https.PATCH(body);

  if (code == HTTP_CODE_OK) {
    Serial.println("lastSeen updated");
  } else {
    Serial.print("Failed: ");
    Serial.println(code);
    Serial.println(https.getString());
  }

  https.end();
}

