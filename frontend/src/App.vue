<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { VueFlow, useVueFlow } from '@vue-flow/core'
import { Background } from '@vue-flow/background'
import { Controls } from '@vue-flow/controls'
import { MiniMap } from '@vue-flow/minimap'
import WorkflowNode from './components/WorkflowNode.vue'

const API = `${window.location.protocol}//${window.location.host}/api`

// State
const workflows = ref([])
const currentWf = ref(null)
const nodes = ref([])
const edges = ref([])
const sidebarOpen = ref(true)
const sseConnection = ref(null)
const statusMessage = ref('')
const editingTitle = ref(false)

// Node editing
const editingNode = ref(null)
const editLabel = ref('')
const editDescription = ref('')

const { onConnect, addEdges, onNodesChange, onEdgesChange, removeNodes, removeEdges, fitView } = useVueFlow()

// --- API helpers ---
async function api(path, opts = {}) {
  const res = await fetch(`${API}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...opts,
  })
  if (!res.ok) throw new Error(`API error: ${res.status}`)
  return res.json()
}

// --- Load workflows ---
async function loadWorkflows() {
  workflows.value = await api('/workflows')
}

async function selectWorkflow(wf) {
  currentWf.value = wf
  nodes.value = wf.nodes.map(n => ({
    id: n.id,
    type: 'workflow',
    position: { x: n.position.x, y: n.position.y },
    data: { ...n.data },
  }))
  edges.value = wf.edges.map(e => ({
    id: e.id,
    source: e.source,
    target: e.target,
    animated: e.animated !== false,
  }))
  await nextTick()
  setTimeout(() => fitView({ padding: 0.2 }), 100)
  connectSSE(wf.id)
}

// --- SSE ---
function connectSSE(wfId) {
  if (sseConnection.value) {
    sseConnection.value.close()
  }
  const es = new EventSource(`${API}/workflows/${wfId}/events`)
  sseConnection.value = es
  console.log('[SSE] Connecting to workflow:', wfId)

  es.onopen = () => console.log('[SSE] Connection opened')

  es.addEventListener('node_status_changed', (e) => {
    const data = JSON.parse(e.data)
    console.log('[SSE] node_status_changed:', data)
    // Update nodes array with new reference to trigger reactivity
    nodes.value = nodes.value.map(n => {
      if (n.id === data.node_id) {
        return {
          ...n,
          data: { ...n.data, status: data.status, detail: data.detail }
        }
      }
      return n
    })
    if (currentWf.value) {
      currentWf.value.status = data.workflow_status
    }
  })

  es.addEventListener('workflow_updated', (e) => {
    const data = JSON.parse(e.data)
    if (currentWf.value?.id === data.id) {
      currentWf.value = data
    }
  })

  es.addEventListener('workflow_confirmed', (e) => {
    const data = JSON.parse(e.data)
    console.log('[SSE] workflow_confirmed:', data)
    if (currentWf.value?.id === data.id) {
      currentWf.value.status = 'confirmed'
    }
  })

  es.addEventListener('workflow_started', (e) => {
    const data = JSON.parse(e.data)
    console.log('[SSE] workflow_started:', data)
    if (currentWf.value?.id === data.id) {
      currentWf.value.status = 'running'
      // Refresh nodes
      nodes.value = data.nodes.map(n => ({
        id: n.id,
        type: 'workflow',
        position: { x: n.position.x, y: n.position.y },
        data: { ...n.data },
      }))
    }
  })

  es.onerror = (err) => {
    console.error('[SSE] Connection error, reconnecting...', err)
    setTimeout(() => {
      if (currentWf.value?.id === wfId) connectSSE(wfId)
    }, 3000)
  }
}

// --- Actions ---
async function confirmWorkflow() {
  if (!currentWf.value) return
  await api(`/workflows/${currentWf.value.id}/confirm`, { method: 'POST' })
  currentWf.value.status = 'confirmed'
  statusMessage.value = 'Workflow confirmed. Claude Code can now start.'
  setTimeout(() => statusMessage.value = '', 3000)
}

async function saveWorkflow() {
  if (!currentWf.value) return
  const payload = {
    title: currentWf.value.title,
    description: currentWf.value.description,
    nodes: nodes.value.map(n => ({
      id: n.id,
      type: 'workflow',
      position: n.position,
      data: n.data,
    })),
    edges: edges.value.map(e => ({
      id: e.id,
      source: e.source,
      target: e.target,
      animated: e.animated,
    })),
  }
  await api(`/workflows/${currentWf.value.id}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  })
  statusMessage.value = 'Workflow saved.'
  setTimeout(() => statusMessage.value = '', 2000)
}

