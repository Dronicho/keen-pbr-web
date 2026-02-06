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
	<div class="flex items-center gap-4 mb-6">
		<button
			onclick={onClose}
			class="text-sm transition-colors"
			style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);"
			onmouseenter={(e) => { e.currentTarget.style.color = 'var(--text-primary)'; }}
			onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-tertiary)'; }}
			aria-label="Back to lists"
		>
			&larr; back
		</button>
		<div class="flex-1">
			<div class="flex items-center gap-3">
				<h2 class="text-xl font-bold" style="color: var(--text-primary);">{name}</h2>
				{#if type === 'inline'}
					<span
						class="inline-flex items-center  px-2 py-0.5 text-[11px] font-medium"
						style="color: var(--brand); background: rgba(255,136,0,0.1);"
					>
						inline
					</span>
				{:else if type === 'file'}
					<span
						class="inline-flex items-center  px-2 py-0.5 text-[11px] font-medium"
						style="color: var(--positive); background: rgba(73,161,71,0.1);"
					>
						file
					</span>
				{:else}
					<span
						class="inline-flex items-center  px-2 py-0.5 text-[11px] font-medium"
						style="color: var(--text-tertiary); background: rgba(255,255,255,0.05);"
					>
						url
					</span>
				{/if}
			</div>
		</div>
	</div>

	<!-- Error banner -->
	{#if error}
		<div
			class="mb-4  p-4 text-sm"
			style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
		>
			{error}
		</div>
	{/if}

	<!-- Success banner -->
	{#if message}
		<div
			class="mb-4  p-4 text-sm"
			style="background: rgba(73,161,71,0.1); border: 1px solid rgba(73,161,71,0.2); color: var(--positive);"
		>
			{message}
		</div>
	{/if}

	<!-- Loading state -->
	{#if loadingList}
		<div class=" p-8" style="border: 1px solid var(--stroke);">
			<div class="flex items-center justify-center gap-3">
				<span
					class="inline-block h-5 w-5 animate-spin rounded-full border-2"
					style="border-color: var(--text-quad); border-top-color: var(--text-secondary);"
				></span>
				<span class="text-sm" style="color: var(--text-tertiary);">Loading list...</span>
			</div>
		</div>
	{:else if type === 'url'}
		<!-- URL list: read-only -->
		<div class=" p-6" style="border: 1px solid var(--stroke);">
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
	{:else if isEditable}
		<!-- Editable list -->
		<div class=" overflow-hidden" style="border: 1px solid var(--stroke);">
			<!-- Add entry -->
			<div class="p-4" style="border-bottom: 1px solid var(--stroke);">
				<div class="flex gap-2">
					<input
						type="text"
						bind:value={newEntry}
						onkeydown={handleKeydown}
						placeholder="Add domain, IP, or CIDR..."
						class="flex-1  px-3 py-2 text-sm focus:outline-none transition-colors"
						style="background: var(--bg-tertiary); border: 1px solid var(--stroke); color: var(--text-primary); font-family: 'IBM Plex Mono', monospace;"
						onfocus={(e) => { e.currentTarget.style.borderColor = 'var(--stroke-hover)'; }}
						onblur={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
					/>
					<button
						onclick={addEntry}
						disabled={!newEntry.trim()}
						class="inline-flex items-center gap-1  px-4 py-2 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
						style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
					>
						Add
					</button>
				</div>
			</div>

			<!-- Entry count -->
			<div class="px-4 py-2" style="border-bottom: 1px solid var(--stroke); background: var(--bg-tertiary);">
				<p class="text-[11px] uppercase" style="color: var(--text-tertiary); letter-spacing: 0.05em;">
					<span style="font-family: 'IBM Plex Mono', monospace;">{entries.length}</span>
					{entries.length === 1 ? 'entry' : 'entries'}
				</p>
			</div>

			<!-- Entries list -->
			<div class="max-h-96 overflow-y-auto">
				{#if entries.length === 0}
					<div class="p-8 text-center text-sm" style="color: var(--text-quad);">
						No entries yet. Add domains, IPs, or CIDRs above.
					</div>
				{:else}
					<ul>
						{#each entries as entry, index}
							<li
								class="flex items-center justify-between px-4 py-2 group transition-colors"
								style="border-bottom: 1px solid var(--stroke);"
								onmouseenter={(e) => { e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
								onmouseleave={(e) => { e.currentTarget.style.background = 'transparent'; }}
							>
								<span class="text-sm" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-secondary);">
									{entry}
								</span>
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
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<!-- Save button -->
			<div class="p-4 " style="border-top: 1px solid var(--stroke); background: var(--bg-tertiary);">
				<button
					onclick={save}
					disabled={saving}
					class="inline-flex items-center gap-2  px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
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
			</div>
		</div>
	{/if}
</div>
