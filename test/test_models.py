import pytest
from pydantic import ValidationError
from models import (
    NodeStatus,
    Position,
    NodeData,
    WorkflowNode,
    WorkflowEdge,
    Workflow,
    WorkflowCreate,
    NodeStatusUpdate,
    WorkflowUpdate,
)


class TestNodeStatus:
    def test_node_status_values(self):
        assert NodeStatus.PENDING == "pending"
        assert NodeStatus.IN_PROGRESS == "in_progress"
        assert NodeStatus.COMPLETED == "completed"
        assert NodeStatus.FAILED == "failed"
        assert NodeStatus.SKIPPED == "skipped"

    def test_node_status_is_str_subclass(self):
        assert issubclass(NodeStatus, str)


class TestPosition:
    def test_valid_position(self):
        p = Position(x=100.0, y=200.0)
        assert p.x == 100.0
        assert p.y == 200.0

    def test_position_with_integers(self):
        p = Position(x=0, y=0)
        assert p.x == 0
        assert p.y == 0

    def test_position_with_negative(self):
        p = Position(x=-50.5, y=-100.0)
        assert p.x == -50.5
        assert p.y == -100.0


class TestNodeData:
    def test_default_values(self):
        data = NodeData(label="Test Node")
        assert data.label == "Test Node"
        assert data.description == ""
        assert data.status == NodeStatus.PENDING
        assert data.detail == ""

    def test_custom_values(self):
        data = NodeData(
            label="Build API",
            description="Create REST endpoints",
            status=NodeStatus.IN_PROGRESS,
            detail="Working on auth...",
        )
        assert data.label == "Build API"
        assert data.description == "Create REST endpoints"
        assert data.status == NodeStatus.IN_PROGRESS
        assert data.detail == "Working on auth..."

    def test_invalid_status(self):
        with pytest.raises(ValidationError):
            NodeData(label="Test", status="invalid_status")


class TestWorkflowNode:
    def test_valid_node(self):
        node = WorkflowNode(
            id="n1",
            position=Position(x=250, y=50),
            data=NodeData(label="Step 1"),
        )
        assert node.id == "n1"
        assert node.type == "workflow"
        assert node.position.x == 250
        assert node.data.label == "Step 1"

    def test_missing_id(self):
        with pytest.raises(ValidationError):
            WorkflowNode(
                position=Position(x=0, y=0),
                data=NodeData(label="Test"),
            )


class TestWorkflowEdge:
    def test_valid_edge(self):
        edge = WorkflowEdge(id="e1", source="n1", target="n2")
        assert edge.id == "e1"
        assert edge.source == "n1"
        assert edge.target == "n2"
        assert edge.animated is True

    def test_edge_not_animated(self):
        edge = WorkflowEdge(id="e1", source="n1", target="n2", animated=False)
        assert edge.animated is False


class TestWorkflow:
    def test_default_values(self):
        wf = Workflow(id="abc123", title="Test Workflow")
        assert wf.id == "abc123"
        assert wf.title == "Test Workflow"
        assert wf.description == ""
        assert wf.nodes == []
        assert wf.edges == []
        assert wf.status == "pending_user_confirm"
        assert wf.created_at == ""
        assert wf.updated_at == ""

    def test_workflow_with_nodes_and_edges(self):
        node = WorkflowNode(
            id="n1",
            position=Position(x=250, y=50),
            data=NodeData(label="Step 1"),
        )
        edge = WorkflowEdge(id="e1", source="n1", target="n2")
        wf = Workflow(
            id="abc123",
            title="Test",
            nodes=[node],
            edges=[edge],
        )
        assert len(wf.nodes) == 1
        assert len(wf.edges) == 1
        assert wf.nodes[0].id == "n1"


class TestWorkflowCreate:
    def test_minimal_create(self):
        body = WorkflowCreate(title="New Workflow")
        assert body.title == "New Workflow"
        assert body.description == ""
        assert body.nodes == []
        assert body.edges == []

    def test_full_create(self):
        body = WorkflowCreate(
            title="Full Workflow",
            description="A test workflow",
            nodes=[
                WorkflowNode(
                    id="n1",
                    position=Position(x=0, y=0),
                    data=NodeData(label="Step 1"),
                )
            ],
            edges=[WorkflowEdge(id="e1", source="n1", target="n2")],
        )
        assert body.title == "Full Workflow"
        assert len(body.nodes) == 1
        assert len(body.edges) == 1


class TestNodeStatusUpdate:
    def test_update(self):
        update = NodeStatusUpdate(status=NodeStatus.COMPLETED, detail="Done")
        assert update.status == NodeStatus.COMPLETED
        assert update.detail == "Done"

    def test_default_detail(self):
        update = NodeStatusUpdate(status=NodeStatus.IN_PROGRESS)
        assert update.detail == ""


class TestWorkflowUpdate:
    def test_partial_update(self):
        update = WorkflowUpdate(title="New Title")
        assert update.title == "New Title"
        assert update.description is None
        assert update.nodes is None
        assert update.edges is None
        assert update.status is None

    def test_full_update(self):
        update = WorkflowUpdate(
            title="T",
            description="D",
            nodes=[],
            edges=[],
            status="completed",
        )
        assert update.status == "completed"
