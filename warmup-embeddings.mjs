import { pipeline, env } from '@xenova/transformers';

env.cacheDir = process.env.TRANSFORMERS_CACHE ?? '/opt/agentmemory/.cache';
console.log('[warmup] Caching embedding model to:', env.cacheDir);

const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
await embedder('warmup', { pooling: 'mean', normalize: true });
console.log('[warmup] Embedding model warmed up successfully.');
process.exit(0);
