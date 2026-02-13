<script lang="ts">
	import { getList, saveList, type ListInfo } from '$lib/api';

	let { name, type, onClose }: { name: string; type: string; onClose: () => void } = $props();

	let list: ListInfo | null = $state(null);
	let entries: string[] = $state([]);
	let newEntry = $state('');
	let saving = $state(false);
	let message = $state('');
	let error = $state('');
	let loadingList = $state(true);

	async function load() {
		loadingList = true;
		error = '';
		try {
			list = await getList(name);
			entries = [...(list.entries || [])];
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load list';
		} finally {
			loadingList = false;
		}
	}

	function addEntry() {
		const val = newEntry.trim();
		if (val && !entries.includes(val)) {
			entries = [...entries, val];
			newEntry = '';
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			addEntry();
		}
	}

	function removeEntry(index: number) {
		entries = entries.filter((_, i) => i !== index);
	}

	async function save() {
		saving = true;
		message = '';
		error = '';
		try {
			await saveList(name, entries);
			message = 'Saved successfully';
			setTimeout(() => {
				message = '';
			}, 3000);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to save';
		} finally {
			saving = false;
		}
	}

	$effect(() => {
		load();
	});

	let isEditable = $derived(type === 'inline' || type === 'file');
</script>

<div class="max-w-3xl">
	<!-- Header -->
	<div class="flex items-center gap-3 mb-6">
		<button
			onclick={onClose}
			class="inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white p-2 text-gray-500 hover:bg-gray-50 hover:text-gray-700 transition-colors"
			aria-label="Back to lists"
		>
			<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
			</svg>
		</button>
		<div class="flex-1">
			<div class="flex items-center gap-2">
				<h2 class="text-xl font-bold text-gray-800">{name}</h2>
				{#if type === 'inline'}
					<span class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800">inline</span>
				{:else if type === 'file'}
					<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">file</span>
				{:else}
					<span class="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-800">url</span>
				{/if}
			</div>
		</div>
	</div>

	<!-- Error banner -->
	{#if error}
		<div class="mb-4 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
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
	{#if loadingList}
		<div class="bg-white rounded-lg border border-gray-200 p-8">
			<div class="flex items-center justify-center gap-3 text-gray-500">
				<span class="inline-block h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-gray-600"></span>
				<span class="text-sm">Loading list...</span>
			</div>
		</div>
	{:else if type === 'url'}
		<!-- URL list: read-only -->
		<div class="bg-white rounded-lg border border-gray-200 p-6">
			<p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">Source URL</p>
			<p class="text-sm font-mono text-gray-800 break-all">{list?.url || 'No URL specified'}</p>
		</div>
	{:else if isEditable}
		<!-- Editable list -->
		<div class="bg-white rounded-lg border border-gray-200">
			<!-- Add entry -->
			<div class="p-4 border-b border-gray-200">
				<div class="flex gap-2">
					<input
						type="text"
						bind:value={newEntry}
						onkeydown={handleKeydown}
						placeholder="Add domain, IP, or CIDR..."
						class="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-800 placeholder-gray-400 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
					/>
					<button
						onclick={addEntry}
						disabled={!newEntry.trim()}
						class="inline-flex items-center gap-1 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
					>
						Add
					</button>
				</div>
			</div>

			<!-- Entry count -->
			<div class="px-4 py-2 border-b border-gray-100 bg-gray-50">
				<p class="text-xs text-gray-500">{entries.length} {entries.length === 1 ? 'entry' : 'entries'}</p>
			</div>

			<!-- Entries list -->
			<div class="max-h-96 overflow-y-auto">
				{#if entries.length === 0}
					<div class="p-8 text-center text-sm text-gray-400">
						No entries yet. Add domains, IPs, or CIDRs above.
					</div>
				{:else}
					<ul class="divide-y divide-gray-100">
						{#each entries as entry, index}
							<li class="flex items-center justify-between px-4 py-2 hover:bg-gray-50 group">
								<span class="text-sm font-mono text-gray-700">{entry}</span>
								<button
									onclick={() => removeEntry(index)}
									class="inline-flex items-center justify-center rounded p-1 text-gray-400 hover:bg-red-50 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-all"
									aria-label="Remove {entry}"
								>
									<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<!-- Save button -->
			<div class="p-4 border-t border-gray-200 bg-gray-50 rounded-b-lg">
				<button
					onclick={save}
					disabled={saving}
					class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
				>
					{#if saving}
						<span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></span>
						Saving...
					{:else}
						Save
					{/if}
				</button>
			</div>
		</div>
	{/if}
</div>