async function deleteWorkflow(wfId) {
  await api(`/workflows/${wfId}`, { method: 'DELETE' })
  if (currentWf.value?.id === wfId) {
    currentWf.value = null
    nodes.value = []
    edges.value = []
    if (sseConnection.value) sseConnection.value.close()
  }
  await loadWorkflows()
}

function openEditNode(node) {
  editingNode.value = node
  editLabel.value = node.data?.label || ''
  editDescription.value = node.data?.description || ''
}

function saveEditNode() {
  if (!editingNode.value) return
  const node = nodes.value.find(n => n.id === editingNode.value.id)
  if (node) {
    node.data = { ...node.data, label: editLabel.value, description: editDescription.value }
    // Trigger reactivity by creating new array reference
    nodes.value = nodes.value.map(n => n.id === node.id ? { ...node } : n)
  }
  editingNode.value = null
  editLabel.value = ''
  editDescription.value = ''
}

function cancelEditNode() {
  editingNode.value = null
  editLabel.value = ''
  editDescription.value = ''
}

function addNode() {
  const id = `node_${Date.now()}`
  const lastNode = nodes.value[nodes.value.length - 1]
  const x = lastNode ? lastNode.position.x + 200 : 50
  const y = lastNode ? lastNode.position.y : 200
  nodes.value.push({
    id,
    type: 'workflow',
    position: { x, y },
    data: { label: 'New Task', description: '', status: 'pending', detail: '' },
  })
}

function removeSelectedNodes() {
  const selected = nodes.value.filter(n => n.selected)
  if (selected.length) {
    removeNodes(selected.map(n => n.id))
    // Also remove connected edges
    const nodeIds = new Set(selected.map(n => n.id))
    edges.value = edges.value.filter(e => !nodeIds.has(e.source) && !nodeIds.has(e.target))
  }
}

onConnect((params) => {
  addEdges([{
    id: `e_${params.source}_${params.target}`,
    source: params.source,
    target: params.target,
    animated: true,
  }])
})

onNodesChange((changes) => {
  for (const change of changes) {
    if (change.type === 'remove') {
      nodes.value = nodes.value.filter(n => n.id !== change.id)
      edges.value = edges.value.filter(e => e.source !== change.id && e.target !== change.id)
    }
    if (change.type === 'position' && change.position) {
      const node = nodes.value.find(n => n.id === change.id)
      if (node) node.position = change.position
    }
  }
})

onEdgesChange((changes) => {
  for (const change of changes) {
    if (change.type === 'remove') {
      edges.value = edges.value.filter(e => e.id !== change.id)
    }
  }
})

// --- Polling for new workflows ---
let pollTimer = null
onMounted(() => {
  loadWorkflows()
  pollTimer = setInterval(loadWorkflows, 5000)
})
onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
  if (sseConnection.value) sseConnection.value.close()
})
</script>

