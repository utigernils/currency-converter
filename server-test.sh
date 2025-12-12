RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Server-Konfiguration
SERVER_PORT=8000
SERVER_URL="http://localhost:${SERVER_PORT}"
SERVER_PID=""
AUTH_HEADER="Authorization: Basic YmFua2VyOmlMaWtlTW9uZXk="

echo "======================================"
echo "Currency Converter Server Tests"
echo "======================================"
echo ""

# Funktion zum Starten des Servers
start_server() {
    echo "Starting server..."
    deno run --allow-net --allow-read src/server.ts &
    SERVER_PID=$!
    
    # Warte, bis Server bereit ist (max 5 Sekunden)
    local retries=10
    while [ $retries -gt 0 ]; do
        if curl -s -o /dev/null -w "%{http_code}" "${SERVER_URL}/rate/usd/eur" > /dev/null 2>&1; then
            echo -e "${GREEN}Server started successfully (PID: ${SERVER_PID})${NC}"
            echo ""
            return 0
        fi
        sleep 0.5
        ((retries--))
    done
    
    echo -e "${RED}Failed to start server${NC}"
    return 1
}

# Funktion zum Stoppen des Servers
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        echo ""
        echo "Stopping server (PID: ${SERVER_PID})..."
        kill "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
        echo -e "${GREEN}Server stopped${NC}"
    fi
}

# Trap für sauberes Aufräumen bei Skript-Ende oder Abbruch
trap stop_server EXIT INT TERM

# Hilfsfunktion zum Testen
test_case() {
    local test_name="$1"
    local expected_status="$2"
    shift 2
    local curl_cmd="$*"

    echo -n "Test: $test_name ... "

    # HTTP-Request ausführen
    local response
    local http_code
    
    response=$(eval "$curl_cmd" 2>&1)
    http_code=$?
    
    # HTTP Status Code extrahieren (letzten 3 Zeichen der Antwort)
    local status_code=$(echo "$response" | tail -c 4 | head -c 3)
    
    # Prüfen, ob der Status-Code dem erwarteten entspricht
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Expected status: $expected_status, got: $status_code"
        echo "  Response: $response"
        ((TESTS_FAILED++))
    fi
}

# Hilfsfunktion zum Testen mit JSON-Validierung
test_json_response() {
    local test_name="$1"
    local expected_status="$2"
    local json_check="$3"
    shift 3
    local curl_cmd="$*"

    echo -n "Test: $test_name ... "

    # HTTP-Request ausführen
    local full_response
    full_response=$(eval "$curl_cmd" 2>&1)
    
    # HTTP Status Code extrahieren (letzten 3 Zeichen der Antwort)
    local status_code=$(echo "$full_response" | tail -c 4 | head -c 3)
    
    # JSON-Body extrahieren (alles außer letzten 3 Zeichen)
    local response_body=$(echo "$full_response" | head -c -4)
    
    # Status-Code prüfen
    if [ "$status_code" != "$expected_status" ]; then
        echo -e "${RED}FAILED${NC}"
        echo "  Expected status: $expected_status, got: $status_code"
        echo "  Response: $full_response"
        ((TESTS_FAILED++))
        return
    fi
    
    # JSON-Validierung (falls angegeben)
    if [ -n "$json_check" ]; then
        local json_result
        json_result=$(echo "$response_body" | jq -r "$json_check" 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$json_result" ] || [ "$json_result" = "null" ]; then
            echo -e "${RED}FAILED${NC}"
            echo "  JSON check failed: $json_check"
            echo "  Response body: $response_body"
            ((TESTS_FAILED++))
            return
        fi
    fi
    
    echo -e "${GREEN}PASSED${NC}"
    ((TESTS_PASSED++))
}

# Server starten
if ! start_server; then
    echo -e "${RED}Cannot run tests without server${NC}"
    exit 1
fi

# Test 1: Hinterlegen eines neuen Wechselkurses
test_case "PUT /rate/usd/eur/0.95 (create new rate)" "201" \
    "curl -s -X PUT -H '${AUTH_HEADER}' -w '%{http_code}' '${SERVER_URL}/rate/usd/eur/0.95'"

# Test 2: Abrufen eines bekannten Wechselkurses
test_json_response "GET /rate/usd/eur (known rate)" "200" ".rate" \
    "curl -s -X GET -w '%{http_code}' '${SERVER_URL}/rate/usd/eur'"

# Test 3: Abrufen eines unbekannten Wechselkurses (Negativtest)
test_case "GET /rate/xxx/yyy (unknown rate)" "404" \
    "curl -s -X GET -w '%{http_code}' '${SERVER_URL}/rate/xxx/yyy'"

# Test 4: Konversion mit einer bekannten Währung
test_json_response "GET /conversion/usd/eur/100 (known currencies)" "200" ".result" \
    "curl -s -X GET -w '%{http_code}' '${SERVER_URL}/conversion/usd/eur/100'"

# Test 5: Konversion in die umgekehrte Richtung
test_json_response "GET /conversion/eur/usd/95 (reverse conversion)" "200" ".result" \
    "curl -s -X GET -w '%{http_code}' '${SERVER_URL}/conversion/eur/usd/95'"

# Test 6: Entfernen eines Wechselkurses
test_case "DELETE /rate/usd/eur (remove rate)" "204" \
    "curl -s -X DELETE -H '${AUTH_HEADER}' -w '%{http_code}' '${SERVER_URL}/rate/usd/eur'"

# Test 7: Konversion für entfernte Währung (Negativtest)
test_case "GET /conversion/usd/eur/100 (after deletion)" "500" \
    "curl -s -X GET -w '%{http_code}' '${SERVER_URL}/conversion/usd/eur/100'"

# Zusammenfassung
echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
echo "======================================"

# Exit-Code bestimmen
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
