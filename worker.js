// worker.js (Module Worker) – Gateway multi-provider con Responses API + Chat Completions

var __defProp = Object.defineProperty;
var __name = (target, value) =>
  __defProp(target, "name", { value, configurable: true });

// =========================
// CONFIGURAZIONE PROVIDERS
// =========================
const PROVIDERS = {
  openai: {
    baseUrl: "https://api.openai.com/v1/chat/completions",
    responsesUrl: "https://api.openai.com/v1/responses",
    modelsUrl: "https://api.openai.com/v1/models",
    apiKeyEnv: "OPENAI_API_KEY",
    headerName: "Authorization",
    headerPrefix: "Bearer",
    supportsStreaming: true,
    supportsResponses: true,
    // Fallback statico (usato solo se manca la chiave o /models fallisce)
    supportedModels: [
      // Serie GPT-4.1 e 4o (2025) + legacy ancora presenti
      "gpt-4.1", "gpt-4.1-mini",
      "gpt-4o", "gpt-4o-mini", "chatgpt-4o-latest",
      "gpt-4-turbo",
      // Reasoning serie “o”
      "o3", "o3-mini", "o1", "o1-mini", "o1-preview",
      // Legacy per compatibilità
      "gpt-3.5-turbo"
    ]
  },
  anthropic: {
    baseUrl: "https://api.anthropic.com/v1/messages",
    modelsUrl: "https://api.anthropic.com/v1/models",
    apiKeyEnv: "ANTHROPIC_API_KEY",
    headerName: "x-api-key",
    headerPrefix: "",
    supportsStreaming: true,
    supportsResponses: false,
    supportedModels: [
      // Linea Claude 3.x (IDs ufficiali noti e stabili)
      "claude-3-7-sonnet-20250219",
      "claude-3-5-sonnet-20241022",
      "claude-3-5-haiku-20241022",
      "claude-3-opus-20240229",
      "claude-3-haiku-20240307"
    ]
  },
  groq: {
    baseUrl: "https://api.groq.com/openai/v1/chat/completions",
    modelsUrl: "https://api.groq.com/openai/v1/models",
    apiKeyEnv: "GROQ_API_KEY",
    headerName: "Authorization",
    headerPrefix: "Bearer",
    supportsStreaming: true,
    supportsResponses: false,
    supportedModels: [
      // Produzione (console.groq.com/docs/models)
      "llama-3.3-70b-versatile",
      "llama-3.1-8b-instant",
      "openai/gpt-oss-120b",
      "openai/gpt-oss-20b",
      "meta-llama/llama-guard-4-12b",
      // Audio/STT (non chat ma utili in /models)
      "whisper-large-v3",
      "whisper-large-v3-turbo"
      // (Altri preview possono apparire dinamicamente via /v1/models)
    ]
  },
  mistral: {
    baseUrl: "https://api.mistral.ai/v1/chat/completions",
    modelsUrl: "https://api.mistral.ai/v1/models",
    apiKeyEnv: "MISTRAL_API_KEY",
    headerName: "Authorization",
    headerPrefix: "Bearer",
    supportsStreaming: true,
    supportsResponses: false,
    supportedModels: [
      // Linea stabile “latest”
      "mistral-small-latest",
      "mistral-medium-latest",
      "mistral-large-latest"
      // (Vision/Code dedicati come Pixtral/Codestral sono gestiti dal provider e
      //  appariranno dinamicamente se inclusi nella tua org/progetto)
    ]
  },
  xai: {
    baseUrl: "https://api.x.ai/v1/chat/completions",
    modelsUrl: "https://api.x.ai/v1/models",
    apiKeyEnv: "XAI_API_KEY",
    headerName: "Authorization",
    headerPrefix: "Bearer",
    supportsStreaming: true,
    supportsResponses: false,
    supportedModels: [
      // Rilasci 2025 (luglio+)
      "grok-4-0709",
      "grok-4",
      "grok-4-latest",
      "grok-4-fast",
      "grok-4-fast-non-reasoning-latest",
      "grok-4-fast-reasoning-latest",
      // Vision + Code
      "grok-2-vision-1212",
      "grok-vision-beta",
      "grok-code-fast-1",
      // Serie 3 (ancora disponibili)
      "grok-3",
      "grok-3-mini"
    ]
  }
};

// =========================
// UTILS
// =========================
function getProviderFromHeader(request) {
  return request.headers.get("x-provider");
}
__name(getProviderFromHeader, "getProviderFromHeader");

