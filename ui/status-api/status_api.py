from fastapi import FastAPI
import subprocess
import json

app = FastAPI()


@app.get("/health")
async def health():
    return {"status": "ok", "service": "aiops-status-api"}


@app.get("/ecosystem/status")
async def ecosystem_status():
    return {
        "services": [
            {"name": "ui-gateway", "port": 8089},
            {"name": "status-api", "port": 8090},
            {"name": "mariadb-auth", "port": 3307},
        ]
    }


@app.get("/ecosystem/inventory")
async def ecosystem_inventory():
    """
    Returns the JSON from inventory.sh:
    {
      "services": [
        { "name": "...", "image": "...", ... },
        ...
      ]
    }
    """
    out = subprocess.check_output(
        ["bash", "inventory.sh"], stderr=subprocess.DEVNULL
    ).decode()
    return json.loads(out)
