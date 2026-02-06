<script lang="ts">
	import { getList, saveList, type ListInfo } from '$lib/api';

	let { data } = $props();
	let name = $derived(data.name);

	let list: ListInfo | null = $state(null);
	let entries: string[] = $state([]);
	let newEntry = $state('');
	let saving = $state(false);
	let message = $state('');
	let error = $state('');
	let loading = $state(true);

	async function load() {
		loading = true;
		error = '';
		try {
			list = await getList(name);
			entries = [...(list.entries || [])];
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load list';
		} finally {
			loading = false;
		}
	}

	function addEntries(text: string) {
		const values = text
			.split(/[\s,;]+/)
			.map(v => v.trim())
			.filter(v => v.length > 0 && !entries.includes(v));
		if (values.length > 0) {
			entries = [...entries, ...values];
		}
	}

	function addEntry() {
		const val = newEntry.trim();
		if (!val) return;
		addEntries(val);
		newEntry = '';
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			addEntry();
		}
	}

	function handlePaste(e: ClipboardEvent) {
		const text = e.clipboardData?.getData('text') || '';
		if (text.includes('\n') || text.includes(' ') || text.includes('\t')) {
			e.preventDefault();
			addEntries(text);
			newEntry = '';
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
			setTimeout(() => { message = ''; }, 3000);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to save';
		} finally {
			saving = false;
		}
	}

	$effect(() => {
		load();
	});

	let isEditable = $derived(list ? (list.type === 'inline' || list.type === 'file') : false);
</script>

<div class="flex flex-col h-[calc(100vh-64px)]">
	<!-- Fixed top bar -->
	<div class="shrink-0 pb-4" style="border-bottom: 1px solid var(--stroke);">
		<div class="flex items-center gap-4 mb-4">
			<a
				href="/lists"
				class="text-sm transition-colors"
				style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);"
				onmouseenter={(e) => { e.currentTarget.style.color = 'var(--text-primary)'; }}
				onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-tertiary)'; }}
			>
				&larr; lists
			</a>
			<div class="flex items-center gap-3">
				<h2 class="text-xl font-bold" style="color: var(--text-primary);">{name}</h2>
				{#if list}
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
				{/if}
			</div>
		</div>

		<!-- Error/success banners -->
		{#if error}
			<div
				class="mb-3 p-3 text-sm"
				style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
			>
				{error}
			</div>
		{/if}
		{#if message}
			<div
				class="mb-3 p-3 text-sm"
				style="background: rgba(73,161,71,0.1); border: 1px solid rgba(73,161,71,0.2); color: var(--positive);"
			>
				{message}
			</div>
		{/if}

		<!-- Add entry input (for editable lists) -->
		{#if isEditable && !loading}
			<div class="flex gap-2">
				<input
					type="text"
					bind:value={newEntry}
					onkeydown={handleKeydown}
					onpaste={handlePaste}
					placeholder="Add domain, IP, or CIDR... (paste multiple separated by space/newline)"
					class="flex-1 px-3 py-2 text-sm focus:outline-none transition-colors"
					style="background: var(--bg-tertiary); border: 1px solid var(--stroke); color: var(--text-primary); font-family: 'IBM Plex Mono', monospace;"
					onfocus={(e) => { e.currentTarget.style.borderColor = 'var(--brand)'; }}
					onblur={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
				/>
				<button
					onclick={addEntry}
					disabled={!newEntry.trim()}
					class="px-4 py-2 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
					style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
				>
					Add
				</button>
			</div>
		{/if}
	</div>

	<!-- Scrollable entries -->
	<div class="flex-1 overflow-y-auto min-h-0">
		{#if loading}
			<div class="flex items-center justify-center py-16">
				<span
					class="inline-block h-5 w-5 animate-spin rounded-full border-2"
					style="border-color: var(--text-quad); border-top-color: var(--text-secondary);"
				></span>
				<span class="ml-3 text-sm" style="color: var(--text-tertiary);">Loading...</span>
			</div>
		{:else if list?.type === 'url'}
			<div class="py-8">
				<p
					class="text-[11px] font-semibold uppercase mb-2"
					style="color: var(--text-tertiary); letter-spacing: 0.05em;"
				>
					Source URL
				</p>
				<p
					class="text-sm break-all"
					style="font-family: 'IBM Plex Mono', monospace; color: var(--text-secondary);"
				>
					{list?.url || 'No URL specified'}
				</p>
			</div>
		{:else if entries.length === 0}
			<div class="flex items-center justify-center py-16">
				<p class="text-sm" style="color: var(--text-quad);">No entries yet. Add domains, IPs, or CIDRs above.</p>
			</div>
		{:else}
			<table class="w-full">
				<thead>
					<tr style="border-bottom: 1px solid var(--stroke);">
						<th
							class="text-left px-4 py-2 text-[11px] font-semibold uppercase"
							style="color: var(--text-quad); letter-spacing: 0.05em;"
						>
							Entry
						</th>
						{#if isEditable}
							<th class="w-12"></th>
						{/if}
					</tr>
				</thead>
				<tbody>
					{#each entries as entry, index}
						<tr
							class="group transition-colors"
							style="border-bottom: 1px solid var(--stroke);"
							onmouseenter={(e) => { e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
							onmouseleave={(e) => { e.currentTarget.style.background = 'transparent'; }}
						>
							<td class="px-4 py-2">
								<span class="text-sm" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-secondary);">
									{entry}
								</span>
							</td>
							{#if isEditable}
								<td class="px-2 py-2 text-right">
									<button
										onclick={() => removeEntry(index)}
										class="inline-flex items-center justify-center p-1 opacity-0 group-hover:opacity-100 transition-all"
										style="color: var(--text-quad);"
										onmouseenter={(e) => { e.currentTarget.style.color = 'var(--negative)'; }}
										onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-quad)'; }}
										aria-label="Remove {entry}"
									>
										<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
										</svg>
									</button>
								</td>
							{/if}
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>

	<!-- Fixed bottom bar -->
	{#if isEditable && !loading}
		<div class="shrink-0 flex items-center gap-3 pt-4" style="border-top: 1px solid var(--stroke);">
			<button
				onclick={save}
				disabled={saving}
				class="inline-flex items-center gap-2 px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
				style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
			>
				{#if saving}
					<span
						class="inline-block h-4 w-4 animate-spin rounded-full border-2"
						style="border-color: var(--bg-primary); border-top-color: transparent;"
					></span>
					Saving...
				{:else}
					Save
				{/if}
			</button>
			<button
				onclick={load}
				disabled={saving}
				class="inline-flex items-center gap-2 px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
				style="background: transparent; color: var(--text-secondary); border: 1px solid var(--stroke); letter-spacing: 0.05em;"
				onmouseenter={(e) => { e.currentTarget.style.borderColor = 'var(--stroke-hover)'; }}
				onmouseleave={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
			>
				Reload
			</button>
			<span class="ml-auto text-[11px] uppercase" style="color: var(--text-quad); letter-spacing: 0.05em; font-family: 'IBM Plex Mono', monospace;">
				{entries.length} {entries.length === 1 ? 'entry' : 'entries'}
			</span>
		</div>
	{/if}
</div>