<template>
  <div class="app-layout">
    <!-- Sidebar -->
    <aside class="sidebar" :class="{ collapsed: !sidebarOpen }">
      <div class="sidebar-header">
        <h2 v-if="sidebarOpen">Workflows</h2>
        <button class="toggle-btn" @click="sidebarOpen = !sidebarOpen">
          {{ sidebarOpen ? '◀' : '▶' }}
        </button>
      </div>
      <div v-if="sidebarOpen" class="sidebar-content">
        <div class="wf-list">
          <div
            v-for="wf in workflows"
            :key="wf.id"
            class="wf-item"
            :class="{ active: currentWf?.id === wf.id }"
            @click="selectWorkflow(wf)"
          >
            <div class="wf-item-header">
              <span class="wf-title">{{ wf.title }}</span>
              <button class="del-btn" @click.stop="deleteWorkflow(wf.id)" title="Delete">×</button>
            </div>
            <div class="wf-meta">
              <span class="wf-status" :class="`st-${wf.status}`">{{ wf.status }}</span>
              <span class="wf-count">{{ wf.nodes.length }} nodes</span>
            </div>
          </div>
          <div v-if="!workflows.length" class="empty-msg">
            No workflows yet.<br/>Claude Code will create one when you start a task.
          </div>
        </div>
      </div>
    </aside>

    <!-- Main -->
    <main class="main-area">
      <!-- Toolbar -->
      <div v-if="currentWf" class="toolbar">
        <div class="toolbar-left">
          <input
            v-if="editingTitle"
            v-model="currentWf.title"
            class="title-input"
            @blur="editingTitle = false"
            @keydown.enter="editingTitle = false"
            autofocus
          />
          <h3 v-else class="wf-heading" @click="editingTitle = true">
            {{ currentWf.title }}
          </h3>
          <span class="status-badge" :class="`st-${currentWf.status}`">
            {{ currentWf.status }}
          </span>
        </div>
        <div class="toolbar-right">
          <button class="btn btn-secondary" @click="addNode">+ Add Node</button>
          <button class="btn btn-secondary" @click="removeSelectedNodes">Remove Selected</button>
          <button class="btn btn-secondary" @click="saveWorkflow">Save</button>
          <button
            v-if="currentWf.status === 'pending_user_confirm'"
            class="btn btn-primary"
            @click="confirmWorkflow"
          >
            Confirm Workflow
          </button>
        </div>
      </div>

      <!-- Status message -->
      <div v-if="statusMessage" class="status-msg">{{ statusMessage }}</div>

      <!-- Vue Flow -->
      <div v-if="currentWf" class="flow-container">
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :default-edge-options="{ animated: true }"
          :snap-to-grid="true"
          :snap-grid="[15, 15]"
          fit-view-on-init
        >
          <template #node-workflow="nodeProps">
            <div @dblclick="openEditNode(nodeProps)">
              <WorkflowNode :data="nodeProps.data" />
            </div>
          </template>
          <Background :gap="20" :size="1" />
          <Controls />
          <MiniMap />
        </VueFlow>
      </div>

      <!-- Node edit modal -->
      <div v-if="editingNode" class="modal-overlay" @click.self="cancelEditNode">
        <div class="modal-content">
          <h3>Edit Node</h3>
          <div class="form-group">
            <label>Label</label>
            <input v-model="editLabel" class="form-input" placeholder="Node label" @keydown.enter="saveEditNode" />
          </div>
          <div class="form-group">
            <label>Description</label>
            <textarea v-model="editDescription" class="form-input" rows="3" placeholder="What this step does"></textarea>
          </div>
          <div class="modal-actions">
            <button class="btn btn-secondary" @click="cancelEditNode">Cancel</button>
            <button class="btn btn-primary" @click="saveEditNode">Save</button>
          </div>
        </div>
      </div>

      <!-- Empty state -->
      <div v-if="!currentWf" class="empty-state">
        <div class="empty-icon">🔗</div>
        <h2>Claude Code Workflow Orchestrator</h2>
        <p>Start a task in Claude Code and a workflow will appear here automatically.</p>
        <p class="hint">Claude Code will orchestrate the task steps, and you can review and modify the workflow before execution.</p>
      </div>
    </main>
  </div>
</template>

<style>
/* Reset & global */
:root {
  --bg-primary: #11111b;
  --bg-secondary: #181825;
  --bg-surface: #1e1e2e;
  --text-primary: #cdd6f4;
  --text-secondary: #a6adc8;
  --border: #313244;
  --accent: #89b4fa;
  --success: #a6e3a1;
  --warning: #f9e2af;
  --danger: #f38ba8;
}

.vue-flow__minimap {
  background: var(--bg-secondary) !important;
}

.vue-flow__controls {
  background: var(--bg-surface) !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
}

.vue-flow__controls button {
  background: var(--bg-surface) !important;
  color: var(--text-primary) !important;
  border-bottom-color: var(--border) !important;
}

.vue-flow__edge-path {
  stroke: var(--accent) !important;
  stroke-width: 2px !important;
}

.vue-flow__handle {
  width: 10px !important;
  height: 10px !important;
  background: var(--accent) !important;
  border: 2px solid var(--bg-primary) !important;
}
</style>

<style scoped>
.app-layout {
  display: flex;
  width: 100%;
  height: 100vh;
  background: var(--bg-primary);
  color: var(--text-primary);
}

