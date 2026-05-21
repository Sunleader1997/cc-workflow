from __future__ import annotations
from enum import Enum
from typing import Optional
from pydantic import BaseModel


class NodeStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"


class Position(BaseModel):
    x: float
    y: float


class NodeData(BaseModel):
    label: str
    description: str = ""
    status: NodeStatus = NodeStatus.PENDING
    detail: str = ""


class WorkflowNode(BaseModel):
    id: str
    type: str = "workflow"
    position: Position
    data: NodeData


class WorkflowEdge(BaseModel):
    id: str
    source: str
    target: str
    animated: bool = True


class Workflow(BaseModel):
    id: str
    title: str
    description: str = ""
    nodes: list[WorkflowNode] = []
    edges: list[WorkflowEdge] = []
    status: str = "pending_user_confirm"  # pending_user_confirm | confirmed | running | completed | failed
    created_at: str = ""
    updated_at: str = ""


class WorkflowCreate(BaseModel):
    title: str
    description: str = ""
    nodes: list[WorkflowNode] = []
    edges: list[WorkflowEdge] = []


class NodeStatusUpdate(BaseModel):
    status: NodeStatus
    detail: str = ""


class WorkflowUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    nodes: Optional[list[WorkflowNode]] = None
    edges: Optional[list[WorkflowEdge]] = None
    status: Optional[str] = None
