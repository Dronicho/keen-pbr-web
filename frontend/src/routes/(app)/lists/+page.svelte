<script lang="ts">
	import { goto } from '$app/navigation';
	import { getLists, type ListInfo } from '$lib/api';

	let lists: ListInfo[] = $state([]);
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

	function navigateToList(name: string) {
		goto(`/lists/${name}`);
	}

	$effect(() => {
		loadLists();
	});
</script>

<div class="max-w-4xl">
	<h2 class="text-2xl font-bold mb-8" style="color: var(--text-primary);">Lists</h2>

	{#if error}
		<div
			class="mb-6 p-4 text-sm"
			style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
		>
			{error}
		</div>
	{/if}

	{#if loading}
		<div class="p-8" style="border: 1px solid var(--stroke);">
			<div class="flex items-center justify-center gap-3">
				<span
					class="inline-block h-5 w-5 animate-spin rounded-full border-2"
					style="border-color: var(--text-quad); border-top-color: var(--text-secondary);"
				></span>
				<span class="text-sm" style="color: var(--text-tertiary);">Loading lists...</span>
			</div>
		</div>
	{:else if lists.length === 0}
		<div class="p-8 text-center" style="border: 1px solid var(--stroke);">
			<p class="text-sm" style="color: var(--text-tertiary);">No lists configured. Add lists in the Config page.</p>
		</div>
	{:else}
		<table class="w-full" style="border: 1px solid var(--stroke);">
			<thead>
				<tr style="border-bottom: 1px solid var(--stroke);">
					<th
						class="text-left px-4 py-3 text-[11px] font-semibold uppercase"
						style="color: var(--text-quad); letter-spacing: 0.05em;"
					>
						Name
					</th>
					<th
						class="text-left px-4 py-3 text-[11px] font-semibold uppercase"
						style="color: var(--text-quad); letter-spacing: 0.05em;"
					>
						Type
					</th>
					<th
						class="text-left px-4 py-3 text-[11px] font-semibold uppercase"
						style="color: var(--text-quad); letter-spacing: 0.05em;"
					>
						Source
					</th>
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
							<span class="text-sm font-medium" style="color: var(--text-primary);">
								{list.name}
							</span>
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
							{#if list.type === 'url' && list.url}
								<span
									class="text-xs truncate block max-w-xs"
									style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);"
								>
									{list.url}
								</span>
							{:else if list.type === 'file' && list.file}
								<span
									class="text-xs truncate block max-w-xs"
									style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);"
								>
									{list.file}
								</span>
							{:else if list.entries}
								<span class="text-xs" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">
									{list.entries.length} {list.entries.length === 1 ? 'entry' : 'entries'}
								</span>
							{:else}
								<span class="text-xs" style="color: var(--text-quad);">&mdash;</span>
							{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</div>
