<script lang="ts">
	import { goto } from '$app/navigation';
	import { getStatus, getLists, type StatusInfo, type ListInfo } from '$lib/api';

	let status: StatusInfo | null = $state(null);
	let lists: ListInfo[] = $state([]);
	let error: string | null = $state(null);

	async function loadStatus() {
		try {
			error = null;
			status = await getStatus();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load status';
		}
	}

	async function loadLists() {
		try {
			lists = await getLists();
		} catch {
			// silently fail, lists are non-critical for dashboard
		}
	}

	function navigateToList(name: string) {
		goto(`/lists/${name}`);
	}

	$effect(() => {
		loadStatus();
		loadLists();
	});
</script>

<div class="max-w-4xl">
	<h2 class="text-2xl font-bold mb-8" style="color: var(--text-primary);">Dashboard</h2>

	{#if error}
		<div
			class="mb-6 p-4 text-sm"
			style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
		>
			{error}
		</div>
	{/if}

	<!-- Overview -->
	<p
		class="text-[11px] font-semibold uppercase mb-3"
		style="color: var(--text-tertiary); letter-spacing: 0.05em;"
	>
		Overview
	</p>

	<div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-10">
		<div class="p-5" style="border: 1px solid var(--stroke);">
			<p class="text-[11px] font-semibold uppercase mb-2" style="color: var(--text-tertiary); letter-spacing: 0.05em;">
				Config Path
			</p>
			<p class="text-sm break-all" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-secondary);">
				{status?.config_path ?? '\u2014'}
			</p>
		</div>
		<div class="p-5" style="border: 1px solid var(--stroke);">
			<p class="text-[11px] font-semibold uppercase mb-2" style="color: var(--text-tertiary); letter-spacing: 0.05em;">
				Lists
			</p>
			<p class="text-4xl font-bold" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">
				{status?.lists_count ?? 0}
			</p>
		</div>
		<div class="p-5" style="border: 1px solid var(--stroke);">
			<p class="text-[11px] font-semibold uppercase mb-2" style="color: var(--text-tertiary); letter-spacing: 0.05em;">
				IP Sets
			</p>
			<p class="text-4xl font-bold" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">
				{status?.ipsets_count ?? 0}
			</p>
		</div>
	</div>

	<!-- Quick Links to Lists -->
	{#if lists.length > 0}
		<p
			class="text-[11px] font-semibold uppercase mb-3"
			style="color: var(--text-tertiary); letter-spacing: 0.05em;"
		>
			Quick Links
		</p>
		<div style="border: 1px solid var(--stroke);">
			<table class="w-full">
				<thead>
					<tr style="border-bottom: 1px solid var(--stroke);">
						<th class="text-left px-4 py-2.5 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">
							List
						</th>
						<th class="text-left px-4 py-2.5 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">
							Type
						</th>
						<th class="text-left px-4 py-2.5 text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">
							Info
						</th>
					</tr>
				</thead>
				<tbody>
					{#each lists as list}
						<tr
							class="transition-colors cursor-pointer"
							style="border-bottom: 1px solid var(--stroke);"
							onclick={() => navigateToList(list.name)}
							onmouseenter={(e) => { e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
							onmouseleave={(e) => { e.currentTarget.style.background = 'transparent'; }}
						>
							<td class="px-4 py-2.5">
								<span class="text-sm font-medium" style="color: var(--text-primary);">
									{list.name}
								</span>
							</td>
							<td class="px-4 py-2.5">
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
							<td class="px-4 py-2.5">
								{#if list.type === 'url' && list.url}
									<span class="text-xs truncate block max-w-xs" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">
										{list.url}
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
		</div>
	{/if}
</div>
