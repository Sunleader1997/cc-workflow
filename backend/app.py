from __future__ import annotations

import asyncio
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from typing import AsyncGenerator

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sse_starlette.sse import EventSourceResponse

from models import (
    NodeStatus,
    NodeStatusUpdate,
    Workflow,
    WorkflowCreate,
    WorkflowEdge,
    WorkflowNode,
    WorkflowUpdate,
    Position,
    NodeData,
)

app = FastAPI(title="Claude Code Workflow Orchestrator")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage
workflows: dict[str, Workflow] = {}
# SSE subscribers per workflow: workflow_id -> list of asyncio.Queue
_subscribers: dict[str, list[asyncio.Queue]] = {}
# Global event stream subscribers (all workflow events)
_global_subscribers: list[asyncio.Queue] = []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _broadcast(workflow_id: str, event: str, data: dict):
    """Broadcast an SSE event to all subscribers of a workflow and global subscribers."""
    msg = {"event": event, "data": data}
    for q in _subscribers.get(workflow_id, []):
        await q.put(msg)
    for q in _global_subscribers:
        await q.put(msg)


# --------------- Workflow CRUD ---------------

@app.post("/api/workflows", response_model=Workflow)
async def create_workflow(body: WorkflowCreate):
    wf_id = str(uuid.uuid4())[:8]
    now = _now()
    wf = Workflow(
        id=wf_id,
        title=body.title,
        description=body.description,
        nodes=body.nodes,
        edges=body.edges,
        status="pending_user_confirm",
        created_at=now,
        updated_at=now,
    )
    workflows[wf_id] = wf
    await _broadcast(wf_id, "workflow_created", wf.model_dump())
    return wf


@app.get("/api/workflows", response_model=list[Workflow])
async def list_workflows():
    return list(workflows.values())


@app.get("/api/workflows/{wf_id}", response_model=Workflow)
async def get_workflow(wf_id: str):
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    return workflows[wf_id]


@app.put("/api/workflows/{wf_id}", response_model=Workflow)
async def update_workflow(wf_id: str, body: WorkflowUpdate):
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    wf = workflows[wf_id]
    if body.title is not None:
        wf.title = body.title
    if body.description is not None:
        wf.description = body.description
    if body.nodes is not None:
        wf.nodes = body.nodes
    if body.edges is not None:
        wf.edges = body.edges
    if body.status is not None:
        wf.status = body.status
    wf.updated_at = _now()
    await _broadcast(wf_id, "workflow_updated", wf.model_dump())
    return wf


@app.delete("/api/workflows/{wf_id}")
async def delete_workflow(wf_id: str):
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    del workflows[wf_id]
    _subscribers.pop(wf_id, None)
    return {"ok": True}


# --------------- Confirm / Start ---------------

@app.post("/api/workflows/{wf_id}/confirm")
async def confirm_workflow(wf_id: str):
    """User confirms the workflow, marking it ready to run."""
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    wf = workflows[wf_id]
    wf.status = "confirmed"
    wf.updated_at = _now()
    await _broadcast(wf_id, "workflow_confirmed", wf.model_dump())
    return wf


@app.post("/api/workflows/{wf_id}/start")
async def start_workflow(wf_id: str):
    """Start executing the workflow."""
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    wf = workflows[wf_id]
    wf.status = "running"
    # Reset all nodes to pending
    for node in wf.nodes:
        node.data.status = NodeStatus.PENDING
        node.data.detail = ""
    wf.updated_at = _now()
    await _broadcast(wf_id, "workflow_started", wf.model_dump())
    return wf


# --------------- Node progress update ---------------

@app.post("/api/workflows/{wf_id}/nodes/{node_id}/status")
async def update_node_status(wf_id: str, node_id: str, body: NodeStatusUpdate):
    """Update a node's status (called by Claude Code skill)."""
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    wf = workflows[wf_id]
    target = None
    for node in wf.nodes:
        if node.id == node_id:
            target = node
            break
    if target is None:
        raise HTTPException(404, f"Node {node_id} not found")
    target.data.status = body.status
    target.data.detail = body.detail
    wf.updated_at = _now()
    # Check if all nodes completed
    all_done = all(
        n.data.status in (NodeStatus.COMPLETED, NodeStatus.SKIPPED)
        for n in wf.nodes
    )
    any_failed = any(n.data.status == NodeStatus.FAILED for n in wf.nodes)
    if any_failed:
        wf.status = "failed"
    elif all_done:
        wf.status = "completed"
    await _broadcast(wf_id, "node_status_changed", {
        "workflow_id": wf_id,
        "node_id": node_id,
        "status": body.status.value,
        "detail": body.detail,
        "workflow_status": wf.status,
    })
    return target


# --------------- SSE Streams ---------------

async def _event_generator(queue: asyncio.Queue, cleanup_fn=None) -> AsyncGenerator:
    try:
        while True:
            msg = await queue.get()
            yield {"event": msg["event"], "data": json.dumps(msg["data"])}
    except asyncio.CancelledError:
        pass
    finally:
        if cleanup_fn:
            cleanup_fn()


@app.get("/api/workflows/{wf_id}/events")
async def workflow_events(wf_id: str):
    """SSE stream for a specific workflow."""
    if wf_id not in workflows:
        raise HTTPException(404, "Workflow not found")
    queue: asyncio.Queue = asyncio.Queue()
    _subscribers.setdefault(wf_id, []).append(queue)

    def cleanup():
        if queue in _subscribers.get(wf_id, []):
            _subscribers[wf_id].remove(queue)

    return EventSourceResponse(_event_generator(queue, cleanup))


@app.get("/api/events")
async def global_events():
    """SSE stream for all workflow events."""
    queue: asyncio.Queue = asyncio.Queue()
    _global_subscribers.append(queue)

    def cleanup():
        if queue in _global_subscribers:
            _global_subscribers.remove(queue)

    return EventSourceResponse(_event_generator(queue, cleanup))


# --------------- Health ---------------

@app.get("/api/health")
async def health():
    return {"status": "ok", "workflows": len(workflows)}


# Serve frontend static files when running as PyInstaller bundle
if getattr(sys, 'frozen', False):
    static_dir = os.path.join(sys._MEIPASS, "frontend", "dist")
    if os.path.exists(static_dir):
        app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9800)
