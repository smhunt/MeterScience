#!/usr/bin/env python3
"""
MeterPi - Raspberry Pi Meter Reading System
Automatic utility meter OCR with local storage and API
"""

import os
import time
import json
import sqlite3
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, asdict
from pathlib import Path

import cv2
import numpy as np
from flask import Flask, jsonify, request, Response
from flask_cors import CORS
import paho.mqtt.client as mqtt

# Optional: Use pytesseract or paddle-ocr
try:
    import pytesseract
    OCR_ENGINE = "tesseract"
except ImportError:
    try:
        from paddleocr import PaddleOCR
        ocr_model = PaddleOCR(use_angle_cls=True, lang='en', use_gpu=False)
        OCR_ENGINE = "paddle"
    except ImportError:
        OCR_ENGINE = None
        logging.warning("No OCR engine available!")

# Configuration
CONFIG = {
    "capture_interval_seconds": 60,
    "camera_device": 0,
    "camera_width": 1280,
    "camera_height": 720,
    "db_path": "/home/pi/meterpi/readings.db",
    "log_path": "/home/pi/meterpi/meterpi.log",
    "api_port": 5000,
    "mqtt_enabled": False,
    "mqtt_broker": "localhost",
    "mqtt_port": 1883,
    "mqtt_topic": "meterpi/readings",
    "cloud_sync_enabled": False,
    "cloud_api_url": "https://api.meterscience.io/v1",
    "cloud_api_key": "",
    "meter_type": "electric",
    "expected_digits": 6,
    "min_confidence": 0.7,
    "consensus_frames": 3,
}

# Load config from file if exists
CONFIG_FILE = Path("/home/pi/meterpi/config.json")
if CONFIG_FILE.exists():
    with open(CONFIG_FILE) as f:
        CONFIG.update(json.load(f))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(CONFIG["log_path"]),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class MeterReading:
    """Single meter reading with metadata"""
    reading_id: str
    value: str
    numeric_value: Optional[float]
    confidence: float
    timestamp: str
    image_hash: str
    processing_ms: int
    all_candidates: List[Dict]
    synced: bool = False
    
    def to_dict(self) -> Dict:
        return asdict(self)


