<script setup>
import { Handle, Position } from '@vue-flow/core'
import { computed, watch } from 'vue'

const props = defineProps({
  data: Object,
})

watch(() => props.data, (newData) => {
  console.log('[WorkflowNode] data changed:', newData?.status, newData?.detail)
}, { deep: true })

const statusIcon = computed(() => {
  switch (props.data?.status) {
    case 'pending': return '⏳'
    case 'in_progress': return '⚡'
    case 'completed': return '✅'
    case 'failed': return '❌'
    case 'skipped': return '⏭️'
    default: return '⏳'
  }
})

const statusClass = computed(() => `status-${props.data?.status || 'pending'}`)
</script>

<template>
  <div class="workflow-node" :class="statusClass">
    <Handle type="target" :position="Position.Left" />
    <div class="node-header">
      <span class="node-icon">{{ statusIcon }}</span>
      <span class="node-label">{{ data?.label || 'Task' }}</span>
    </div>
    <div v-if="data?.description" class="node-desc">{{ data.description }}</div>
    <div v-if="data?.detail" class="node-detail">{{ data.detail }}</div>
    <Handle type="source" :position="Position.Right" />
  </div>
</template>

<style scoped>
.workflow-node {
  background: #1e1e2e;
  border: 2px solid #45475a;
  border-radius: 10px;
  padding: 12px 16px;
  min-width: 180px;
  max-width: 280px;
  color: #cdd6f4;
  font-size: 13px;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
}

.status-pending { border-color: #585b70; }
.status-in_progress {
  border-color: #89b4fa;
  box-shadow: 0 0 12px rgba(137, 180, 250, 0.4);
  animation: pulse 2s infinite;
}
.status-completed { border-color: #a6e3a1; }
.status-failed { border-color: #f38ba8; }
.status-skipped { border-color: #6c7086; }

@keyframes pulse {
  0%, 100% { box-shadow: 0 0 8px rgba(137, 180, 250, 0.3); }
  50% { box-shadow: 0 0 20px rgba(137, 180, 250, 0.6); }
}

.node-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  font-size: 14px;
}

.node-icon { font-size: 16px; }

.node-desc {
  margin-top: 6px;
  color: #a6adc8;
  font-size: 12px;
  line-height: 1.4;
}

.node-detail {
  margin-top: 6px;
  padding: 4px 8px;
  background: rgba(137, 180, 250, 0.1);
  border-radius: 4px;
  font-size: 11px;
  color: #89b4fa;
  word-break: break-word;
}
</style>
