from flask import Flask, request, jsonify, render_template_string
import psycopg2
import requests
import os
import json

app = Flask(__name__)

DB_HOST = os.environ.get('DB_HOST', 'db')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME', 'logmeindb')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'postgres')


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )


def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS logs (
            id SERIAL PRIMARY KEY,
            message TEXT NOT NULL,
            level TEXT NOT NULL,
            ip VARCHAR(45),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cur.close()
    conn.close()


def get_client_ip():
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr


def get_geo_location(ip):
    try:
        # Ignore local/Docker IPs
        if ip.startswith('172.') or ip.startswith('127.') or ip == '::1':
            return 'Inconnue'
        resp = requests.get(f"https://ipapi.co/{ip}/json/", timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            city = data.get('city', '')
            country = data.get('country_name', '')
            return f"{city}, {country}" if city or country else 'Inconnue'
        return 'Inconnue'
    except Exception:
        return 'Inconnue'


@app.route('/api/logs', methods=['GET', 'POST'])
def logs():
    if request.method == 'POST':
        data = request.get_json()
        message = data.get('message')
        level = data.get('level', 'INFO')
        ip = get_client_ip()
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO logs (message, level, ip) VALUES (%s, %s, %s)",
            (message, level, ip)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'status': 'success'}), 201
    else:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, message, level, ip, created_at FROM logs ORDER BY created_at DESC"
        )
        logs = cur.fetchall()
        cur.close()
        conn.close()

        logs_list = [
            {
                'id': row[0],
                'message': row[1],
                'level': row[2],
                'ip': row[3],
                'geo': get_geo_location(row[3]),
                'created_at': row[4].isoformat()
            }
            for row in logs
        ]

        if request.args.get('html') == '1':
            table_template = """
            <html>
            <head>
                <title>Logs DB</title>
                <style>
                    body { font-family: Arial, sans-serif; background: #f8f9fb; }
                    table { border-collapse: collapse; width: 90%; margin: 40px auto; }
                    th, td { border: 1px solid #aaa; padding: 8px 12px; }
                    th { background: #232c4d; color: #fff; }
                    tr:nth-child(even) { background: #e3e7f1; }
                    h1 { text-align: center; }
                </style>
            </head>
            <body>
                <h1>Logs en base</h1>
                <table>
                    <tr>
                        <th>ID</th>
                        <th>Date</th>
                        <th>Niveau</th>
                        <th>Message</th>
                        <th>IP</th>
                        <th>Localisation</th>
                    </tr>
                    {% for log in logs %}
                    <tr>
                        <td>{{log.id}}</td>
                        <td>{{log.created_at}}</td>
                        <td>{{log.level}}</td>
                        <td>{{log.message}}</td>
                        <td>{{log.ip}}</td>
                        <td>{{log.geo}}</td>
                    </tr>
                    {% endfor %}
                </table>
            </body>
            </html>
            """
            return render_template_string(table_template, logs=logs_list)
        else:
            return jsonify(logs_list)


@app.route('/api/logs/clear', methods=['DELETE'])
def clear_logs():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM logs")
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'status': 'logs cleared'})


@app.route('/api/stats', methods=['GET'])
def stats():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM logs")
    count = cur.fetchone()[0]
    cur.close()
    conn.close()
    return jsonify({'log_count': count})


def health_response():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        db_ok = (cur.fetchone()[0] == 1)
        cur.close()
        conn.close()
    except Exception:
        db_ok = False

    status = 'ok' if db_ok else 'db_error'
    result = {
        'status': status,
        'backend': 'up',
        'db': db_ok,
        'version': '1.0'
    }

    if request.args.get('html') == '1':
        return render_template_string("""
        <html>
        <head>
            <title>Health Check</title>
            <style>
                body { background: #f9faff; font-family: 'Segoe UI', Arial, sans-serif; color: #222; }
                .health { margin: 40px auto; background: #fff; border-radius: 10px; box-shadow: 0 3px 16px #232c4d13; max-width: 400px; padding: 32px; }
                h1 { text-align: center; color: #232c4d;}
                .status-ok { color: #14b314; font-weight: bold; }
                .status-bad { color: #b32414; font-weight: bold; }
                .line { margin: 10px 0; font-size: 1.15em;}
            </style>
        </head>
        <body>
            <div class="health">
                <h1>Health Check</h1>
                <div class="line">Backend : <span class="status-ok">UP</span></div>
                <div class="line">DB : <span class="{{ 'status-ok' if db else 'status-bad' }}">{{ 'OK' if db else 'DOWN' }}</span></div>
                <div class="line">Status : <b>{{ status }}</b></div>
                <div class="line">Version : <b>{{ version }}</b></div>
            </div>
        </body>
        </html>
        """, db=db_ok, status=status, version=result['version'])
    else:
        return app.response_class(
            response=json.dumps(result, indent=4),
            status=200,
            mimetype='application/json'
        )


@app.route('/api/health', methods=['GET'])
def api_health():
    return health_response()


@app.route('/health', methods=['GET'])
def root_health():
    return health_response()


if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)
