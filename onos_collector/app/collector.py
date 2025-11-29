import requests
import time
import json
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Configuration ---
ONOS_URL = "http://192.168.206.136:8181/onos/v1/devices"
FASTAPI_URL = "http://192.168.206.136:8080/ingest/onos_metrics"
ONOS_AUTH = ('karaf', 'karaf')  # Default ONOS credentials
POLL_INTERVAL = 30 # Poll every 30 seconds

def get_onos_device_count():
    """Pulls device data from ONOS and returns the count."""
    try:
        response = requests.get(ONOS_URL, auth=ONOS_AUTH, timeout=10)
        response.raise_for_status()
        devices = response.json().get('devices', [])
        return len(devices)
    except requests.exceptions.RequestException as e:
        logging.error(f"Error connecting to ONOS: {e}")
        return 0

def send_to_fastapi(device_count):
    """Sends collected data to the FastAPI ingestion endpoint."""
    payload = {
        "device_id": "controller_instance",
        "metric": "total_devices",
        "value": float(device_count)
    }
    try:
        response = requests.post(FASTAPI_URL, json=payload, timeout=5)
        response.raise_for_status()
        logging.info(f"Successfully sent {device_count} devices to FastAPI. Status: {response.json().get('status')}")
    except requests.exceptions.RequestException as e:
        logging.error(f"Error sending data to FastAPI: {e}")

if __name__ == "__main__":
    while True:
        count = get_onos_device_count()
        if count >= 0: # Proceed even if count is 0
            send_to_fastapi(count)
        
        logging.info(f"Sleeping for {POLL_INTERVAL} seconds.")
        time.sleep(POLL_INTERVAL)
