import time
from app import init_db, get_db_connection

def wait_for_db(max_retries=10, delay=3):
    for attempt in range(max_retries):
        try:
            conn = get_db_connection()
            conn.close()
            print("✅ Base de données disponible.")
            return True
        except Exception as e:
            print(f"❌ Tentative {attempt + 1} : DB pas encore dispo, attente {delay}s...")
            time.sleep(delay)
    return False

if __name__ == "__main__":
    if wait_for_db():
        init_db()
        print("✅ Base de données initialisée avec succès.")
    else:
        print("❌ La base de données n'est pas disponible, abandon.")
        exit(1)