class Database:
    """SQLite storage for readings"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._init_db()
    
    def _init_db(self):
        """Create tables if not exist"""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS readings (
                reading_id TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                numeric_value REAL,
                confidence REAL NOT NULL,
                timestamp TEXT NOT NULL,
                image_hash TEXT,
                processing_ms INTEGER,
                all_candidates TEXT,
                synced INTEGER DEFAULT 0
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_timestamp ON readings(timestamp)
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_synced ON readings(synced)
        """)
        conn.commit()
        conn.close()
    
    def save_reading(self, reading: MeterReading):
        """Insert a new reading"""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            INSERT INTO readings 
            (reading_id, value, numeric_value, confidence, timestamp, 
             image_hash, processing_ms, all_candidates, synced)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            reading.reading_id,
            reading.value,
            reading.numeric_value,
            reading.confidence,
            reading.timestamp,
            reading.image_hash,
            reading.processing_ms,
            json.dumps(reading.all_candidates),
            1 if reading.synced else 0
        ))
        conn.commit()
        conn.close()
    
    def get_latest(self) -> Optional[Dict]:
        """Get most recent reading"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.execute("""
            SELECT * FROM readings ORDER BY timestamp DESC LIMIT 1
        """)
        row = cur.fetchone()
        conn.close()
        
        if row:
            return self._row_to_dict(row)
        return None
    
    def get_range(self, from_ts: str, to_ts: str, limit: int = 1000) -> List[Dict]:
        """Get readings in time range"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.execute("""
            SELECT * FROM readings 
            WHERE timestamp >= ? AND timestamp <= ?
            ORDER BY timestamp DESC
            LIMIT ?
        """, (from_ts, to_ts, limit))
        rows = cur.fetchall()
        conn.close()
        
        return [self._row_to_dict(r) for r in rows]
    
    def get_unsynced(self, limit: int = 100) -> List[Dict]:
        """Get readings not yet synced to cloud"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.execute("""
            SELECT * FROM readings WHERE synced = 0
            ORDER BY timestamp ASC LIMIT ?
        """, (limit,))
        rows = cur.fetchall()
        conn.close()
        
        return [self._row_to_dict(r) for r in rows]
    
    def mark_synced(self, reading_ids: List[str]):
        """Mark readings as synced"""
        conn = sqlite3.connect(self.db_path)
        placeholders = ",".join("?" * len(reading_ids))
        conn.execute(f"""
            UPDATE readings SET synced = 1 
            WHERE reading_id IN ({placeholders})
        """, reading_ids)
        conn.commit()
        conn.close()
    
    def get_stats(self) -> Dict:
        """Get aggregate statistics"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        
        # Total readings
        total = conn.execute("SELECT COUNT(*) as count FROM readings").fetchone()["count"]
        
        # First and latest
        first = conn.execute("SELECT timestamp FROM readings ORDER BY timestamp ASC LIMIT 1").fetchone()
        latest = conn.execute("SELECT timestamp FROM readings ORDER BY timestamp DESC LIMIT 1").fetchone()
        
        # Daily usage (last 30 days)
        thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()
        readings_30d = conn.execute("""
            SELECT value, numeric_value, timestamp FROM readings
            WHERE timestamp >= ? AND numeric_value IS NOT NULL
            ORDER BY timestamp ASC
        """, (thirty_days_ago,)).fetchall()
        
        conn.close()
        
        # Calculate usage
        daily_usage = []
        if len(readings_30d) >= 2:
            for i in range(1, len(readings_30d)):
                prev = readings_30d[i-1]
                curr = readings_30d[i]
                if prev["numeric_value"] and curr["numeric_value"]:
                    usage = curr["numeric_value"] - prev["numeric_value"]
                    if usage >= 0:  # Ignore meter resets
                        prev_ts = datetime.fromisoformat(prev["timestamp"].replace("Z", "+00:00"))
                        curr_ts = datetime.fromisoformat(curr["timestamp"].replace("Z", "+00:00"))
                        days = (curr_ts - prev_ts).total_seconds() / 86400
                        if days > 0:
                            daily_usage.append(usage / days)
        
        avg_daily = sum(daily_usage) / len(daily_usage) if daily_usage else 0
        
        # Current month usage
        month_start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0).isoformat()
        
        return {
            "total_readings": total,
            "first_reading": first["timestamp"] if first else None,
            "latest_reading": latest["timestamp"] if latest else None,
            "average_daily_usage": round(avg_daily, 2),
            "readings_last_30_days": len(readings_30d),
        }
    
    def _row_to_dict(self, row: sqlite3.Row) -> Dict:
        """Convert row to dictionary"""
        d = dict(row)
        if d.get("all_candidates"):
            d["all_candidates"] = json.loads(d["all_candidates"])
        d["synced"] = bool(d.get("synced", 0))
        return d


