<script lang="ts">
	import { getDiagnostic, type ActionResult } from '$lib/api';

	interface DiagSection {
		id: 'interfaces' | 'dnsmasq-config' | 'dns';
		label: string;
		description: string;
	}

	const sections: DiagSection[] = [
		{ id: 'interfaces', label: 'Interfaces', description: 'Available network interfaces for routing' },
		{ id: 'dnsmasq-config', label: 'Dnsmasq Config', description: 'Generated dnsmasq configuration for ipset-based DNS resolution' },
		{ id: 'dns', label: 'DNS', description: 'Current DNS configuration and status' },
	];

	let results: Record<string, ActionResult | null> = $state({});

	async function loadSection(id: DiagSection['id']) {
		try {
			results[id] = await getDiagnostic(id);
		} catch (e) {
			results[id] = { success: false, output: e instanceof Error ? e.message : 'Failed to load' };
		}
	}

	async function loadAll() {
		for (const s of sections) {
			loadSection(s.id);
		}
	}

	$effect(() => {
		loadAll();
	});
</script>

<div class="max-w-4xl">
	<div class="mb-8">
		<h2 class="text-2xl font-bold" style="color: var(--text-primary);">Diagnostics</h2>
		<p class="text-sm mt-1" style="color: var(--text-tertiary);">
			Live output from keen-pbr diagnostic commands.
		</p>
	</div>

	{#each sections as section}
		<div class="mb-6" style="border: 1px solid var(--stroke);">
			<div class="flex items-center justify-between px-5 py-3" style="border-bottom: 1px solid var(--stroke);">
				<div>
					<h3 class="text-sm font-bold" style="color: var(--text-primary);">{section.label}</h3>
					<p class="text-[11px] mt-0.5" style="color: var(--text-tertiary);">{section.description}</p>
				</div>
				<button
					onclick={() => loadSection(section.id)}
					class="px-3 py-1 text-[11px] font-semibold uppercase transition-colors"
					style="color: var(--text-secondary); border: 1px solid var(--stroke); letter-spacing: 0.05em;"
					onmouseenter={(e) => { e.currentTarget.style.borderColor = 'var(--stroke-hover)'; }}
					onmouseleave={(e) => { e.currentTarget.style.borderColor = 'var(--stroke)'; }}
				>
					Refresh
				</button>
			</div>
			<div class="px-5 py-4">
				{#if results[section.id]}
					{@const r = results[section.id]}
					{#if !r.success}
						<div class="mb-2 text-[11px] font-semibold uppercase" style="color: var(--negative); letter-spacing: 0.05em;">
							Error
						</div>
					{/if}
					<pre
						class="text-xs leading-relaxed overflow-x-auto whitespace-pre-wrap"
						style="font-family: 'IBM Plex Mono', monospace; color: {r.success ? 'var(--text-secondary)' : 'var(--negative)'};"
					>{r.output || '(no output)'}</pre>
				{:else}
					<p class="text-sm" style="color: var(--text-quad);">&mdash;</p>
				{/if}
			</div>
		</div>
	{/each}
</div>
