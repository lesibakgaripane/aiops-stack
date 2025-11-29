from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging
import psycopg2
from datetime import datetime
import os

app = FastAPI(title="AI-Ops Ecosystem API", version="1.0")

logging.basicConfig(level=logging.INFO)

# --- Database Connection Details ---
DB_HOST = "datalake_db"
DB_NAME = "aiops_data"
DB_USER = "aiops_user"
DB_PASS = "password"

def get_db_connection():
    """Establishes and returns a database connection."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        return conn
    except Exception as error:
        logging.error(f"Database connection error: {error}")
        return None

def init_db():
    """Creates the necessary tables if they do not exist."""
    conn = get_db_connection()
    if not conn:
        logging.error("Skipping DB initialization: Connection not available.")
        return

    try:
        cur = conn.cursor()
        
        # Create table for ONOS metrics
        cur.execute("""
            CREATE TABLE IF NOT EXISTS onos_metrics (
                timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                device_id VARCHAR(255) NOT NULL,
                metric VARCHAR(255) NOT NULL,
                value REAL
            );
        """)
        
        # Create table for Zabbix events
        cur.execute("""
            CREATE TABLE IF NOT EXISTS zabbix_events (
                timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                host VARCHAR(255) NOT NULL,
                item_key VARCHAR(255) NOT NULL,
                value TEXT
            );
        """)

        # Create table for LibreNMS data
        cur.execute("""
            CREATE TABLE IF NOT EXISTS librenms_data (
                timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                hostname VARCHAR(255) NOT NULL,
                mib VARCHAR(255) NOT NULL,
                value TEXT
            );
        """)
        
        conn.commit()
        logging.info("Database tables initialized successfully.")
    except Exception as error:
        conn.rollback()
        logging.error(f"Error initializing tables: {error}")
    finally:
        conn.close()

# Initialize tables when the application starts
init_db()

# --- Data Models (Schemas) ---

class OnosData(BaseModel):
    device_id: str
    metric: str
    value: float

class ZabbixData(BaseModel):
    host: str
    item_key: str
    value: str

class LibrenmsData(BaseModel):
    hostname: str
    mib: str
    value: str

# --- Endpoints for Data Collectors (Modified for DB Insertion) ---

@app.post("/ingest/onos_metrics")
async def ingest_onos_metrics(data: OnosData):
    conn = get_db_connection()
    if not conn: raise HTTPException(status_code=500, detail="Database connection failed")
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO onos_metrics (device_id, metric, value) VALUES (%s, %s, %s)",
            (data.device_id, data.metric, data.value)
        )
        conn.commit()
        logging.info(f"ONOS Data written to DB: {data.device_id}")
    except Exception as error:
        conn.rollback()
        logging.error(f"DB insertion error (ONOS): {error}")
        raise HTTPException(status_code=500, detail="DB insertion failed")
    finally:
        cur.close()
        conn.close()
    return {"status": "received_and_stored", "data": data.dict()}

@app.post("/ingest/zabbix_events")
async def ingest_zabbix_events(data: ZabbixData):
    conn = get_db_connection()
    if not conn: raise HTTPException(status_code=500, detail="Database connection failed")
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO zabbix_events (host, item_key, value) VALUES (%s, %s, %s)",
            (data.host, data.item_key, data.value)
        )
        conn.commit()
        logging.info(f"Zabbix Event written to DB: {data.host} - {data.item_key}")
    except Exception as error:
        conn.rollback()
        logging.error(f"DB insertion error (Zabbix): {error}")
        raise HTTPException(status_code=500, detail="DB insertion failed")
    finally:
        cur.close()
        conn.close()
    return {"status": "received_and_stored", "data": data.dict()}

@app.post("/ingest/librenms_data")
async def ingest_librenms_data(data: LibrenmsData):
    conn = get_db_connection()
    if not conn: raise HTTPException(status_code=500, detail="Database connection failed")
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO librenms_data (hostname, mib, value) VALUES (%s, %s, %s)",
            (data.hostname, data.mib, data.value)
        )
        conn.commit()
        logging.info(f"LibreNMS Data written to DB: {data.hostname}")
    except Exception as error:
        conn.rollback()
        logging.error(f"DB insertion error (LibreNMS): {error}")
        raise HTTPException(status_code=500, detail="DB insertion failed")
    finally:
        cur.close()
        conn.close()
    return {"status": "received_and_stored", "data": data.dict()}

@app.get("/status")
async def get_status():
    return {"status": "ok", "service": "FastAPI Heartbeat (DB Integrated)"}