class MeterOCR:
    """OCR processing for meter displays"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.expected_digits = config["expected_digits"]
        self.min_confidence = config["min_confidence"]
    
    def process_frame(self, frame: np.ndarray) -> Optional[Dict]:
        """
        Process a single frame and extract meter reading
        Returns dict with value, confidence, candidates
        """
        start_time = time.time()
        
        # Preprocess
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Enhance contrast
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)
        
        # Threshold
        _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        # OCR
        candidates = self._run_ocr(binary)
        
        # Filter and score candidates
        valid_candidates = []
        for text, confidence, bbox in candidates:
            digits = ''.join(c for c in text if c.isdigit())
            
            # Score based on digit count match
            if len(digits) >= 4:
                score = confidence
                if len(digits) == self.expected_digits:
                    score += 0.2  # Bonus for expected length
                
                valid_candidates.append({
                    "text": text,
                    "digits": digits,
                    "confidence": round(score, 3),
                    "bbox": bbox
                })
        
        # Sort by score
        valid_candidates.sort(key=lambda x: x["confidence"], reverse=True)
        
        processing_ms = int((time.time() - start_time) * 1000)
        
        if valid_candidates:
            best = valid_candidates[0]
            if best["confidence"] >= self.min_confidence:
                return {
                    "value": best["digits"],
                    "confidence": best["confidence"],
                    "candidates": valid_candidates[:5],
                    "processing_ms": processing_ms
                }
        
        return None
    
    def _run_ocr(self, image: np.ndarray) -> List[tuple]:
        """Run OCR engine and return (text, confidence, bbox) tuples"""
        results = []
        
        if OCR_ENGINE == "tesseract":
            # Tesseract
            data = pytesseract.image_to_data(
                image, 
                config='--psm 7 -c tessedit_char_whitelist=0123456789',
                output_type=pytesseract.Output.DICT
            )
            
            for i, text in enumerate(data['text']):
                if text.strip():
                    conf = float(data['conf'][i]) / 100.0
                    bbox = [
                        data['left'][i], data['top'][i],
                        data['width'][i], data['height'][i]
                    ]
                    results.append((text, conf, bbox))
        
        elif OCR_ENGINE == "paddle":
            # PaddleOCR
            ocr_results = ocr_model.ocr(image, cls=True)
            if ocr_results and ocr_results[0]:
                for line in ocr_results[0]:
                    bbox = line[0]
                    text, conf = line[1]
                    results.append((text, conf, bbox))
        
        return results


class MeterCapture:
    """Camera capture and reading orchestration"""
    
    def __init__(self, config: Dict, db: Database, ocr: MeterOCR):
        self.config = config
        self.db = db
        self.ocr = ocr
        self.camera = None
        self.mqtt_client = None
        self.consensus_buffer = []
        
        if config["mqtt_enabled"]:
            self._init_mqtt()
    
    def _init_mqtt(self):
        """Initialize MQTT client"""
        self.mqtt_client = mqtt.Client()
        try:
            self.mqtt_client.connect(
                self.config["mqtt_broker"],
                self.config["mqtt_port"],
                60
            )
            self.mqtt_client.loop_start()
            logger.info(f"Connected to MQTT broker at {self.config['mqtt_broker']}")
        except Exception as e:
            logger.error(f"MQTT connection failed: {e}")
            self.mqtt_client = None
    
    def capture_and_process(self) -> Optional[MeterReading]:
        """Capture frame, process OCR, return reading if valid"""
        
        # Initialize camera if needed
        if self.camera is None:
            self.camera = cv2.VideoCapture(self.config["camera_device"])
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, self.config["camera_width"])
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, self.config["camera_height"])
            time.sleep(1)  # Let camera warm up
        
        # Capture frame
        ret, frame = self.camera.read()
        if not ret:
            logger.error("Failed to capture frame")
            return None
        
        # Process with OCR
        result = self.ocr.process_frame(frame)
        if not result:
            logger.debug("No valid reading detected")
            return None
        
        # Add to consensus buffer
        self.consensus_buffer.append(result["value"])
        if len(self.consensus_buffer) > self.config["consensus_frames"]:
            self.consensus_buffer.pop(0)
        
        # Check consensus
        if len(self.consensus_buffer) >= self.config["consensus_frames"]:
            # All readings must match
            if len(set(self.consensus_buffer)) == 1:
                value = self.consensus_buffer[0]
                
                # Create reading
                reading = MeterReading(
                    reading_id=hashlib.sha256(
                        f"{value}{datetime.utcnow().isoformat()}".encode()
                    ).hexdigest()[:16],
                    value=value,
                    numeric_value=float(value) if value.isdigit() else None,
                    confidence=result["confidence"],
                    timestamp=datetime.utcnow().isoformat() + "Z",
                    image_hash=hashlib.sha256(frame.tobytes()).hexdigest()[:16],
                    processing_ms=result["processing_ms"],
                    all_candidates=result["candidates"]
                )
                
                # Clear consensus buffer
                self.consensus_buffer = []
                
                return reading
        
        return None
    
    def save_and_publish(self, reading: MeterReading):
        """Save reading to DB and publish to MQTT"""
        
        # Save to database
        self.db.save_reading(reading)
        logger.info(f"Saved reading: {reading.value} (conf: {reading.confidence:.2f})")
        
        # Publish to MQTT
        if self.mqtt_client:
            payload = json.dumps(reading.to_dict())
            self.mqtt_client.publish(self.config["mqtt_topic"], payload)
            logger.debug(f"Published to MQTT: {self.config['mqtt_topic']}")
    
    def run_loop(self):
        """Main capture loop"""
        logger.info(f"Starting capture loop (interval: {self.config['capture_interval_seconds']}s)")
        
        while True:
            try:
                reading = self.capture_and_process()
                if reading:
                    self.save_and_publish(reading)
                
                time.sleep(self.config["capture_interval_seconds"])
                
            except KeyboardInterrupt:
                logger.info("Shutting down...")
                break
            except Exception as e:
                logger.error(f"Error in capture loop: {e}")
                time.sleep(5)
        
        if self.camera:
            self.camera.release()
        if self.mqtt_client:
            self.mqtt_client.loop_stop()


# Flask API
app = Flask(__name__)
CORS(app)

db = Database(CONFIG["db_path"])


@app.route('/api/v1/readings/latest', methods=['GET'])
def get_latest():
    """Get most recent reading"""
    reading = db.get_latest()
    if reading:
        return jsonify(reading)
    return jsonify({"error": "No readings available"}), 404


@app.route('/api/v1/readings', methods=['GET'])
def get_readings():
    """Get readings with optional filters"""
    from_ts = request.args.get('from', (datetime.utcnow() - timedelta(days=7)).isoformat())
    to_ts = request.args.get('to', datetime.utcnow().isoformat())
    limit = min(int(request.args.get('limit', 100)), 1000)
    
    readings = db.get_range(from_ts, to_ts, limit)
    return jsonify({
        "readings": readings,
        "count": len(readings),
        "from": from_ts,
        "to": to_ts
    })


@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """Get aggregate statistics"""
    stats = db.get_stats()
    stats["meter_type"] = CONFIG["meter_type"]
    stats["device_id"] = hashlib.sha256(
        open('/etc/machine-id').read().encode()
    ).hexdigest()[:16] if os.path.exists('/etc/machine-id') else "unknown"
    return jsonify(stats)


@app.route('/api/v1/config', methods=['GET'])
def get_config():
    """Get current configuration (sanitized)"""
    safe_config = {k: v for k, v in CONFIG.items() 
                   if 'key' not in k.lower() and 'secret' not in k.lower()}
    return jsonify(safe_config)


@app.route('/api/v1/health', methods=['GET'])
def health():
    """Health check endpoint"""
    latest = db.get_latest()
    return jsonify({
        "status": "healthy",
        "ocr_engine": OCR_ENGINE,
        "latest_reading": latest["timestamp"] if latest else None,
        "uptime": "TODO"
    })


@app.route('/ws/readings')
def ws_readings():
    """WebSocket endpoint for live readings (SSE fallback)"""
    def generate():
        last_id = None
        while True:
            latest = db.get_latest()
            if latest and latest["reading_id"] != last_id:
                last_id = latest["reading_id"]
                yield f"data: {json.dumps(latest)}\n\n"
            time.sleep(1)
    
    return Response(generate(), mimetype='text/event-stream')


def run_api():
    """Run Flask API server"""
    app.run(host='0.0.0.0', port=CONFIG["api_port"], threaded=True)


if __name__ == "__main__":
    import argparse
    import threading
    
    parser = argparse.ArgumentParser(description='MeterPi - Meter Reading System')
    parser.add_argument('--api-only', action='store_true', help='Run API server only')
    parser.add_argument('--capture-only', action='store_true', help='Run capture only')
    args = parser.parse_args()
    
    # Ensure directories exist
    Path(CONFIG["db_path"]).parent.mkdir(parents=True, exist_ok=True)
    Path(CONFIG["log_path"]).parent.mkdir(parents=True, exist_ok=True)
    
    if args.api_only:
        run_api()
    elif args.capture_only:
        ocr = MeterOCR(CONFIG)
        capture = MeterCapture(CONFIG, db, ocr)
        capture.run_loop()
    else:
        # Run both
        api_thread = threading.Thread(target=run_api, daemon=True)
        api_thread.start()
        
        ocr = MeterOCR(CONFIG)
        capture = MeterCapture(CONFIG, db, ocr)
        capture.run_loop()
