<script lang="ts">
	import { getStatus, runAction, type StatusInfo, type ActionResult } from '$lib/api';

	let status: StatusInfo | null = $state(null);
	let actionOutput: ActionResult | null = $state(null);
	let loading = $state('');
	let error: string | null = $state(null);

	async function loadStatus() {
		try {
			error = null;
			status = await getStatus();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load status';
		}
	}

	async function executeAction(action: 'download' | 'apply' | 'self-check') {
		loading = action;
		actionOutput = null;
		try {
			actionOutput = await runAction(action);
		} catch (e) {
			actionOutput = { success: false, output: e instanceof Error ? e.message : 'Action failed' };
		} finally {
			loading = '';
			loadStatus();
		}
	}

	$effect(() => {
		loadStatus();
	});
</script>

<div class="max-w-4xl">
	<h2 class="text-xl font-bold text-gray-800 mb-6">Dashboard</h2>

	<!-- Error banner -->
	{#if error}
		<div class="mb-6 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
			{error}
		</div>
	{/if}

	<!-- Status cards -->
	<div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Config Path</p>
			{#if status}
				<p class="text-sm font-mono text-gray-800 break-all">{status.config_path}</p>
			{:else}
				<p class="text-sm text-gray-400">Loading...</p>
			{/if}
		</div>
		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Lists</p>
			{#if status}
				<p class="text-2xl font-bold text-gray-800">{status.lists_count}</p>
			{:else}
				<p class="text-sm text-gray-400">Loading...</p>
			{/if}
		</div>
		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">IP Sets</p>
			{#if status}
				<p class="text-2xl font-bold text-gray-800">{status.ipsets_count}</p>
			{:else}
				<p class="text-sm text-gray-400">Loading...</p>
			{/if}
		</div>
	</div>

	<!-- Action buttons -->
	<h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">Actions</h3>
	<div class="flex flex-wrap gap-3 mb-8">
		<button
			onclick={() => executeAction('download')}
			disabled={loading !== ''}
			class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
		>
			{#if loading === 'download'}
				<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
				Downloading...
			{:else}
				Download Lists
			{/if}
		</button>
		<button
			onclick={() => executeAction('apply')}
			disabled={loading !== ''}
			class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
		>
			{#if loading === 'apply'}
				<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
				Applying...
			{:else}
				Apply Config
			{/if}
		</button>
		<button
			onclick={() => executeAction('self-check')}
			disabled={loading !== ''}
			class="inline-flex items-center gap-2 rounded-lg bg-gray-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
		>
			{#if loading === 'self-check'}
				<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
				Checking...
			{:else}
				Self-Check
			{/if}
		</button>
	</div>

	<!-- Action output -->
	{#if actionOutput}
		<h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">Output</h3>
		<div
			class="rounded-lg border p-4 {actionOutput.success
				? 'border-green-200 bg-green-50'
				: 'border-red-200 bg-red-50'}"
		>
			<div class="flex items-center gap-2 mb-2">
				{#if actionOutput.success}
					<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
						Success
					</span>
				{:else}
					<span class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
						Failed
					</span>
				{/if}
			</div>
			<pre
				class="whitespace-pre-wrap break-words text-sm font-mono {actionOutput.success
					? 'text-green-900'
					: 'text-red-900'}">{actionOutput.output}</pre>
		</div>
	{/if}
</div>
