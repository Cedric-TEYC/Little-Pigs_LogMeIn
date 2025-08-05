import time
from app import init_db
import os
import psycopg2

def wait_for_db(host, port, user, password, dbname, timeout=120, retry_interval=3):
    print(f"Attente initiale de 10s avant de tester la DB...")
    time.sleep(10)  # Pause initiale pour laisser le temps à Postgres de démarrer

    start = time.time()
    while time.time() - start < timeout:
        try:
            conn = psycopg2.connect(
                host=host,
                port=port,
                user=user,
                password=password,
                dbname=dbname
            )
            conn.close()
            print("DB is ready.")
            return True
        except psycopg2.OperationalError:
            print(f"Tentative : DB pas encore dispo, attente {retry_interval}s...")
            time.sleep(retry_interval)
    print("La base de données n'est pas disponible, abandon.")
    return False

if __name__ == "__main__":
    host = os.getenv("DB_HOST", "db")
    port = int(os.getenv("DB_PORT", 5432))
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASSWORD", "postgres")
    dbname = os.getenv("DB_NAME", "logmeindb")

    if wait_for_db(host, port, user, password, dbname):
        init_db()
    else:
        exit(1)
