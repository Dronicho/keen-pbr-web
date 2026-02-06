<script lang="ts">
	import { goto } from '$app/navigation';
	import { getLists, getConfig, createList, deleteList, type ListInfo, type IPSet } from '$lib/api';

	let lists: ListInfo[] = $state([]);
	let ipsets: IPSet[] = $state([]);
	let error: string | null = $state(null);

	// Add list form
	let showAdd = $state(false);
	let newName = $state('');
	let newUrl = $state('');
	let newIpset = $state('');

	async function loadData() {
		error = null;
		try {
			const [listsData, configData] = await Promise.all([getLists(), getConfig()]);
			lists = listsData;
			ipsets = configData.ipsets;
			if (!newIpset && ipsets.length > 0) {
				newIpset = ipsets[0].ipset_name;
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load data';
		}
	}

	function navigateToList(name: string) {
		goto(`/lists/${name}`);
	}

	async function handleAdd() {
		if (!newName.trim() || !newUrl.trim() || !newIpset) return;
		error = null;
		try {
			await createList(newName.trim(), newUrl.trim(), newIpset);
			newName = '';
			newUrl = '';
			showAdd = false;
			await loadData();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create list';
		}
	}

	async function handleDelete(e: MouseEvent, name: string) {
		e.stopPropagation();
		error = null;
		try {
			await deleteList(name);
			await loadData();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to delete list';
		}
	}

	$effect(() => {
		loadData();
	});
</script>

<div class="max-w-4xl">
	<div class="flex items-center justify-between mb-8">
		<h2 class="text-2xl font-bold" style="color: var(--text-primary);">Lists</h2>
		<button
			onclick={() => { showAdd = !showAdd; }}
			class="px-4 py-2 text-[13px] font-semibold uppercase transition-colors"
			style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
		>
			{showAdd ? 'Cancel' : 'Add URL List'}
		</button>
	</div>

	{#if error}
		<div
			class="mb-6 p-4 text-sm"
			style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
		>
			{error}
		</div>
	{/if}

	{#if showAdd}
		<div class="mb-6 p-5" style="border: 1px solid var(--stroke);">
			<p
				class="text-[11px] font-semibold uppercase mb-3"
				style="color: var(--text-tertiary); letter-spacing: 0.05em;"
			>
				New URL List
			</p>
			<div class="flex flex-col gap-3">
				<input
					type="text"
					bind:value={newName}
					placeholder="List name (e.g. community-hosts)"
					class="px-3 py-2 text-sm focus:outline-none transition-colors"
					style="background: var(--bg-tertiary); border: 1px solid var(--stroke); color: var(--text-primary); font-family: 'IBM Plex Mono', monospace;"
					onfocus={(e) => { e.currentTarget.style.borderColor = 'var(--brand)'; }}
					onblur={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
				/>
				<input
					type="text"
					bind:value={newUrl}
					placeholder="https://example.com/domains.txt"
					class="px-3 py-2 text-sm focus:outline-none transition-colors"
					style="background: var(--bg-tertiary); border: 1px solid var(--stroke); color: var(--text-primary); font-family: 'IBM Plex Mono', monospace;"
					onfocus={(e) => { e.currentTarget.style.borderColor = 'var(--brand)'; }}
					onblur={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
				/>
				<div class="flex items-center gap-3">
					<span class="text-[11px] font-semibold uppercase shrink-0" style="color: var(--text-quad); letter-spacing: 0.05em;">IP Set</span>
					<div class="flex gap-2">
						{#each ipsets as ipset}
							<button
								onclick={() => { newIpset = ipset.ipset_name; }}
								class="px-3 py-1.5 text-xs font-medium transition-colors"
								style="font-family: 'IBM Plex Mono', monospace; {newIpset === ipset.ipset_name
									? 'background: var(--text-primary); color: var(--bg-primary);'
									: 'background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--stroke);'
								}"
							>
								{ipset.ipset_name}
							</button>
						{/each}
					</div>
				</div>
				<div class="flex gap-2">
					<button
						onclick={handleAdd}
						disabled={!newName.trim() || !newUrl.trim() || !newIpset}
						class="px-4 py-2 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
						style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
					>
						Add
					</button>
				</div>
			</div>
		</div>
	{/if}

	{#if lists.length === 0}
		<div class="p-8 text-center" style="border: 1px solid var(--stroke);">
			<p class="text-sm" style="color: var(--text-tertiary);">No lists configured. Add a URL list above or edit the Config.</p>
		</div>
	{:else}
		<table class="w-full" style="border: 1px solid var(--stroke);">
			<thead>
				<tr style="border-bottom: 1px solid var(--stroke);">
					<th class="text-left px-4 py-3 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Name</th>
					<th class="text-left px-4 py-3 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Type</th>
					<th class="text-left px-4 py-3 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">IP Set</th>
					<th class="text-left px-4 py-3 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Source</th>
					<th class="w-12"></th>
				</tr>
			</thead>
			<tbody>
				{#each lists as list}
					<tr
						class="group transition-colors cursor-pointer"
						style="border-bottom: 1px solid var(--stroke);"
						onclick={() => navigateToList(list.name)}
						onmouseenter={(e) => { e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
						onmouseleave={(e) => { e.currentTarget.style.background = 'transparent'; }}
					>
						<td class="px-4 py-3">
							<span class="text-sm font-medium" style="color: var(--text-primary);">{list.name}</span>
						</td>
						<td class="px-4 py-3">
							<span
								class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium uppercase"
								style="letter-spacing: 0.05em; {list.type === 'inline'
									? 'color: var(--brand); background: rgba(255,136,0,0.1);'
									: list.type === 'file'
										? 'color: var(--positive); background: rgba(73,161,71,0.1);'
										: 'color: var(--text-tertiary); background: rgba(255,255,255,0.05);'
								}"
							>
								{list.type}
							</span>
						</td>
						<td class="px-4 py-3">
							<div class="flex flex-wrap gap-1">
								{#each list.ipsets as ipsetName}
									<span
										class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium"
										style="font-family: 'IBM Plex Mono', monospace; background: var(--bg-tertiary); color: var(--text-secondary);"
									>{ipsetName}</span>
								{:else}
									<span class="text-xs" style="color: var(--text-quad);">&mdash;</span>
								{/each}
							</div>
						</td>
						<td class="px-4 py-3">
							{#if list.type === 'url' && list.url}
								<span class="text-xs truncate block max-w-xs" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">{list.url}</span>
							{:else if list.type === 'file' && list.file}
								<span class="text-xs truncate block max-w-xs" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">{list.file}</span>
							{:else if list.entries}
								<span class="text-xs" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">{list.entries.length} {list.entries.length === 1 ? 'entry' : 'entries'}</span>
							{:else}
								<span class="text-xs" style="color: var(--text-quad);">&mdash;</span>
							{/if}
						</td>
						<td class="px-2 py-3 text-right">
							<button
								onclick={(e) => handleDelete(e, list.name)}
								class="inline-flex items-center justify-center p-1 opacity-0 group-hover:opacity-100 transition-all"
								style="color: var(--text-quad);"
								onmouseenter={(e) => { e.currentTarget.style.color = 'var(--negative)'; }}
								onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-quad)'; }}
								aria-label="Delete {list.name}"
							>
								<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</div>
