import pytest
from fastapi.testclient import TestClient
from app import app, workflows, _subscribers, _global_subscribers
from models import NodeStatus, WorkflowNode, WorkflowEdge, Position, NodeData


@pytest.fixture(autouse=True)
def reset_state():
    """Reset in-memory state before each test."""
    workflows.clear()
    _subscribers.clear()
    _global_subscribers.clear()
    yield


@pytest.fixture
def client():
    return TestClient(app)


class TestHealth:
    def test_health(self, client):
        response = client.get("/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["workflows"] == 0


class TestCreateWorkflow:
    def test_create_minimal(self, client):
        response = client.post("/api/workflows", json={
            "title": "Test Workflow",
            "description": "A test",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Test Workflow"
        assert data["description"] == "A test"
        assert data["status"] == "pending_user_confirm"
        assert len(data["id"]) == 8
        assert data["nodes"] == []
        assert data["edges"] == []

    def test_create_with_nodes(self, client):
        response = client.post("/api/workflows", json={
            "title": "With Nodes",
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 250, "y": 50},
                    "data": {"label": "Step 1", "description": "First step"},
                }
            ],
            "edges": [],
        })
        assert response.status_code == 200
        data = response.json()
        assert len(data["nodes"]) == 1
        assert data["nodes"][0]["data"]["label"] == "Step 1"


class TestListWorkflows:
    def test_empty_list(self, client):
        response = client.get("/api/workflows")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_after_create(self, client):
        client.post("/api/workflows", json={"title": "WF1"})
        client.post("/api/workflows", json={"title": "WF2"})
        response = client.get("/api/workflows")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        titles = {w["title"] for w in data}
        assert titles == {"WF1", "WF2"}


class TestGetWorkflow:
    def test_get_existing(self, client):
        create_resp = client.post("/api/workflows", json={"title": "Get Me"})
        wf_id = create_resp.json()["id"]
        response = client.get(f"/api/workflows/{wf_id}")
        assert response.status_code == 200
        assert response.json()["title"] == "Get Me"

    def test_get_not_found(self, client):
        response = client.get("/api/workflows/nonexist")
        assert response.status_code == 404


class TestUpdateWorkflow:
    def test_update_title(self, client):
        create_resp = client.post("/api/workflows", json={"title": "Old"})
        wf_id = create_resp.json()["id"]
        response = client.put(f"/api/workflows/{wf_id}", json={"title": "New"})
        assert response.status_code == 200
        assert response.json()["title"] == "New"

    def test_update_nodes(self, client):
        create_resp = client.post("/api/workflows", json={"title": "T"})
        wf_id = create_resp.json()["id"]
        response = client.put(f"/api/workflows/{wf_id}", json={
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 0, "y": 0},
                    "data": {"label": "Updated", "description": ""},
                }
            ]
        })
        assert response.status_code == 200
        assert response.json()["nodes"][0]["data"]["label"] == "Updated"

    def test_update_not_found(self, client):
        response = client.put("/api/workflows/nonexist", json={"title": "X"})
        assert response.status_code == 404


class TestDeleteWorkflow:
    def test_delete_existing(self, client):
        create_resp = client.post("/api/workflows", json={"title": "Delete Me"})
        wf_id = create_resp.json()["id"]
        response = client.delete(f"/api/workflows/{wf_id}")
        assert response.status_code == 200
        assert response.json()["ok"] is True
        assert client.get(f"/api/workflows/{wf_id}").status_code == 404

    def test_delete_not_found(self, client):
        response = client.delete("/api/workflows/nonexist")
        assert response.status_code == 404


class TestConfirmWorkflow:
    def test_confirm(self, client):
        create_resp = client.post("/api/workflows", json={"title": "T"})
        wf_id = create_resp.json()["id"]
        assert create_resp.json()["status"] == "pending_user_confirm"

        response = client.post(f"/api/workflows/{wf_id}/confirm")
        assert response.status_code == 200
        assert response.json()["status"] == "confirmed"

    def test_confirm_not_found(self, client):
        response = client.post("/api/workflows/nonexist/confirm")
        assert response.status_code == 404


class TestStartWorkflow:
    def test_start(self, client):
        create_resp = client.post("/api/workflows", json={
            "title": "T",
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 0, "y": 0},
                    "data": {"label": "S1", "status": "completed"},
                }
            ],
        })
        wf_id = create_resp.json()["id"]
        response = client.post(f"/api/workflows/{wf_id}/start")
        assert response.status_code == 200
        assert response.json()["status"] == "running"
        # Nodes should be reset to pending
        assert response.json()["nodes"][0]["data"]["status"] == "pending"

    def test_start_not_found(self, client):
        response = client.post("/api/workflows/nonexist/start")
        assert response.status_code == 404


class TestUpdateNodeStatus:
    def test_update_status(self, client):
        create_resp = client.post("/api/workflows", json={
            "title": "T",
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 0, "y": 0},
                    "data": {"label": "S1"},
                }
            ],
        })
        wf_id = create_resp.json()["id"]
        response = client.post(
            f"/api/workflows/{wf_id}/nodes/n1/status",
            json={"status": "in_progress", "detail": "Working..."},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["data"]["status"] == "in_progress"
        assert data["data"]["detail"] == "Working..."

    def test_all_nodes_completed(self, client):
        create_resp = client.post("/api/workflows", json={
            "title": "T",
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 0, "y": 0},
                    "data": {"label": "S1"},
                }
            ],
        })
        wf_id = create_resp.json()["id"]
        client.post(
            f"/api/workflows/{wf_id}/nodes/n1/status",
            json={"status": "completed"},
        )
        wf_resp = client.get(f"/api/workflows/{wf_id}")
        assert wf_resp.json()["status"] == "completed"

    def test_any_node_failed(self, client):
        create_resp = client.post("/api/workflows", json={
            "title": "T",
            "nodes": [
                {
                    "id": "n1",
                    "type": "workflow",
                    "position": {"x": 0, "y": 0},
                    "data": {"label": "S1"},
                }
            ],
        })
        wf_id = create_resp.json()["id"]
        client.post(
            f"/api/workflows/{wf_id}/nodes/n1/status",
            json={"status": "failed", "detail": "Error"},
        )
        wf_resp = client.get(f"/api/workflows/{wf_id}")
        assert wf_resp.json()["status"] == "failed"

    def test_node_not_found(self, client):
        create_resp = client.post("/api/workflows", json={"title": "T"})
        wf_id = create_resp.json()["id"]
        response = client.post(
            f"/api/workflows/{wf_id}/nodes/xyz/status",
            json={"status": "completed"},
        )
        assert response.status_code == 404

    def test_workflow_not_found(self, client):
        response = client.post(
            "/api/workflows/nonexist/nodes/n1/status",
            json={"status": "completed"},
        )
        assert response.status_code == 404
