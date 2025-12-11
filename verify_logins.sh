#!/bin/bash

# API Endpoint
URL="http://localhost:8089/auth/login"

# The password that currently works for Lesiba
# (Assuming it's the admin password you used. Update this if it's different)
PASSWORD="password" 

echo "---------------------------------------------------"
echo "Testing Logins with password: '$PASSWORD'"
echo "---------------------------------------------------"

for USER in lesiba tumi koki ramo; do
    echo -n "Testing user: $USER ... "
    
    # Send login request
    RESPONSE=$(curl -s -X POST "$URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$USER&password=$PASSWORD")

    # Check for Access Token
    if echo "$RESPONSE" | grep -q "access_token"; then
        ROLE=$(echo "$RESPONSE" | grep -o '"role":"[^"]*"' | cut -d'"' -f4)
        echo "✅ SUCCESS"
        echo "   -> Assigned Role: $ROLE"
        
        # Verify Redirection Target
        case $ROLE in
            "SUPER_ADMIN") echo "   -> Redirects to: superadmin.html" ;;
            "ADMIN")       echo "   -> Redirects to: admin.html" ;;
            "SUPER_USER")  echo "   -> Redirects to: superuser.html" ;;
            "END_USER")    echo "   -> Redirects to: enduser.html" ;;
            *)             echo "   -> WARNING: Unknown role redirection" ;;
        esac
    else
        echo "❌ FAILED"
        echo "   -> Response: $RESPONSE"
    fi
    echo "---------------------------------------------------"
done