function getProviderForModel(model) {
  const modelLower = (model || "").toLowerCase();

  // xAI
  if (modelLower.includes("grok") || modelLower.startsWith("xai-")) return "xai";
  // Anthropic
  if (modelLower.startsWith("claude") || modelLower.includes("claude")) return "anthropic";
  // Mistral
  if (modelLower.includes("mistral")) return "mistral";
  // OpenAI (gpt-*, chatgpt-*, o*-series)
  if (
    modelLower.startsWith("gpt-") ||
    modelLower.includes("chatgpt") ||
    modelLower.startsWith("o1") ||
    modelLower.startsWith("o3") ||
    modelLower.startsWith("o2") // compat futuro
  ) return "openai";
  // Groq hosted open-weights (llama, mixtral, gemma, qwen, deepseek, gpt-oss)
  if (
    (modelLower.includes("llama") ||
     modelLower.includes("mixtral") ||
     modelLower.includes("gemma") ||
     modelLower.includes("qwen") ||
     modelLower.includes("deepseek") ||
     modelLower.includes("gpt-oss")) &&
    !modelLower.includes("/")
  ) return "groq";

  // Fallback: ricerca nelle liste statiche
  for (const [providerName, config] of Object.entries(PROVIDERS)) {
    if (config.supportedModels.some(m =>
      modelLower.includes(m.toLowerCase()) ||
      m.toLowerCase().includes(modelLower)
    )) {
      return providerName;
    }
  }
  return "openai";
}
__name(getProviderForModel, "getProviderForModel");

function buildProviderHeaders(providerName, apiKey) {
  const provider = PROVIDERS[providerName];
  const headers = {
    "User-Agent": "Cloudflare-Worker-LLM-Gateway/3.0"
  };
  if (provider.headerPrefix) {
    headers[provider.headerName] = `${provider.headerPrefix} ${apiKey}`;
  } else {
    headers[provider.headerName] = apiKey;
  }
  if (providerName === "anthropic") {
    headers["anthropic-version"] = "2023-06-01";
    headers["Content-Type"] = "application/json";
  }
  return headers;
}
__name(buildProviderHeaders, "buildProviderHeaders");

// =========================
// TRASFORMAZIONI
// =========================
function transformForAnthropic(body) {
  const messages = body.messages || [];
  const systemMessage = messages.find(m => m.role === "system");
  const userMessages = messages.filter(m => m.role !== "system");
  return {
    model: body.model,
    max_tokens: body.max_tokens || 1024,
    messages: userMessages,
    stream: !!body.stream,
    ...(systemMessage ? { system: systemMessage.content } : {})
  };
}
__name(transformForAnthropic, "transformForAnthropic");

function transformAnthropicResponse(anthropicResponse) {
  return {
    id: anthropicResponse.id || ("chatcmpl-" + Date.now()),
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: anthropicResponse.model,
    choices: [
      {
        index: 0,
        message: { role: "assistant", content: anthropicResponse?.content?.[0]?.text || "" },
        finish_reason: anthropicResponse.stop_reason === "end_turn" ? "stop" : "length"
      }
    ],
    usage: {
      prompt_tokens: anthropicResponse?.usage?.input_tokens || 0,
      completion_tokens: anthropropicResponse?.usage?.output_tokens || 0,
      total_tokens:
        (anthropicResponse?.usage?.input_tokens || 0) +
        (anthropicResponse?.usage?.output_tokens || 0)
    }
  };
}
__name(transformAnthropicResponse, "transformAnthropicResponse");

// Responses API -> Chat (non-stream)
function transformResponsesApiToChat(responsesApiResponse) {
  return {
    id: responsesApiResponse.id || ("chatcmpl-" + Date.now()),
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: responsesApiResponse.model,
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content: responsesApiResponse?.output?.text || responsesApiResponse?.output || ""
        },
        finish_reason: responsesApiResponse.status === "completed" ? "stop" : "length"
      }
    ],
    usage: responsesApiResponse.usage || {
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0
    }
  };
}
__name(transformResponsesApiToChat, "transformResponsesApiToChat");

