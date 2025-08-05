import time
import os
import psycopg2
from app import init_db

def wait_for_db(host, port, user, password, dbname, timeout=60):
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
            print("Tentative : DB pas encore dispo, attente 3s...")
            time.sleep(3)
    print("La base de données n'est pas disponible, abandon.")
    return False

if __name__ == "__main__":
    host = os.getenv("DB_HOST", "db")
    port = int(os.getenv("DB_PORT", 5432))
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASSWORD", "postgres")
    dbname = os.getenv("DB_NAME", "logmeindb")

    if wait_for_db(host, port, user, password, dbname):
        print("Initialisation de la base...")
        init_db()
    else:
        print("Erreur : impossible de se connecter à la base.")
        exit(1)
