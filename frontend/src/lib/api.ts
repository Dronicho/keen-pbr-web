const API_BASE = '/api';

export interface StatusInfo {
	config_path: string;
	lists_count: number;
	ipsets_count: number;
}

export interface ActionResult {
	success: boolean;
	output: string;
}

export interface ListInfo {
	name: string;
	type: 'inline' | 'file' | 'url';
	url?: string;
	file?: string;
	entries?: string[];
}

export interface Config {
	general: {
		lists_output_dir: string;
		use_keenetic_api: boolean;
		use_keenetic_dns: boolean;
		fallback_dns: string;
	};
	ipsets: IPSet[];
	lists: ListDef[];
}

export interface IPSet {
	ipset_name: string;
	lists: string[];
	ip_version: number;
	flush_before_applying: boolean;
	routing: {
		interfaces: string[];
		kill_switch: boolean;
		fwmark: number;
		table: number;
		priority: number;
		override_dns?: string;
	};
}

export interface ListDef {
	list_name: string;
	url?: string;
	file?: string;
	hosts?: string[];
}

async function fetchJSON<T>(url: string, options?: RequestInit): Promise<T> {
	const res = await fetch(API_BASE + url, options);
	if (!res.ok) {
		const text = await res.text();
		throw new Error(text || res.statusText);
	}
	return res.json();
}

async function fetchText(url: string, options?: RequestInit): Promise<string> {
	const res = await fetch(API_BASE + url, options);
	if (!res.ok) {
		const text = await res.text();
		throw new Error(text || res.statusText);
	}
	return res.text();
}

export async function getStatus(): Promise<StatusInfo> {
	return fetchJSON('/status');
}

export async function getConfig(): Promise<Config> {
	return fetchJSON('/config');
}

export async function saveConfig(config: Config): Promise<void> {
	await fetchJSON('/config', {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(config),
	});
}

export async function getConfigRaw(): Promise<string> {
	return fetchText('/config/raw');
}

export async function saveConfigRaw(content: string): Promise<void> {
	await fetch(API_BASE + '/config/raw', {
		method: 'PUT',
		headers: { 'Content-Type': 'text/plain' },
		body: content,
	});
}

export async function getLists(): Promise<ListInfo[]> {
	return fetchJSON('/lists');
}

export async function getList(name: string): Promise<ListInfo> {
	return fetchJSON(`/lists/${encodeURIComponent(name)}`);
}

export async function saveList(name: string, entries: string[]): Promise<void> {
	await fetchJSON(`/lists/${encodeURIComponent(name)}`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ entries }),
	});
}

export async function runAction(action: 'download' | 'apply' | 'self-check'): Promise<ActionResult> {
	return fetchJSON(`/actions/${action}`, { method: 'POST' });
}
