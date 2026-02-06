<script lang="ts">
	import { getConfig, type Config } from '$lib/api';

	let config: Config | null = $state(null);
	let error: string | null = $state(null);

	async function loadConfig() {
		error = null;
		try {
			config = await getConfig();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load config';
		}
	}

	$effect(() => {
		loadConfig();
	});
</script>

<div class="max-w-4xl">
	<div class="mb-8">
		<h2 class="text-2xl font-bold" style="color: var(--text-primary);">IP Sets</h2>
		<p class="text-sm mt-1" style="color: var(--text-tertiary);">
			Routing policy configuration for each ipset. Each ipset groups lists of hosts/IPs and routes matching traffic through specified network interfaces.
		</p>
	</div>

	{#if error}
		<div
			class="mb-6 p-4 text-sm"
			style="background: rgba(235,54,28,0.1); border: 1px solid rgba(235,54,28,0.2); color: var(--negative);"
		>
			{error}
		</div>
	{/if}

	{#if config && config.ipsets.length === 0}
		<div class="p-8 text-center" style="border: 1px solid var(--stroke);">
			<p class="text-sm" style="color: var(--text-tertiary);">No IP sets configured. Add IP sets in the Config page.</p>
		</div>
	{:else if config}
		{#each config.ipsets as ipset}
			<div class="mb-4" style="border: 1px solid var(--stroke);">
				<div class="flex items-center justify-between px-5 py-4" style="border-bottom: 1px solid var(--stroke);">
					<div class="flex items-center gap-3">
						<h3 class="text-base font-bold" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.ipset_name}</h3>
						<span
							class="inline-flex items-center px-2 py-0.5 text-[11px] font-medium uppercase"
							style="letter-spacing: 0.05em; font-family: 'IBM Plex Mono', monospace; {ipset.ip_version === 4 ? 'color: var(--brand); background: rgba(255,136,0,0.1);' : 'color: #b537f2; background: rgba(181,55,242,0.1);'}"
						>
							IPv{ipset.ip_version}
						</span>
					</div>
					<div class="flex items-center gap-3">
						{#if ipset.routing.kill_switch}
							<span class="inline-flex items-center gap-1.5 text-[11px] font-medium uppercase" style="letter-spacing: 0.05em; color: var(--positive);">
								<span class="inline-block h-2 w-2 rounded-full" style="background: var(--positive);"></span>
								Kill Switch
							</span>
						{/if}
					</div>
				</div>
				<table class="w-full text-sm">
					<tbody>
						{#if ipset.lists.length > 0}
							<tr style="border-bottom: 1px solid var(--stroke);">
								<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em; width: 140px;">Lists</td>
								<td class="px-5 py-3">
									<div class="flex flex-wrap gap-1.5">
										{#each ipset.lists as list}
											<a href="/lists/{list}" class="inline-flex items-center px-2.5 py-0.5 text-xs font-medium transition-colors" style="font-family: 'IBM Plex Mono', monospace; background: var(--bg-tertiary); color: var(--text-secondary);" onmouseenter={(e) => { e.currentTarget.style.color = 'var(--brand)'; }} onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-secondary)'; }}>{list}</a>
										{/each}
									</div>
								</td>
							</tr>
						{/if}
						{#if ipset.routing.interfaces.length > 0}
							<tr style="border-bottom: 1px solid var(--stroke);">
								<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Interfaces</td>
								<td class="px-5 py-3" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.routing.interfaces.join(', ')}</td>
							</tr>
						{/if}
						<tr style="border-bottom: 1px solid var(--stroke);">
							<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">FW Mark</td>
							<td class="px-5 py-3" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.routing.fwmark}</td>
						</tr>
						<tr style="border-bottom: 1px solid var(--stroke);">
							<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Table</td>
							<td class="px-5 py-3" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.routing.table}</td>
						</tr>
						<tr style="border-bottom: 1px solid var(--stroke);">
							<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Priority</td>
							<td class="px-5 py-3" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.routing.priority}</td>
						</tr>
						{#if ipset.routing.override_dns}
							<tr style="border-bottom: 1px solid var(--stroke);">
								<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">DNS Override</td>
								<td class="px-5 py-3" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">{ipset.routing.override_dns}</td>
							</tr>
						{/if}
						<tr>
							<td class="px-5 py-3 whitespace-nowrap text-[11px] font-semibold uppercase" style="color: var(--text-quad); letter-spacing: 0.05em;">Flush on Apply</td>
							<td class="px-5 py-3">
								{#if ipset.flush_before_applying}
									<span class="inline-flex items-center gap-1.5 text-xs font-medium">
										<span class="inline-block h-2 w-2 rounded-full" style="background: var(--positive);"></span>
										<span style="color: var(--positive);">On</span>
									</span>
								{:else}
									<span class="inline-flex items-center gap-1.5 text-xs font-medium">
										<span class="inline-block h-2 w-2 rounded-full" style="background: var(--text-quad);"></span>
										<span style="color: var(--text-quad);">Off</span>
									</span>
								{/if}
							</td>
						</tr>
					</tbody>
				</table>
			</div>
		{/each}
	{/if}
</div>
