#!/bin/bash
#
# Simple script to register the MQTT topics when the container starts for the first time...

MQTT_SERVER=`cat /etc/inverter/mqtt.json | jq '.server' -r`
MQTT_PORT=`cat /etc/inverter/mqtt.json | jq '.port' -r`
MQTT_TOPIC=`cat /etc/inverter/mqtt.json | jq '.topic' -r`
MQTT_DEVICENAME=`cat /etc/inverter/mqtt.json | jq '.devicename' -r`
MQTT_USERNAME=`cat /etc/inverter/mqtt.json | jq '.username' -r`
MQTT_PASSWORD=`cat /etc/inverter/mqtt.json | jq '.password' -r`
MQTT_CLIENTID=`cat /etc/inverter/mqtt.json | jq '.clientid' -r`

# registerTopic <name> <unit> <icon> [device_class] [state_class]
# device_class/state_class are optional; omitted when empty so Home Assistant
# doesn't complain about a unit/class mismatch on enum or boolean sensors.
registerTopic () {
    local name="$1" unit="$2" icon="$3" device_class="$4" state_class="$5"
    local object_id="${MQTT_DEVICENAME}_${name}"

    local payload="{"
    payload+="\"name\":\"${object_id}\","
    payload+="\"unique_id\":\"${object_id}\","
    payload+="\"state_topic\":\"${MQTT_TOPIC}/sensor/${object_id}\","
    [ -n "$unit" ]         && payload+="\"unit_of_measurement\":\"${unit}\","
    [ -n "$icon" ]         && payload+="\"icon\":\"mdi:${icon}\","
    [ -n "$device_class" ] && payload+="\"device_class\":\"${device_class}\","
    [ -n "$state_class" ]  && payload+="\"state_class\":\"${state_class}\","
    payload+="\"device\":{\"identifiers\":[\"${MQTT_DEVICENAME}\"],\"name\":\"Voltronic Inverter\",\"manufacturer\":\"Voltronic\",\"model\":\"Axpert\"}"
    payload+="}"

    mosquitto_pub \
        -h $MQTT_SERVER \
        -p $MQTT_PORT \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i $MQTT_CLIENTID \
        -t "$MQTT_TOPIC/sensor/${object_id}/config" \
        -m "$payload"
}

registerInverterRawCMD () {
    mosquitto_pub \
        -h $MQTT_SERVER \
        -p $MQTT_PORT \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -i $MQTT_CLIENTID \
        -t "$MQTT_TOPIC/sensor/$MQTT_DEVICENAME/config" \
        -m "{
            \"name\": \""$MQTT_DEVICENAME"\",
            \"state_topic\": \"$MQTT_TOPIC/sensor/$MQTT_DEVICENAME\"
        }"
}

# Live measurements get device_class + state_class "measurement".
# Setpoints (config voltages/currents) get a device_class but no state_class (no long-term stats).
# Enum/boolean/mode topics get neither, only an icon.
registerTopic "Inverter_mode" "" "solar-power" "" "" # 1 = Power_On, 2 = Standby, 3 = Line, 4 = Battery, 5 = Fault, 6 = Power_Saving, 7 = Unknown
registerTopic "AC_grid_voltage" "V" "power-plug" "voltage" "measurement"
registerTopic "AC_grid_frequency" "Hz" "current-ac" "frequency" "measurement"
registerTopic "AC_out_voltage" "V" "power-plug" "voltage" "measurement"
registerTopic "AC_out_frequency" "Hz" "current-ac" "frequency" "measurement"
registerTopic "PV_in_voltage" "V" "solar-panel-large" "voltage" "measurement"
registerTopic "PV_in_current" "A" "solar-panel-large" "current" "measurement"
registerTopic "PV_in_watts" "W" "solar-panel-large" "power" "measurement"
registerTopic "PV_in_watthour" "Wh" "solar-panel-large" "" ""
registerTopic "PV_total_watthour" "Wh" "solar-panel-large" "energy" "total_increasing"
registerTopic "SCC_voltage" "V" "current-dc" "voltage" "measurement"
registerTopic "Load_pct" "%" "brightness-percent" "" "measurement"
registerTopic "Load_watt" "W" "chart-bell-curve" "power" "measurement"
registerTopic "Load_watthour" "Wh" "chart-bell-curve" "" ""
registerTopic "Load_total_watthour" "Wh" "chart-bell-curve" "energy" "total_increasing"
registerTopic "Load_va" "VA" "chart-bell-curve" "apparent_power" "measurement"
registerTopic "Bus_voltage" "V" "details" "voltage" "measurement"
registerTopic "Heatsink_temperature" "°C" "details" "temperature" "measurement"
registerTopic "Battery_capacity" "%" "battery-outline" "battery" "measurement"
registerTopic "Battery_voltage" "V" "battery-outline" "voltage" "measurement"
registerTopic "Battery_charge_current" "A" "current-dc" "current" "measurement"
registerTopic "Battery_discharge_current" "A" "current-dc" "current" "measurement"
registerTopic "Battery_charge_watt" "W" "battery-charging" "power" "measurement"
registerTopic "Battery_discharge_watt" "W" "battery-arrow-down" "power" "measurement"
registerTopic "Load_status_on" "" "power" "" ""
registerTopic "SCC_charge_on" "" "power" "" ""
registerTopic "AC_charge_on" "" "power" "" ""
registerTopic "Battery_recharge_voltage" "V" "current-dc" "voltage" ""
registerTopic "Battery_under_voltage" "V" "current-dc" "voltage" ""
registerTopic "Battery_bulk_voltage" "V" "current-dc" "voltage" ""
registerTopic "Battery_float_voltage" "V" "current-dc" "voltage" ""
registerTopic "Max_grid_charge_current" "A" "current-ac" "current" ""
registerTopic "Max_charge_current" "A" "current-ac" "current" ""
registerTopic "Out_source_priority" "" "grid" "" ""
registerTopic "Charger_source_priority" "" "solar-power" "" ""
registerTopic "Battery_redischarge_voltage" "V" "battery-negative" "voltage" ""

# Add in a separate topic so we can send raw commands from assistant back to the inverter via MQTT (such as changing power modes etc)...
registerInverterRawCMD