// Chat -> Responses API (quando il client manda Chat ma si vuole usare /v1/responses)
function transformChatCompletionsToResponses(body) {
  const messages = body.messages || [];
  const lastUser = [...messages].reverse().find(m => m.role === "user");
  const input = lastUser ? lastUser.content : "";

  const systemMsgs = messages.filter(m => m.role === "system");
  const conversationHistory = messages.filter(m => m.role !== "system");

  const payload = {
    model: body.model,
    input,
    modalities: ["text"],
    metadata: {
      conversation_history: conversationHistory,
      system_context: systemMsgs.length ? systemMsgs[0].content : undefined
    }
  };

  if (body.stream) payload.stream = { mode: "text" };
  if (typeof body.max_output_tokens === "number") {
    payload.max_output_tokens = body.max_output_tokens;
  } else if (typeof body.max_tokens === "number") {
    payload.max_output_tokens = body.max_tokens;
  }
  if (body.response_format) payload.response_format = body.response_format;
  if (body.tools) payload.tools = body.tools;
  if (body.tool_choice) payload.tool_choice = body.tool_choice;

  return payload;
}
__name(transformChatCompletionsToResponses, "transformChatCompletionsToResponses");

// =========================
// STREAMING (SSE)
// =========================
async function handleStreamingResponse(response, providerName) {
  if (!response.body) {
    return new Response("Stream not available", { status: 502 });
  }

  const readable = new ReadableStream({
    start(controller) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      const encoder = new TextEncoder();

      const pump = async () => {
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value, { stream: true });

            if (providerName === "openai") {
              // OpenAI Responses API: convert specific events -> chat chunks
              const lines = chunk.split("\n");
              for (const line of lines) {
                if (!line.trim()) continue;
                if (!line.startsWith("data:")) {
                  // Passa-through eventuali righe non data:
                  controller.enqueue(encoder.encode(line + "\n"));
                  continue;
                }
                const data = line.slice(5).trim(); // after "data:"
                if (data === "[DONE]") {
                  controller.enqueue(encoder.encode("data: [DONE]\n\n"));
                  controller.close();
                  return;
                }
                try {
                  const parsed = JSON.parse(data);
                  // Eventi Responses API
                  if (parsed.type === "response.output_text.delta") {
                    const chatChunk = {
                      id: parsed.response_id || ("chatcmpl-" + Date.now()),
                      object: "chat.completion.chunk",
                      created: Math.floor(Date.now() / 1000),
                      model: parsed.model,
                      choices: [
                        {
                          index: 0,
                          delta: { content: parsed.delta || "" },
                          finish_reason: null
                        }
                      ]
                    };
                    controller.enqueue(
                      encoder.encode(`data: ${JSON.stringify(chatChunk)}\n\n`)
                    );
                  } else if (parsed.type === "response.completed") {
                    const chatChunk = {
                      id: parsed.response_id || ("chatcmpl-" + Date.now()),
                      object: "chat.completion.chunk",
                      created: Math.floor(Date.now() / 1000),
                      model: parsed.model,
                      choices: [
                        { index: 0, delta: {}, finish_reason: "stop" }
                      ]
                    };
                    controller.enqueue(
                      encoder.encode(`data: ${JSON.stringify(chatChunk)}\n\n`)
                    );
                    controller.enqueue(encoder.encode("data: [DONE]\n\n"));
                    controller.close();
                    return;
                  } else {
                    // Altri eventi: passthrough
                    controller.enqueue(encoder.encode(line + "\n"));
                  }
                } catch {
                  // Non JSON -> passthrough
                  controller.enqueue(encoder.encode(line + "\n"));
                }
              }
            } else if (providerName === "anthropic") {
              // Anthropic usa SSE con "event:" e "data:" – passthrough trasparente
              controller.enqueue(encoder.encode(chunk));
            } else {
              // Altri provider: passthrough trasparente del chunk
              controller.enqueue(value);
            }
          }
        } catch (err) {
          controller.error(err);
        } finally {
          reader.releaseLock();
        }
      };

      pump();
    }
  });

  return new Response(readable, {
    status: response.status,
    statusText: response.statusText,
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, x-provider"
    }
  });
}
__name(handleStreamingResponse, "handleStreamingResponse");

// =========================
// /v1/models (dinamico + aggregato)
// =========================
async function listModelsFromProvider(providerName, env) {
  const provider = PROVIDERS[providerName];
  const apiKey = env[provider.apiKeyEnv];
  if (!apiKey) return null; // nessuna chiave -> evita chiamata esterna

  const headers = buildProviderHeaders(providerName, apiKey);
  try {
    const res = await fetch(provider.modelsUrl, { method: "GET", headers });
    const data = await res.json();
    // Normalizza: alcune API ritornano {data: [...]}, altre la lista diretta
    const models = Array.isArray(data?.data) ? data.data : (Array.isArray(data) ? data : []);
    return models.map(m => ({
      id: m.id || m.name || m.model || "unknown",
      object: "model",
      created: Math.floor(Date.now() / 1000),
      owned_by: providerName
    }));
  } catch {
    return null;
  }
}

