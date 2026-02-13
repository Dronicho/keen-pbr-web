<script>
	import '../app.css';
	import { page } from '$app/state';
	let { children } = $props();

	const navItems = [
		{ href: '/', label: 'Dashboard', icon: '\u2302' },
		{ href: '/lists', label: 'Lists', icon: '\u2630' },
		{ href: '/ipsets', label: 'IPSets', icon: '\u21C4' },
		{ href: '/config', label: 'Config', icon: '\u2699' },
	];
</script>

<div class="min-h-screen bg-gray-50 flex">
	<!-- Sidebar -->
	<nav class="w-56 bg-white border-r border-gray-200 flex flex-col">
		<div class="p-4 border-b border-gray-200">
			<h1 class="text-lg font-bold text-gray-800">keen-pbr</h1>
			<p class="text-xs text-gray-500">web configuration</p>
		</div>
		<div class="flex-1 py-2">
			{#each navItems as item}
				<a
					href={item.href}
					class="flex items-center px-4 py-2.5 text-sm transition-colors {page.url.pathname === item.href ? 'bg-blue-50 text-blue-700 font-medium border-r-2 border-blue-700' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'}"
				>
					<span class="mr-3">{item.icon}</span>
					{item.label}
				</a>
			{/each}
		</div>
	</nav>

	<!-- Main content -->
	<main class="flex-1 p-6">
		{@render children()}
	</main>
</div>
