#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
from datetime import datetime, timezone

PROJECT_ID = "jalrakshak-fa0ed"
API_KEY = "AIzaSyAMsGZA5ZivEXVp6UZMrcOWLeWoE8rNEPw"
BASE_URL = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

def to_firestore_value(val):
    if isinstance(val, bool):
        return {"booleanValue": val}
    elif isinstance(val, int):
        return {"integerValue": str(val)}
    elif isinstance(val, float):
        return {"doubleValue": val}
    elif isinstance(val, str):
        return {"stringValue": val}
    elif isinstance(val, dict):
        return {"mapValue": {"fields": {k: to_firestore_value(v) for k, v in val.items()}}}
    elif isinstance(val, list):
        return {"arrayValue": {"values": [to_firestore_value(x) for x in val]}}
    elif val is None:
        return {"nullValue": None}
    return {"stringValue": str(val)}

def write_document(collection: str, doc_id: str, data: dict):
    fields = {k: to_firestore_value(v) for k, v in data.items()}
    payload = json.dumps({"fields": fields}).encode("utf-8")
    
    # Use PATCH to write / upsert with document path
    url = f"{BASE_URL}/{collection}/{doc_id}?key={API_KEY}"
    req = urllib.request.Request(url, data=payload, method="PATCH")
    req.add_header("Content-Type", "application/json")
    
    try:
        with urllib.request.urlopen(req) as resp:
            res = json.loads(resp.read().decode())
            print(f"✔ [{collection}] Created/Updated: {doc_id}")
            return res
    except urllib.error.HTTPError as e:
        print(f"✖ Error writing {collection}/{doc_id}: {e.code} - {e.read().decode()}")
        return None

