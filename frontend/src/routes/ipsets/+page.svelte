<script lang="ts">
	import { getConfig, type Config, type IPSet } from '$lib/api';

	let config: Config | null = $state(null);
	let loading = $state(true);
	let error: string | null = $state(null);

	async function loadConfig() {
		loading = true;
		error = null;
		try {
			config = await getConfig();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load config';
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		loadConfig();
	});
</script>

<div class="max-w-4xl">
	<h2 class="text-xl font-bold text-gray-800 mb-6">IP Sets</h2>

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
				<span class="text-sm">Loading IP sets...</span>
			</div>
		</div>
	{:else if config && config.ipsets.length === 0}
		<div class="bg-white rounded-lg border border-gray-200 p-8 text-center">
			<p class="text-sm text-gray-500">No IP sets configured. Add IP sets in the Config page.</p>
		</div>
	{:else if config}
		<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
			{#each config.ipsets as ipset}
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<!-- Header: name + IP version badge -->
					<div class="flex items-start justify-between mb-3">
						<h3 class="text-sm font-semibold text-gray-800 break-all">{ipset.ipset_name}</h3>
						<span class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium shrink-0 ml-2 {ipset.ip_version === 4 ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}">
							IPv{ipset.ip_version}
						</span>
					</div>

					<!-- Lists -->
					{#if ipset.lists.length > 0}
						<div class="mb-3">
							<p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1.5">Lists</p>
							<div class="flex flex-wrap gap-1.5">
								{#each ipset.lists as list}
									<span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-700">{list}</span>
								{/each}
							</div>
						</div>
					{/if}

					<!-- Routing details table -->
					<div class="border-t border-gray-100 pt-3">
						<table class="w-full text-sm">
							<tbody>
								{#if ipset.routing.interfaces.length > 0}
									<tr>
										<td class="py-1 pr-3 text-gray-500 whitespace-nowrap align-top">Interfaces</td>
										<td class="py-1 font-medium text-gray-800">{ipset.routing.interfaces.join(', ')}</td>
									</tr>
								{/if}
								<tr>
									<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">FW Mark</td>
									<td class="py-1 font-mono text-gray-800">{ipset.routing.fwmark}</td>
								</tr>
								<tr>
									<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">Table</td>
									<td class="py-1 font-mono text-gray-800">{ipset.routing.table}</td>
								</tr>
								<tr>
									<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">Priority</td>
									<td class="py-1 font-mono text-gray-800">{ipset.routing.priority}</td>
								</tr>
								<tr>
									<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">Kill Switch</td>
									<td class="py-1">
										{#if ipset.routing.kill_switch}
											<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">On</span>
										{:else}
											<span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-600">Off</span>
										{/if}
									</td>
								</tr>
								{#if ipset.routing.override_dns}
									<tr>
										<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">DNS Override</td>
										<td class="py-1 font-mono text-gray-800">{ipset.routing.override_dns}</td>
									</tr>
								{/if}
								<tr>
									<td class="py-1 pr-3 text-gray-500 whitespace-nowrap">Flush</td>
									<td class="py-1">
										{#if ipset.flush_before_applying}
											<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">On</span>
										{:else}
											<span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-600">Off</span>
										{/if}
									</td>
								</tr>
							</tbody>
						</table>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
