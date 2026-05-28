#!/bin/bash
export TERM=xterm

# stty -F /dev/ttyUSB0 2400 raw

configure_mqtt_service() {
    local config="/etc/inverter/mqtt.json"
    local response
    local host
    local port
    local username
    local password
    local clientid
    local tmp

    if [ -z "$SUPERVISOR_TOKEN" ]; then
        echo "SUPERVISOR_TOKEN is not set, using MQTT settings from ${config}"
        return 0
    fi

    response=$(curl -fsS \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        http://supervisor/services/mqtt 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "Could not read Home Assistant MQTT service settings, using ${config}"
        return 0
    fi

    host=$(echo "$response" | jq -r '.data.host // .host // empty')
    port=$(echo "$response" | jq -r '.data.port // .port // 1883')
    username=$(echo "$response" | jq -r '.data.username // .username // empty')
    password=$(echo "$response" | jq -r '.data.password // .password // empty')
    clientid=$(cat "$config" | jq -r '.clientid // "voltronic"')

    if [ -z "$host" ]; then
        echo "Home Assistant MQTT service did not provide a host, using ${config}"
        return 0
    fi

    tmp=$(mktemp)
    jq \
        --arg server "$host" \
        --arg port "$port" \
        --arg username "$username" \
        --arg password "$password" \
        --arg clientid "$clientid" \
        '.server = $server
            | .port = $port
            | .username = $username
            | .password = $password
            | .clientid = $clientid' \
        "$config" > "$tmp" && mv "$tmp" "$config"
}

configure_mqtt_service

# Init the mqtt server for the first time, then every 5 minutes
# This will re-create the auto-created topics in the MQTT server if HA is restarted...

watch -n 300 /opt/inverter-mqtt/mqtt-init.sh > /dev/null 2>&1 &

# Run the MQTT Subscriber process in the background (so that way we can change the configuration on the inverter from home assistant)
/opt/inverter-mqtt/mqtt-subscriber.sh &

# execute exactly every 30 seconds...
watch -n 30 /opt/inverter-mqtt/mqtt-push.sh > /dev/null 2>&1
