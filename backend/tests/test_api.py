import pytest
import json
from app import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_health_endpoint(client):
    response = client.get('/api/health')
    assert response.status_code == 200
    data = response.get_json()
    assert 'status' in data
    assert data['backend'] == 'up'

def test_get_logs(client):
    response = client.get('/api/logs')
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)

def test_post_log(client):
    payload = {
        'message': 'Test log message',
        'level': 'INFO'
    }
    response = client.post('/api/logs', data=json.dumps(payload), content_type='application/json')
    assert response.status_code == 201
    data = response.get_json()
    assert data['status'] == 'success'

def test_stats_endpoint(client):
    response = client.get('/api/stats')
    assert response.status_code == 200
    data = response.get_json()
    assert 'log_count' in data
    assert isinstance(data['log_count'], int)
