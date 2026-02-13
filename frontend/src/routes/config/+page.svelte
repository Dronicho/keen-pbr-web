<script lang="ts">
	import { getConfigRaw, saveConfigRaw } from '$lib/api';

	let content = $state('');
	let originalContent = $state('');
	let loading = $state(true);
	let saving = $state(false);
	let error: string | null = $state(null);
	let message: string | null = $state(null);
	let hasChanges = $derived(content !== originalContent);

	async function loadConfig() {
		loading = true;
		error = null;
		try {
			content = await getConfigRaw();
			originalContent = content;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load config';
		} finally {
			loading = false;
		}
	}

	async function save() {
		saving = true;
		error = null;
		message = null;
		try {
			await saveConfigRaw(content);
			originalContent = content;
			message = 'Config saved successfully';
			setTimeout(() => { message = null; }, 3000);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to save config (invalid TOML?)';
		} finally {
			saving = false;
		}
	}

	function reset() {
		content = originalContent;
		error = null;
		message = null;
	}

	$effect(() => {
		loadConfig();
	});
</script>

<div class="max-w-4xl">
	<!-- Header -->
	<div class="mb-6">
		<h2 class="text-xl font-bold text-gray-800">Config</h2>
		<p class="text-sm text-gray-500 mt-1">Raw TOML configuration editor</p>
	</div>

	<!-- Error banner -->
	{#if error}
		<div class="mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700 whitespace-pre-wrap break-words">
			{error}
		</div>
	{/if}

	<!-- Success banner -->
	{#if message}
		<div class="mb-4 rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-700">
			{message}
		</div>
	{/if}

	<!-- Loading state -->
	{#if loading}
		<div class="bg-white rounded-lg border border-gray-200 p-8">
			<div class="flex items-center justify-center gap-3 text-gray-500">
				<span class="inline-block h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-gray-600"></span>
				<span class="text-sm">Loading config...</span>
			</div>
		</div>
	{:else}
		<!-- Unsaved changes indicator -->
		{#if hasChanges}
			<div class="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-2 text-sm text-amber-700 flex items-center gap-2">
				<span class="inline-block h-2 w-2 rounded-full bg-amber-500"></span>
				You have unsaved changes
			</div>
		{/if}

		<!-- Editor -->
		<div class="rounded-lg border border-gray-200 overflow-hidden">
			<textarea
				bind:value={content}
				spellcheck="false"
				autocomplete="off"
				autocorrect="off"
				autocapitalize="off"
				class="w-full min-h-[500px] p-4 font-mono text-sm leading-relaxed bg-gray-900 text-gray-100 resize-y focus:outline-none border-none"
				placeholder="# TOML configuration..."
			></textarea>
		</div>

		<!-- Buttons -->
		<div class="flex items-center gap-3 mt-4">
			<button
				onclick={save}
				disabled={!hasChanges || saving}
				class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
			>
				{#if saving}
					<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
					Saving...
				{:else}
					Save
				{/if}
			</button>
			<button
				onclick={reset}
				disabled={!hasChanges || saving}
				class="inline-flex items-center gap-2 rounded-lg bg-white border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
			>
				Reset
			</button>
		</div>
	{/if}
</div>
