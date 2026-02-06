<script lang="ts">
	import { page } from '$app/state';
	import { runAction, type ActionResult } from '$lib/api';
	let { children } = $props();

	const navItems = [
		{ href: '/', label: 'Dashboard' },
		{ href: '/lists', label: 'Lists' },
		{ href: '/ipsets', label: 'IP Sets' },
		{ href: '/diagnostics', label: 'Diagnostics' },
		{ href: '/config', label: 'Config' },
	];

	let loading = $state('');
	let lastResult: ActionResult | null = $state(null);

	async function executeAction(action: 'download' | 'apply' | 'self-check' | 'undo-routing') {
		loading = action;
		lastResult = null;
		try {
			lastResult = await runAction(action);
		} catch (e) {
			lastResult = { success: false, output: e instanceof Error ? e.message : 'Action failed' };
		} finally {
			loading = '';
			setTimeout(() => { lastResult = null; }, 4000);
		}
	}
</script>

<div class="min-h-screen flex" style="background: var(--bg-primary);">
	<!-- Sidebar -->
	<nav
		class="w-56 flex flex-col shrink-0 fixed inset-y-0 left-0 z-10"
		style="background: var(--bg-primary); border-right: 1px solid var(--stroke);"
	>
		<div class="px-5 py-5" style="border-bottom: 1px solid var(--stroke);">
			<h1 class="text-lg font-bold" style="font-family: 'IBM Plex Mono', monospace; color: var(--text-primary);">
				keen-pbr<span style="color: var(--brand);">*</span>
			</h1>
			<p
				class="text-[10px] mt-0.5 uppercase"
				style="color: var(--text-tertiary); letter-spacing: 0.1em;"
			>
				routing control
			</p>
		</div>
		<div class="flex-1 py-3">
			{#each navItems as item}
				{@const isActive = page.url.pathname === item.href || (item.href !== '/' && page.url.pathname.startsWith(item.href))}
				<a
					href={item.href}
					class="flex items-center px-5 py-2.5 text-[13px] font-semibold transition-colors"
					style="color: {isActive ? 'var(--brand)' : 'var(--text-secondary)'}; border-left: 2px solid {isActive ? 'var(--brand)' : 'transparent'};"
					onmouseenter={(e) => { if (!isActive) e.currentTarget.style.color = 'var(--text-primary)'; }}
					onmouseleave={(e) => { if (!isActive) e.currentTarget.style.color = 'var(--text-secondary)'; }}
				>
					{item.label}
				</a>
			{/each}
		</div>

		<!-- Control Plane -->
		<div class="px-4 py-4" style="border-top: 1px solid var(--stroke);">
			<p
				class="text-[10px] font-semibold uppercase mb-3"
				style="color: var(--text-quad); letter-spacing: 0.1em;"
			>
				Control
			</p>
			<div class="flex flex-col gap-1.5">
				<button
					onclick={() => executeAction('download')}
					disabled={loading !== ''}
					class="flex items-center gap-2 w-full px-3 py-1.5 text-[12px] font-medium text-left transition-colors disabled:opacity-40"
					style="color: var(--text-secondary);"
					onmouseenter={(e) => { e.currentTarget.style.color = 'var(--text-primary)'; e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
					onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-secondary)'; e.currentTarget.style.background = 'transparent'; }}
				>
					{#if loading === 'download'}
						<span class="inline-block h-3 w-3 animate-spin rounded-full border border-t-transparent" style="border-color: var(--text-secondary); border-top-color: transparent;"></span>
					{:else}
						<svg class="h-3.5 w-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
					{/if}
					Download
				</button>
				<button
					onclick={() => executeAction('apply')}
					disabled={loading !== ''}
					class="flex items-center gap-2 w-full px-3 py-1.5 text-[12px] font-medium text-left transition-colors disabled:opacity-40"
					style="color: var(--text-secondary);"
					onmouseenter={(e) => { e.currentTarget.style.color = 'var(--text-primary)'; e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
					onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-secondary)'; e.currentTarget.style.background = 'transparent'; }}
				>
					{#if loading === 'apply'}
						<span class="inline-block h-3 w-3 animate-spin rounded-full border border-t-transparent" style="border-color: var(--text-secondary); border-top-color: transparent;"></span>
					{:else}
						<svg class="h-3.5 w-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
					{/if}
					Apply
				</button>
				<button
					onclick={() => executeAction('self-check')}
					disabled={loading !== ''}
					class="flex items-center gap-2 w-full px-3 py-1.5 text-[12px] font-medium text-left transition-colors disabled:opacity-40"
					style="color: var(--text-secondary);"
					onmouseenter={(e) => { e.currentTarget.style.color = 'var(--text-primary)'; e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
					onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-secondary)'; e.currentTarget.style.background = 'transparent'; }}
				>
					{#if loading === 'self-check'}
						<span class="inline-block h-3 w-3 animate-spin rounded-full border border-t-transparent" style="border-color: var(--text-secondary); border-top-color: transparent;"></span>
					{:else}
						<svg class="h-3.5 w-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
					{/if}
					Self-Check
				</button>
				<button
					onclick={() => executeAction('undo-routing')}
					disabled={loading !== ''}
					class="flex items-center gap-2 w-full px-3 py-1.5 text-[12px] font-medium text-left transition-colors disabled:opacity-40"
					style="color: var(--text-secondary);"
					onmouseenter={(e) => { e.currentTarget.style.color = 'var(--negative)'; e.currentTarget.style.background = 'var(--bg-tertiary)'; }}
					onmouseleave={(e) => { e.currentTarget.style.color = 'var(--text-secondary)'; e.currentTarget.style.background = 'transparent'; }}
				>
					{#if loading === 'undo-routing'}
						<span class="inline-block h-3 w-3 animate-spin rounded-full border border-t-transparent" style="border-color: var(--text-secondary); border-top-color: transparent;"></span>
					{:else}
						<svg class="h-3.5 w-3.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
					{/if}
					Undo Routing
				</button>
			</div>
			{#if lastResult}
				<div class="mt-2 px-3 py-1.5 text-[11px]" style="color: {lastResult.success ? 'var(--positive)' : 'var(--negative)'};">
					{lastResult.success ? 'Done' : 'Failed'}
				</div>
			{/if}
		</div>

		<div class="px-5 py-3" style="border-top: 1px solid var(--stroke);">
			<span
				class="text-[11px]"
				style="font-family: 'IBM Plex Mono', monospace; color: var(--text-quad);"
			>
				v1.0
			</span>
		</div>
	</nav>

	<!-- Main content -->
	<main class="flex-1 ml-56 p-8" style="background: var(--bg-primary);">
		{@render children()}
	</main>
</div>