async function handleModelsEndpoint(request, env) {
  const url = new URL(request.url);
  const headerProvider = (getProviderFromHeader(request) || "").toLowerCase();
  const aggregate = url.searchParams.get("aggregate") === "1" || headerProvider === "all";

  if (aggregate) {
    // Aggrega da tutti i provider con chiave configurata; fallback alla lista statica se serve
    const results = [];
    for (const providerName of Object.keys(PROVIDERS)) {
      const dynamic = await listModelsFromProvider(providerName, env);
      if (dynamic && dynamic.length) {
        results.push(...dynamic);
      } else {
        // Fallback statico
        const fallback = PROVIDERS[providerName].supportedModels.map(id => ({
          id,
          object: "model",
          created: Math.floor(Date.now() / 1000),
          owned_by: providerName
        }));
        results.push(...fallback);
      }
    }
    const payload = { object: "list", data: results };
    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }

  // Non aggregato: usa provider esplicito o default OpenAI
  const providerName = headerProvider || "openai";
  const provider = PROVIDERS[providerName];

  if (!provider) {
    return new Response(JSON.stringify({ error: `Unsupported provider: ${providerName}` }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }

  const apiKey = env[provider.apiKeyEnv];
  if (!apiKey) {
    // Nessuna chiave -> restituisce fallback statico
    const payload = {
      object: "list",
      data: provider.supportedModels.map(id => ({
        id,
        object: "model",
        created: Math.floor(Date.now() / 1000),
        owned_by: providerName
      }))
    };
    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }

  // Forward alla /models del provider
  const headers = buildProviderHeaders(providerName, apiKey);
  try {
    const res = await fetch(provider.modelsUrl, { method: "GET", headers });
    const data = await res.json();
    return new Response(JSON.stringify(data), {
      status: res.status,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  } catch (e) {
    // Fallback statico in caso di errore
    const payload = {
      object: "list",
      data: provider.supportedModels.map(id => ({
        id,
        object: "model",
        created: Math.floor(Date.now() / 1000),
        owned_by: providerName
      }))
    };
    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }
}
__name(handleModelsEndpoint, "handleModelsEndpoint");

// =========================
// /v1/responses (preferito per OpenAI)
// =========================
async function handleResponsesEndpoint(request, env) {
  try {
    const bodyText = await request.text();
    const body = JSON.parse(bodyText || "{}");
    const model = body.model;

    if (!model) {
      return new Response(JSON.stringify({ error: "Model parameter is required" }), {
        status: 400, headers: { "Content-Type": "application/json" }
      });
    }

    const explicitProvider = (getProviderFromHeader(request) || "").toLowerCase();
    const providerName = explicitProvider || getProviderForModel(model);
    const provider = PROVIDERS[providerName];

    if (!provider) {
      return new Response(JSON.stringify({ error: `Unsupported provider: ${providerName}` }), {
        status: 400, headers: { "Content-Type": "application/json" }
      });
    }

    const apiKey = env[provider.apiKeyEnv];
    if (!apiKey) {
      return new Response(JSON.stringify({ error: `${providerName.toUpperCase()} API key not configured` }), {
        status: 500, headers: { "Content-Type": "application/json" }
      });
    }

    let targetUrl = provider.baseUrl;
    let requestBody = body;

    // Per OpenAI usiamo Responses API nativa
    if (providerName === "openai" && provider.supportsResponses) {
      targetUrl = provider.responsesUrl;
      // Il corpo è già in formato Responses API se il client l'ha inviato così.
      // Se il client ha mandato Chat format con /v1/responses, convertiamo:
      if (!body.input && Array.isArray(body.messages)) {
        requestBody = transformChatCompletionsToResponses(body);
      }
    } else {
      // Altri provider: se arrivano payload Responses (input/modalities), converti a Chat
      if (body.input && body.modalities) {
        const messages = [];
        if (body.metadata?.system_context) {
          messages.push({ role: "system", content: body.metadata.system_context });
        }
        if (Array.isArray(body.metadata?.conversation_history)) {
          messages.push(...body.metadata.conversation_history);
        } else {
          messages.push({ role: "user", content: body.input });
        }
        requestBody = { model: body.model, messages, stream: !!(body.stream && body.stream.mode === "text") };
        if (typeof body.max_output_tokens === "number") {
          requestBody.max_tokens = body.max_output_tokens;
        } else if (typeof body.max_tokens === "number") {
          requestBody.max_tokens = body.max_tokens;
        }
        if (body.response_format) requestBody.response_format = body.response_format;
        if (body.tools) requestBody.tools = body.tools;
        if (body.tool_choice) requestBody.tool_choice = body.tool_choice;
      }
    }

    if (providerName === "anthropic") {
      requestBody = transformForAnthropic(requestBody);
    }

    const headers = {
      "Content-Type": "application/json",
      ...buildProviderHeaders(providerName, apiKey)
    };

    const forwardedRequest = new Request(targetUrl, {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody)
    });

    const resp = await fetch(forwardedRequest);

    // Streaming?
    const wantsStream =
      !!requestBody.stream ||
      (!!body.stream && (body.stream === true || typeof body.stream === "object"));
    if (wantsStream) {
      return handleStreamingResponse(resp, providerName);
    }

    // Non-stream
    let responseData = await resp.json();
    if (providerName === "anthropic" && resp.ok) {
      responseData = transformAnthropicResponse(responseData);
    }
    // Se il client ha usato /v1/responses su provider non-OpenAI, rimappa nel formato Responses
    if (!(providerName === "openai" && provider.supportsResponses)) {
      if (body.input && body.modalities) {
        responseData = {
          id: responseData.id || ("resp-" + Date.now()),
          model: responseData.model,
          status: "completed",
          output: responseData?.choices?.[0]?.message?.content || "",
          usage: responseData.usage
        };
      }
    }

    return new Response(JSON.stringify(responseData), {
      status: resp.status,
      statusText: resp.statusText,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-provider"
      }
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: "Internal server error", details: message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }
}
__name(handleResponsesEndpoint, "handleResponsesEndpoint");

// =========================
// /v1/chat/completions (compat)
// =========================
async function handleChatCompletionsEndpoint(request, env) {
  try {
    const bodyText = await request.text();
    const body = JSON.parse(bodyText || "{}");
    const model = body.model;

    if (!model) {
      return new Response(JSON.stringify({ error: "Model parameter is required" }), {
        status: 400, headers: { "Content-Type": "application/json" }
      });
    }

    const explicitProvider = (getProviderFromHeader(request) || "").toLowerCase();
    const providerName = explicitProvider || getProviderForModel(model);
    const provider = PROVIDERS[providerName];

    if (!provider) {
      return new Response(JSON.stringify({ error: `Unsupported provider: ${providerName}` }), {
        status: 400, headers: { "Content-Type": "application/json" }
      });
    }

    const apiKey = env[provider.apiKeyEnv];
    if (!apiKey) {
      return new Response(JSON.stringify({ error: `${providerName.toUpperCase()} API key not configured` }), {
        status: 500, headers: { "Content-Type": "application/json" }
      });
    }

    let requestBody = body;
    if (providerName === "anthropic") {
      requestBody = transformForAnthropic(body);
    }
    if (providerName === "openai") {
      const lowerModel = (requestBody.model || "").toLowerCase();
      const requiresCompletion = lowerModel.includes("gpt-5") || lowerModel.startsWith("o1") || lowerModel.startsWith("o3");
      if (requiresCompletion && typeof requestBody.max_tokens === "number") {
        requestBody.max_completion_tokens = requestBody.max_tokens;
        delete requestBody.max_tokens;
      }
    }

    const headers = {
      "Content-Type": "application/json",
      ...buildProviderHeaders(providerName, apiKey)
    };

    const forwardedRequest = new Request(provider.baseUrl, {
      method: "POST",
      headers,
      body: JSON.stringify(requestBody)
    });

    const resp = await fetch(forwardedRequest);

    // Streaming?
    if (requestBody.stream) {
      return handleStreamingResponse(resp, providerName);
    }

    let responseData = await resp.json();
    if (providerName === "anthropic" && resp.ok) {
      responseData = transformAnthropicResponse(responseData);
    }

    return new Response(JSON.stringify(responseData), {
      status: resp.status,
      statusText: resp.statusText,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-provider"
      }
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: "Internal server error", details: message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }
}
__name(handleChatCompletionsEndpoint, "handleChatCompletionsEndpoint");

// =========================
/** FETCH HANDLER (Module Worker) */
// =========================
const index_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, x-provider"
        }
      });
    }

    // Routing
    if (url.pathname === "/v1/models" && request.method === "GET") {
      return handleModelsEndpoint(request, env);
    }

    if (url.pathname === "/v1/responses" && request.method === "POST") {
      return handleResponsesEndpoint(request, env);
    }

    if (url.pathname === "/v1/chat/completions" && request.method === "POST") {
      return handleChatCompletionsEndpoint(request, env);
    }

    return new Response("Not Found", { status: 404 });
  }
};

// 👉 Export per Module Worker (nessun addEventListener necessario)
export { index_default as default };
