#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
	CallToolRequestSchema,
	ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec, execSync } from "child_process";
import { promisify } from "util";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { readFile, writeFile, unlink } from "fs/promises";
import { randomBytes } from "crypto";

const execAsync = promisify(exec);
const __dirname = dirname(fileURLToPath(import.meta.url));
const NVIMRUN_PATH = join(__dirname, "nvimrun.sh");

// Active sessions tracking
const sessions = new Map();

class NvimRunServer {
	constructor() {
		this.server = new Server(
			{
				name: "@aetherall/mcp-nvim-tmux",
				vendor: "aetherall",
				version: "1.0.0",
				description: "Control Neovim instances through MCP",
			},
			{
				capabilities: {
					tools: {},
				},
			},
		);
		this.setupHandlers();
	}

	setupHandlers() {
		// List available tools
		this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
			tools: [
				{
					name: "nvim_start",
					description: "Start a new Neovim session in tmux",
					inputSchema: {
						type: "object",
						properties: {
							session: {
								type: "string",
								description: "Session name (optional)",
							},
							width: {
								type: "number",
								description: "Terminal width (default: 80)",
							},
							height: {
								type: "number",
								description: "Terminal height (default: 24)",
							},
							record: {
								type: "boolean",
								description: "Record session with asciinema (default: false)",
							},
						},
					},
				},
				{
					name: "nvim_stop",
					description: "Stop a Neovim session",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
						},
						required: ["session"],
					},
				},
				{
					name: "nvim_keys",
					description: "Send keystrokes to Neovim",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							keys: {
								type: "array",
								items: { type: "string" },
								description: "Keys to send",
							},
						},
						required: ["session", "keys"],
					},
				},
				{
					name: "nvim_cmd",
					description: "Execute a Vim command",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							command: {
								type: "string",
								description: "Vim command to execute",
							},
						},
						required: ["session", "command"],
					},
				},
				{
					name: "nvim_lua",
					description: "Execute Lua code in Neovim",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							code: { type: "string", description: "Lua code to execute" },
						},
						required: ["session", "code"],
					},
				},
				{
					name: "nvim_lua_file",
					description:
						"Execute Lua code from multiline input (avoids escaping issues)",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							code: {
								type: "string",
								description: "Lua code to execute (multiline safe)",
							},
						},
						required: ["session", "code"],
					},
				},
				{
					name: "nvim_screen",
					description: "Capture the current screen content",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							color: {
								type: "boolean",
								description: "Include ANSI color codes",
							},
						},
						required: ["session"],
					},
				},
				{
					name: "nvim_edit",
					description: "Open a file at a specific line",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							file: { type: "string", description: "File path" },
							line: { type: "number", description: "Line number (optional)" },
						},
						required: ["session", "file"],
					},
				},
				{
					name: "nvim_insert",
					description: "Insert text at current cursor position",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							text: { type: "string", description: "Text to insert" },
						},
						required: ["session", "text"],
					},
				},
				{
					name: "nvim_type",
					description: "Type literal text without any special key interpretation",
					inputSchema: {
						type: "object",
						properties: {
							session: { type: "string", description: "Session name" },
							text: { type: "string", description: "Text to type literally" },
						},
						required: ["session", "text"],
					},
				},
				{
					name: "nvim_recordings",
					description: "List available asciinema recordings",
					inputSchema: {
						type: "object",
						properties: {},
					},
				},
				{
					name: "nvim_play",
					description: "Play an asciinema recording",
					inputSchema: {
						type: "object",
						properties: {
							pattern: { 
								type: "string", 
								description: "Recording file name or pattern to match" 
							},
						},
						required: ["pattern"],
					},
				},
				{
					name: "nvim_cat",
					description: "Display asciinema recording in AI-readable format with input/output timeline",
					inputSchema: {
						type: "object",
						properties: {
							pattern: { 
								type: "string", 
								description: "Recording file name or pattern to match" 
							},
						},
						required: ["pattern"],
					},
				},
				{
					name: "nvim_analyze",
					description: "Analyze a Neovim recording using AI to explain what happened",
					inputSchema: {
						type: "object",
						properties: {
							pattern: { 
								type: "string", 
								description: "Recording file name or pattern to match" 
							},
							summarize: {
								type: "boolean",
								description: "If true, provide a brief summary instead of detailed analysis",
								default: false
							},
						},
						required: ["pattern"],
					},
				},
			],
		}));

		// Handle tool calls
		this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
			const { name, arguments: args } = request.params;

			try {
				switch (name) {
					case "nvim_start":
						return await this.start(args);
					case "nvim_stop":
						return await this.stop(args);
					case "nvim_keys":
						return await this.keys(args);
					case "nvim_cmd":
						return await this.cmd(args);
					case "nvim_lua":
						return await this.lua(args);
					case "nvim_lua_file":
						return await this.luaFile(args);
					case "nvim_screen":
						return await this.screen(args);
					case "nvim_edit":
						return await this.edit(args);
					case "nvim_insert":
						return await this.insert(args);
					case "nvim_type":
						return await this.type(args);
					case "nvim_recordings":
						return await this.recordings(args);
					case "nvim_play":
						return await this.play(args);
					case "nvim_cat":
						return await this.cat(args);
					case "nvim_analyze":
						return await this.analyze(args);
					default:
						throw new Error(`Unknown tool: ${name}`);
				}
			} catch (error) {
				return {
					content: [
						{
							type: "text",
							text: `Error: ${error.message}`,
						},
					],
				};
			}
		});
	}

	async runCommand(cmd) {
		const { stdout, stderr } = await execAsync(cmd);
		if (stderr && !stderr.includes("warning")) {
			throw new Error(stderr);
		}
		return stdout;
	}

	async start({ session, width = 80, height = 24, record = false }) {
		const sessionName = session || `nvim_mcp_${randomBytes(4).toString("hex")}`;

		const recordFlag = record ? "--record" : "";
		await this.runCommand(
			`${NVIMRUN_PATH} start ${sessionName} ${width} ${height} ${recordFlag}`,
		);
		sessions.set(sessionName, { width, height, startTime: new Date(), recording: record });

		return {
			content: [
				{
					type: "text",
					text: `Started Neovim session: ${sessionName} (${width}x${height})${record ? " [RECORDING]" : ""}`,
				},
			],
		};
	}

	async stop({ session }) {
		await this.runCommand(`${NVIMRUN_PATH} stop ${session}`);
		sessions.delete(session);

		return {
			content: [
				{
					type: "text",
					text: `Stopped session: ${session}`,
				},
			],
		};
	}

	async keys({ session, keys }) {
		const keysStr = keys.join(" ");
		await this.runCommand(`${NVIMRUN_PATH} keys ${session} ${keysStr}`);
		
		// Get screen content after sending keys
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async cmd({ session, command }) {
		await this.runCommand(`${NVIMRUN_PATH} cmd ${session} "${command}"`);
		
		// Get screen content after executing command
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async lua({ session, code }) {
		// Escape single quotes
		const escaped = code.replace(/'/g, "'\\''");
		await this.runCommand(`${NVIMRUN_PATH} lua ${session} '${escaped}'`);
		
		// Get screen content after executing Lua
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async luaFile({ session, code }) {
		// Use temporary file for complex Lua code
		const tmpFile = `/tmp/nvim_mcp_${randomBytes(8).toString("hex")}.lua`;

		try {
			await writeFile(tmpFile, code);
			await this.runCommand(
				`${NVIMRUN_PATH} keys ${session} ":luafile ${tmpFile}" Enter`,
			);

			// Wait a bit before cleanup
			setTimeout(() => unlink(tmpFile).catch(() => {}), 1000);
			
			// Get screen content after executing Lua file
			const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

			return {
				content: [
					{
						type: "text",
						text: screen,
					},
				],
			};
		} catch (error) {
			await unlink(tmpFile).catch(() => {});
			throw error;
		}
	}

	async screen({ session, color = false }) {
		const colorFlag = color ? "--color" : "";
		const output = await this.runCommand(
			`${NVIMRUN_PATH} screen ${session} ${colorFlag}`,
		);

		return {
			content: [
				{
					type: "text",
					text: output,
				},
			],
		};
	}


	async edit({ session, file, line }) {
		const lineCmd = line ? `${line}` : "";
		await this.runCommand(`${NVIMRUN_PATH} cmd ${session} "e ${file}"`);

		if (line) {
			await this.runCommand(`${NVIMRUN_PATH} cmd ${session} "${line}"`);
		}
		
		// Get screen content after opening file
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async insert({ session, text }) {
		// Escape special characters
		const escaped = text.replace(/"/g, '\\"');
		await this.runCommand(
			`${NVIMRUN_PATH} keys ${session} i "${escaped}" Escape`,
		);
		
		// Get screen content after inserting text
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async type({ session, text }) {
		// Use stdin to pass text, avoiding all shell escaping issues
		// Note: exec doesn't support input option, so we use execSync
		try {
			execSync(`${NVIMRUN_PATH} type ${session} -`, { 
				input: text,
				encoding: 'utf8'
			});
		} catch (error) {
			if (error.stderr && !error.stderr.includes("warning")) {
				throw new Error(error.stderr);
			}
		}
		
		// Get screen content after typing text
		const screen = await this.runCommand(`${NVIMRUN_PATH} screen ${session}`);

		return {
			content: [
				{
					type: "text",
					text: screen,
				},
			],
		};
	}

	async recordings() {
		const output = await this.runCommand(`${NVIMRUN_PATH} recordings`);

		return {
			content: [
				{
					type: "text",
					text: output || "No recordings found.",
				},
			],
		};
	}

	async play({ pattern }) {
		const output = await this.runCommand(`${NVIMRUN_PATH} play "${pattern}"`);

		return {
			content: [
				{
					type: "text",
					text: `Playing recording: ${pattern}\n${output}`,
				},
			],
		};
	}

	async cat({ pattern }) {
		const output = await this.runCommand(`${NVIMRUN_PATH} cat "${pattern}"`);

		return {
			content: [
				{
					type: "text",
					text: output,
				},
			],
		};
	}

	async analyze({ pattern, summarize = false }) {
		const summarizeFlag = summarize ? "summarize" : "";
		const output = await this.runCommand(`${NVIMRUN_PATH} analyze "${pattern}" ${summarizeFlag}`);

		return {
			content: [
				{
					type: "text",
					text: output,
				},
			],
		};
	}

	async run() {
		const transport = new StdioServerTransport();
		await this.server.connect(transport);
		console.error("Nvimrun MCP server running on stdio");
	}
}

// Handle cleanup on exit
process.on("SIGINT", async () => {
	console.error("Cleaning up sessions...");
	for (const [session] of sessions) {
		try {
			await execAsync(`${NVIMRUN_PATH} stop ${session}`);
		} catch (error) {
			// Ignore errors during cleanup
		}
	}
	process.exit(0);
});

// Start the server
const server = new NvimRunServer();
server.run().catch(console.error);