def main():
    now = datetime.now(timezone.utc).isoformat()
    print("=== JalRakshak Firestore Seeder ===")
    print(f"Target Project: {PROJECT_ID}\n")

    # 1. Mission Status
    write_document("mission_status", "current", {
        "project_name": "JalRakshak",
        "system_integrity": "NOMINAL",
        "active_nodes": 12,
        "threat_level": "MONITORING",
        "protocol": "STRATUM_MULTI_AGENT_SYNTHESIS",
        "last_sync": now,
        "created_at": now
    })

    # 2. Tactical Nodes Metadata
    nodes = [
        {"id": "NODE_DHARAVI", "name": "Dharavi", "lat": 19.0402, "lng": 72.8508, "vuln": "CRITICAL", "drainage": 35},
        {"id": "NODE_BKC", "name": "BKC", "lat": 19.0662, "lng": 72.8687, "vuln": "MODERATE", "drainage": 75},
        {"id": "NODE_KURLA", "name": "Kurla", "lat": 19.0726, "lng": 72.8845, "vuln": "SEVERE", "drainage": 28},
        {"id": "NODE_COLABA", "name": "Colaba", "lat": 18.9067, "lng": 72.8147, "vuln": "HIGH", "drainage": 60},
        {"id": "NODE_POWAI", "name": "Powai", "lat": 19.1176, "lng": 72.9060, "vuln": "MODERATE", "drainage": 80},
        {"id": "NODE_ANDHERI", "name": "Andheri", "lat": 19.1136, "lng": 72.8697, "vuln": "HIGH", "drainage": 45},
        {"id": "NODE_BANDRA", "name": "Bandra", "lat": 19.0596, "lng": 72.8295, "vuln": "MODERATE", "drainage": 68},
        {"id": "NODE_DADAR", "name": "Dadar", "lat": 19.0178, "lng": 72.8478, "vuln": "HIGH", "drainage": 40},
        {"id": "NODE_CHEMBUR", "name": "Chembur", "lat": 19.0522, "lng": 72.8994, "vuln": "MODERATE", "drainage": 55},
        {"id": "NODE_GHATKOPAR", "name": "Ghatkopar", "lat": 19.0860, "lng": 72.9090, "vuln": "HIGH", "drainage": 50},
        {"id": "NODE_SION", "name": "Sion", "lat": 19.0434, "lng": 72.8634, "vuln": "SEVERE", "drainage": 30},
        {"id": "NODE_WORLI", "name": "Worli", "lat": 19.0166, "lng": 72.8167, "vuln": "MODERATE", "drainage": 65},
    ]

    for n in nodes:
        write_document("nodes", n["id"], {
            "node_id": n["id"],
            "name": n["name"],
            "latitude": n["lat"],
            "longitude": n["lng"],
            "vulnerability": n["vuln"],
            "drainage_capacity_pct": n["drainage"],
            "status": "OPERATIONAL",
            "updated_at": now
        })

    # 3. Telemetry Documents
    telemetry_data = [
        {"name": "Dharavi", "temp": 28.5, "hum": 88.0, "precip": 45.2, "rain": 14.5, "soil": 0.72, "cloud": 85, "risk": "HIGH"},
        {"name": "BKC", "temp": 29.1, "hum": 79.0, "precip": 18.0, "rain": 4.2, "soil": 0.45, "cloud": 60, "risk": "LOW"},
        {"name": "Kurla", "temp": 27.8, "hum": 92.0, "precip": 62.4, "rain": 26.8, "soil": 0.85, "cloud": 95, "risk": "SEVERE"},
        {"name": "Colaba", "temp": 28.9, "hum": 84.0, "precip": 30.1, "rain": 8.5, "soil": 0.58, "cloud": 70, "risk": "MODERATE"},
        {"name": "Powai", "temp": 28.0, "hum": 76.0, "precip": 12.0, "rain": 2.1, "soil": 0.41, "cloud": 50, "risk": "LOW"},
        {"name": "Andheri", "temp": 28.2, "hum": 86.0, "precip": 38.5, "rain": 11.4, "soil": 0.63, "cloud": 80, "risk": "HIGH"},
        {"name": "Bandra", "temp": 29.0, "hum": 81.0, "precip": 22.0, "rain": 5.0, "soil": 0.52, "cloud": 65, "risk": "LOW"},
        {"name": "Dadar", "temp": 28.3, "hum": 87.0, "precip": 41.0, "rain": 13.0, "soil": 0.67, "cloud": 82, "risk": "HIGH"},
        {"name": "Chembur", "temp": 28.7, "hum": 82.0, "precip": 26.5, "rain": 7.2, "soil": 0.54, "cloud": 68, "risk": "MODERATE"},
        {"name": "Ghatkopar", "temp": 28.4, "hum": 85.0, "precip": 35.0, "rain": 10.5, "soil": 0.61, "cloud": 75, "risk": "HIGH"},
        {"name": "Sion", "temp": 27.9, "hum": 90.0, "precip": 58.0, "rain": 22.0, "soil": 0.81, "cloud": 90, "risk": "SEVERE"},
        {"name": "Worli", "temp": 28.8, "hum": 80.0, "precip": 20.5, "rain": 4.8, "soil": 0.49, "cloud": 62, "risk": "LOW"},
    ]

    for t in telemetry_data:
        write_document("telemetry", t["name"], {
            "location": t["name"],
            "temperature": t["temp"],
            "humidity": t["hum"],
            "precipitation": t["precip"],
            "rain": t["rain"],
            "soil_moisture": t["soil"],
            "cloud_cover": t["cloud"],
            "status": "ACTIVE",
            "risk_level": t["risk"],
            "citizen_report_risk": t["risk"].lower(),
            "citizen_report_confidence": 0.92,
            "citizen_report_time": now,
            "timestamp": now,
            "updated_at": now
        })

    # 4. VERITAS Disaster Intelligence Reports
    veritas_reports = [
        {
            "id": "REP_2026_001",
            "location": "Kurla",
            "type": "Inundation",
            "description": "Water accumulation over 1.5ft observed at Kurla railway underpass. Drainage suction units deploying.",
            "confidence": 0.94,
            "citizen_risk": "severe",
            "sensor_risk": "high",
            "verification_status": "VERIFIED",
            "bmc_notified": True,
            "timestamp": now
        },
        {
            "id": "REP_2026_002",
            "location": "Dharavi",
            "type": "Canal Overflow",
            "description": "Mithi river tributary cresting near 60ft road. Silt barrier engaged.",
            "confidence": 0.91,
            "citizen_risk": "high",
            "sensor_risk": "moderate",
            "verification_status": "VERIFIED",
            "bmc_notified": True,
            "timestamp": now
        },
        {
            "id": "REP_2026_003",
            "location": "Sion",
            "type": "Waterlogging",
            "description": "Traffic flow halted on highway approach due to heavy gutter backflow.",
            "confidence": 0.89,
            "citizen_risk": "severe",
            "sensor_risk": "severe",
            "verification_status": "VERIFIED",
            "bmc_notified": True,
            "timestamp": now
        }
    ]

    for r in veritas_reports:
        write_document("veritas_reports", r["id"], r)
        # Also mirror in reports collection
        write_document("reports", r["id"], {
            "location": r["location"],
            "status": r["verification_status"],
            "description": r["description"],
            "timestamp": r["timestamp"],
            "verified": True
        })

    # 5. Alerts
    alerts = [
        {
            "id": "ALT_2026_001",
            "location": "Kurla",
            "risk": "severe",
            "confidence": 0.94,
            "status": "ACTIVE",
            "source": "VERITAS_CITIZEN",
            "message": "[VERIFIED] Flash flood warning: Kurla underpass inundation. Diverting local transit.",
            "timestamp": now,
            "acknowledged": False
        },
        {
            "id": "ALT_2026_002",
            "location": "Sion",
            "risk": "severe",
            "confidence": 0.89,
            "status": "ACTIVE",
            "source": "STRATUM_MULTI_AGENT",
            "message": "[CRITICAL] Runoff index breached in Sion circle corridor. Emergency response dispatched.",
            "timestamp": now,
            "acknowledged": False
        },
        {
            "id": "ALT_2026_003",
            "location": "Dharavi",
            "risk": "high",
            "confidence": 0.91,
            "status": "ACTIVE",
            "source": "STRATUM_AI",
            "message": "[ADVISORY] Elevated catchment runoff detected. BMC storm-drain alert dispatched.",
            "timestamp": now,
            "acknowledged": True
        }
    ]

    for a in alerts:
        write_document("alerts", a["id"], a)

    print("\n✔ All JalRakshak Firestore collections, documents, and fields populated successfully!")

if __name__ == "__main__":
    main()
