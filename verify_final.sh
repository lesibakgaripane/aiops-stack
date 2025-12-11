#!/bin/bash
# Check logins with the working Admin password
URL="http://localhost:8089/auth/login"
PASSWORD="password" 

echo "--- Final Login Verification ---"
for USER in lesiba tumi koki ramo; do
    echo -n "Checking $USER... "
    RESPONSE=$(curl -s -X POST "$URL" -d "username=$USER&password=$PASSWORD")
    
    if echo "$RESPONSE" | grep -q "access_token"; then
        ROLE=$(echo "$RESPONSE" | grep -o '"role":"[^"]*"' | cut -d'"' -f4)
        echo "✅ OK (Role: $ROLE)"
    else
        echo "❌ FAILED"
    fi
done