/* Sidebar */
.sidebar {
  width: 280px;
  min-width: 280px;
  background: var(--bg-secondary);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  transition: width 0.2s, min-width 0.2s;
}
.sidebar.collapsed {
  width: 44px;
  min-width: 44px;
}
.sidebar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border);
}
.sidebar-header h2 {
  font-size: 16px;
  font-weight: 600;
}
.toggle-btn {
  background: none;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 14px;
  padding: 4px 8px;
}
.sidebar-content {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}
.wf-list { display: flex; flex-direction: column; gap: 6px; }
.wf-item {
  padding: 10px 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  cursor: pointer;
  transition: border-color 0.2s;
}
.wf-item:hover { border-color: var(--accent); }
.wf-item.active { border-color: var(--accent); background: rgba(137,180,250,0.08); }
.wf-item-header { display: flex; justify-content: space-between; align-items: center; }
.wf-title { font-weight: 600; font-size: 14px; }
.del-btn {
  background: none; border: none; color: var(--danger);
  cursor: pointer; font-size: 18px; padding: 0 4px; opacity: 0.6;
}
.del-btn:hover { opacity: 1; }
.wf-meta { display: flex; gap: 8px; margin-top: 6px; font-size: 12px; color: var(--text-secondary); }
.wf-status {
  padding: 1px 8px; border-radius: 4px; font-size: 11px; font-weight: 500;
}
.st-pending_user_confirm { background: rgba(249,226,175,0.15); color: var(--warning); }
.st-confirmed { background: rgba(137,180,250,0.15); color: var(--accent); }
.st-running { background: rgba(137,180,250,0.2); color: var(--accent); }
.st-completed { background: rgba(166,227,161,0.15); color: var(--success); }
.st-failed { background: rgba(243,139,168,0.15); color: var(--danger); }
.wf-count { color: var(--text-secondary); }
.empty-msg { text-align: center; padding: 24px; color: var(--text-secondary); font-size: 13px; line-height: 1.6; }

/* Main */
.main-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Toolbar */
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 20px;
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border);
  gap: 16px;
  flex-wrap: wrap;
}
.toolbar-left { display: flex; align-items: center; gap: 12px; }
.toolbar-right { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.wf-heading {
  font-size: 18px; font-weight: 700; cursor: pointer;
}
.wf-heading:hover { color: var(--accent); }
.title-input {
  font-size: 18px; font-weight: 700; background: var(--bg-surface);
  border: 1px solid var(--accent); border-radius: 6px; padding: 4px 8px;
  color: var(--text-primary); outline: none;
}
.status-badge {
  padding: 2px 10px; border-radius: 12px; font-size: 12px; font-weight: 600;
}

.btn {
  padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 500;
  cursor: pointer; border: 1px solid var(--border); transition: all 0.15s;
}
.btn-primary {
  background: var(--accent); color: var(--bg-primary); border-color: var(--accent);
}
.btn-primary:hover { filter: brightness(1.1); }
.btn-secondary {
  background: var(--bg-surface); color: var(--text-primary);
}
.btn-secondary:hover { border-color: var(--accent); }

.status-msg {
  padding: 8px 20px; background: rgba(166,227,161,0.1);
  color: var(--success); font-size: 13px; text-align: center;
}

/* Flow */
.flow-container {
  flex: 1;
  width: 100%;
}

/* Empty state */
.empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  gap: 12px;
}
.empty-icon { font-size: 48px; }
.empty-state h2 { font-size: 22px; color: var(--text-primary); }
.empty-state p { font-size: 14px; }
.hint { font-size: 12px; color: var(--text-secondary); max-width: 400px; text-align: center; }

/* Modal */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal-content {
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 24px;
  width: 400px;
  max-width: 90vw;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}
.modal-content h3 {
  margin: 0 0 16px 0;
  font-size: 16px;
  color: var(--text-primary);
}
.form-group {
  margin-bottom: 14px;
}
.form-group label {
  display: block;
  font-size: 12px;
  color: var(--text-secondary);
  margin-bottom: 6px;
  font-weight: 500;
}
.form-input {
  width: 100%;
  padding: 8px 12px;
  background: var(--bg-primary);
  border: 1px solid var(--border);
  border-radius: 6px;
  color: var(--text-primary);
  font-size: 13px;
  outline: none;
  box-sizing: border-box;
}
.form-input:focus {
  border-color: var(--accent);
}
textarea.form-input {
  resize: vertical;
  font-family: inherit;
}
.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 20px;
}
</style>
