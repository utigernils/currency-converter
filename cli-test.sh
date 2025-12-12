RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

echo "======================================"
echo "Currency Converter CLI Tests"
echo "======================================"
echo ""

# Hilfsfunktion zum Testen
test_case() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local cmd="$*"

    echo -n "Test: $test_name ... "

    # Command ausführen, Output in Variable speichern
    local output
    if ! output=$(eval "$cmd" 2>&1); then
        echo -e "${RED}FAILED${NC}"
        echo "  Command failed with exit code $?"
        echo "  Output: $output"
        ((TESTS_FAILED++))
        return
    fi

    # Exakten Match prüfen
    if [ "$output" = "$expected" ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        return
    fi

    # Numerische Vergleichstoleranz (float compare)
    # Vergleich nur, wenn beide Werte numerisch sind
    if [[ "$expected" =~ ^-?[0-9.]+$ && "$output" =~ ^-?[0-9.]+$ ]]; then
        local diff
        diff=$(awk -v a="$expected" -v b="$output" 'BEGIN { print (a-b < 0 ? b-a : a-b) }')

        # Toleranzbar definieren
        local tolerance="0.000001"

        # Prüfen mit Toleranz
        awk -v d="$diff" -v t="$tolerance" 'BEGIN { exit !(d < t) }'
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}PASSED (≈ numeric)${NC}"
            ((TESTS_PASSED++))
            return
        fi
    fi

    # Wenn alles andere nicht passt → FAILED
    echo -e "${RED}FAILED${NC}"
    echo "  Expected: $expected"
    echo "  Got: $output"
    ((TESTS_FAILED++))
}



# Hilfsfunktion für Negativtests (erwarten einen Fehler)
test_case_error() {
    local test_name="$1"
    shift
    local cmd="$@"
    
    echo -n "Test: $test_name ... "
    
    if output=$(eval "$cmd" 2>&1); then
        echo -e "${RED}FAILED${NC}"
        echo "  Expected error but command succeeded"
        echo "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}PASSED${NC} (error expected)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# Test 1: Konversion mit einer bekannten Währung (USD -> CHF)
test_case "USD to CHF conversion" \
    "81" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=usd --to=chf --amount=100"

# Test 2: Konversion mit einer anderen bekannten Währung (EUR -> CHF)
test_case "EUR to CHF conversion" \
    "94" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=eur --to=chf --amount=100"

# Test 3: Konversion in die umgekehrte Richtung (CHF -> GBP)
test_case "CHF to GBP conversion" \
    "46.5" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=chf --to=gbp --amount=50"

# Test 4: Konversion mit unbekannter Währung (Negativtest - GBP -> USD)
test_case_error "Unknown currency pair (GBP to USD)" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=gbp --to=usd --amount=100"

# Test 5: Konversion mit kleinem Betrag
test_case "Small amount conversion (USD to CHF)" \
    "8.1" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=usd --to=chf --amount=10"

# Test 6: Konversion mit Dezimalzahl
test_case "Decimal amount conversion (EUR to CHF)" \
    "47" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=eur --to=chf --amount=50"

# Test 7: Ungültige Währung (Negativtest)
test_case_error "Invalid currency code" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --from=INVALID --to=chf --amount=100"

# Test 8: Fehlende Parameter (Negativtest)
test_case_error "Missing --from parameter" \
    "deno run --allow-read src/cli.ts --rates=exchange-rates.json --to=chf --amount=100"

echo ""
echo "======================================"
echo "Test Results"
echo "======================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
