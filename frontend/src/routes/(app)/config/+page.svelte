<script lang="ts">
	import { getConfigRaw, saveConfigRaw } from '$lib/api';

	let content = $state('');
	let originalContent = $state('');
	let saving = $state(false);
	let error: string | null = $state(null);
	let message: string | null = $state(null);
	let hasChanges = $derived(content !== originalContent);

	async function loadConfig() {
		error = null;
		try {
			content = await getConfigRaw();
			originalContent = content;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load config';
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

<div class="flex flex-col h-[calc(100vh-64px)]">
	<!-- Fixed top bar -->
	<div class="shrink-0 pb-4" style="border-bottom: 1px solid var(--stroke);">
		<div class="flex items-center gap-3 mb-1">
			<h2 class="text-2xl font-bold" style="color: var(--text-primary);">Config</h2>
			{#if hasChanges}
				<span class="inline-block h-2 w-2 rounded-full" style="background: var(--brand);"></span>
				<span class="text-xs" style="color: var(--brand);">Unsaved changes</span>
			{/if}
		</div>
		<p class="text-sm" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-tertiary);">
			keen-pbr.conf &mdash; raw TOML
		</p>

		{#if error}
			<div
				class="mt-3 p-3 text-sm whitespace-pre-wrap break-words"
				style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
			>
				{error}
			</div>
		{/if}
		{#if message}
			<div
				class="mt-3 p-3 text-sm"
				style="background: rgba(73,161,71,0.1); border: 1px solid rgba(73,161,71,0.2); color: var(--positive);"
			>
				{message}
			</div>
		{/if}
	</div>

	<!-- Scrollable editor -->
	<div class="flex-1 overflow-hidden min-h-0" style="border-left: 1px solid var(--stroke); border-right: 1px solid var(--stroke);">
		<textarea
			bind:value={content}
			spellcheck="false"
			autocomplete="off"
			autocorrect="off"
			autocapitalize="off"
			class="w-full h-full p-4 text-sm leading-relaxed resize-none focus:outline-none border-none"
			style="font-family: 'IBM Plex Mono', monospace; background: var(--bg-code); color: var(--text-secondary);"
			placeholder="# TOML configuration..."
		></textarea>
	</div>

	<!-- Fixed bottom bar -->
	<div class="shrink-0 flex items-center gap-3 pt-4" style="border-top: 1px solid var(--stroke);">
		<button
			onclick={save}
			disabled={!hasChanges || saving}
			class="inline-flex items-center gap-2 px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
			style="background: var(--text-primary); color: var(--bg-primary); letter-spacing: 0.05em;"
		>
			Save
		</button>
		<button
			onclick={reset}
			disabled={!hasChanges || saving}
			class="inline-flex items-center gap-2 px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
			style="background: transparent; color: var(--text-secondary); border: 1px solid var(--stroke); letter-spacing: 0.05em;"
			onmouseenter={(e) => { e.currentTarget.style.borderColor = 'var(--stroke-hover)'; }}
			onmouseleave={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
		>
			Reset
		</button>
		<button
			onclick={loadConfig}
			disabled={saving}
			class="inline-flex items-center gap-2 px-5 py-2.5 text-[13px] font-semibold uppercase disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
			style="background: transparent; color: var(--text-secondary); border: 1px solid var(--stroke); letter-spacing: 0.05em;"
			onmouseenter={(e) => { e.currentTarget.style.borderColor = 'var(--stroke-hover)'; }}
			onmouseleave={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
		>
			Reload
		</button>
	</div>
</div>
