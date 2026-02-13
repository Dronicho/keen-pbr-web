<script lang="ts">
	import { getLists, type ListInfo } from '$lib/api';
	import ListEditor from '$lib/components/ListEditor.svelte';

	let lists: ListInfo[] = $state([]);
	let selectedList: string | null = $state(null);
	let selectedType: string = $state('');
	let loading = $state(true);
	let error: string | null = $state(null);

	async function loadLists() {
		loading = true;
		error = null;
		try {
			lists = await getLists();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load lists';
		} finally {
			loading = false;
		}
	}

	function selectList(name: string, type: string) {
		selectedList = name;
		selectedType = type;
	}

	function closeEditor() {
		selectedList = null;
		selectedType = '';
		loadLists();
	}

	$effect(() => {
		loadLists();
	});
</script>

{#if selectedList}
	<ListEditor name={selectedList} type={selectedType} onClose={closeEditor} />
{:else}
	<div class="max-w-4xl">
		<h2 class="text-xl font-bold text-gray-800 mb-6">Lists</h2>

		<!-- Error banner -->
		{#if error}
			<div class="mb-6 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
				{error}
			</div>
		{/if}

		<!-- Loading state -->
		{#if loading}
			<div class="bg-white rounded-lg border border-gray-200 p-8">
				<div class="flex items-center justify-center gap-3 text-gray-500">
					<span class="inline-block h-5 w-5 animate-spin rounded-full border-2 border-gray-300 border-t-gray-600"></span>
					<span class="text-sm">Loading lists...</span>
				</div>
			</div>
		{:else if lists.length === 0}
			<div class="bg-white rounded-lg border border-gray-200 p-8 text-center">
				<p class="text-sm text-gray-500">No lists configured. Add lists in the Config page.</p>
			</div>
		{:else}
			<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
				{#each lists as list}
					<button
						onclick={() => selectList(list.name, list.type)}
						class="bg-white rounded-lg border border-gray-200 p-4 text-left hover:border-gray-300 hover:shadow-sm transition-all group"
					>
						<div class="flex items-start justify-between mb-2">
							<h3 class="text-sm font-semibold text-gray-800 group-hover:text-blue-700 transition-colors break-all">{list.name}</h3>
							{#if list.type === 'inline'}
								<span class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 shrink-0 ml-2">inline</span>
							{:else if list.type === 'file'}
								<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 shrink-0 ml-2">file</span>
							{:else}
								<span class="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-800 shrink-0 ml-2">url</span>
							{/if}
						</div>
						{#if list.type === 'url' && list.url}
							<p class="text-xs font-mono text-gray-500 truncate">{list.url}</p>
						{:else if list.type === 'file' && list.file}
							<p class="text-xs font-mono text-gray-500 truncate">{list.file}</p>
						{:else if list.entries}
							<p class="text-xs text-gray-500">{list.entries.length} {list.entries.length === 1 ? 'entry' : 'entries'}</p>
						{/if}
					</button>
				{/each}
			</div>
		{/if}
	</div>
{/if}
