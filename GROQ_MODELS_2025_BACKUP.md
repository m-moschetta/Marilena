# Groq Models 2025 - Complete Backup

## Official Groq Models (2025) - Updated January 2025

### Current Available Models (In order of capability)

#### 1. DeepSeek R1 Distill Series (Reasoning Models - BEST CHOICE)
- **API Name**: `deepseek-r1-distill-llama-70b`
- **Speed**: 260 tokens/sec
- **Context**: 131K tokens  
- **Performance**: CodeForces 1633, MATH 94.5%, AIME 70.0%
- **Pricing**: $0.75 input / $0.99 output per 1M tokens
- **Best for**: Complex reasoning, mathematical problems, advanced coding

- **API Name**: `deepseek-r1-distill-qwen-32b`
- **Speed**: 388 tokens/sec (FASTEST reasoning model)
- **Context**: 128K tokens
- **Performance**: CodeForces 1691, AIME 83.3%
- **Pricing**: $0.59 input / $0.79 output per 1M tokens
- **Best for**: Ultra-fast reasoning, production reasoning tasks

- **API Name**: `deepseek-r1-distill-qwen-14b`
- **Speed**: ~500+ tokens/sec
- **Context**: 64K tokens
- **Performance**: AIME 69.7, MATH 93.9%, CodeForces 1481
- **Pricing**: $0.15 input / $0.15 output per 1M tokens
- **Best for**: Cost-effective reasoning, lightweight reasoning tasks

- **API Name**: `deepseek-r1-distill-qwen-1.5b`
- **Speed**: ~800+ tokens/sec (ULTRA FAST)
- **Context**: 32K tokens
- **Performance**: Good for simple reasoning
- **Pricing**: $0.04 input / $0.04 output per 1M tokens  
- **Best for**: Simple reasoning, ultra-high speed, cost-sensitive

#### 2. Qwen 2.5 Series (Fast General Purpose)
- **API Name**: `qwen2.5-32b-instruct`
- **Speed**: 397 tokens/sec
- **Context**: 128K tokens
- **Features**: Tool calling, JSON mode, structured outputs
- **Best for**: General tasks, tool use, structured data

- **API Name**: `qwen2.5-72b-instruct`
- **Speed**: ~200 tokens/sec
- **Context**: 128K tokens
- **Features**: Enhanced capabilities, better reasoning
- **Best for**: Complex tasks requiring balance of speed and capability

#### 3. Llama 3.3/3.1 Series (Meta - Versatile)
- **API Name**: `llama-3.3-70b-versatile`
- **Speed**: ~250 tokens/sec
- **Context**: 128K tokens
- **Best for**: General purpose, balanced performance

- **API Name**: `llama-3.1-405b-reasoning`
- **Speed**: ~100 tokens/sec
- **Context**: 128K tokens
- **Best for**: Most complex tasks, highest capability

- **API Name**: `llama-3.1-70b-versatile`
- **Speed**: ~300 tokens/sec
- **Context**: 128K tokens
- **Best for**: Good balance of size and performance

- **API Name**: `llama-3.1-8b-instant`
- **Speed**: ~800 tokens/sec
- **Context**: 128K tokens
- **Best for**: Fast simple tasks, high throughput

#### 4. Mixtral Series (Mistral AI - Multilingual)
- **API Name**: `mixtral-8x7b-32768`
- **Speed**: ~500 tokens/sec
- **Context**: 32K tokens
- **Features**: Mixture of Experts, excellent multilingual
- **Best for**: Multilingual tasks, coding, creative writing

#### 5. Gemma Series (Google - Efficient)
- **API Name**: `gemma2-9b-it`
- **Speed**: ~600 tokens/sec
- **Context**: 8K tokens
- **Best for**: Efficient instruction following

- **API Name**: `gemma-7b-it`
- **Speed**: ~700 tokens/sec
- **Context**: 8K tokens
- **Best for**: Lightweight but capable

## Model Selection Guide

### For Advanced Reasoning & Mathematics
1. **deepseek-r1-distill-llama-70b** - Most capable reasoning
2. **deepseek-r1-distill-qwen-32b** - Best speed/capability balance
3. **deepseek-r1-distill-qwen-14b** - Cost-effective reasoning

### For General AI Tasks
1. **qwen2.5-32b-instruct** - Excellent all-around with tool use
2. **llama-3.3-70b-versatile** - Reliable general purpose
3. **llama-3.1-70b-versatile** - Good balance

### For Speed & High Throughput
1. **deepseek-r1-distill-qwen-1.5b** - Ultra-fast reasoning
2. **llama-3.1-8b-instant** - Fastest general purpose
3. **gemma2-9b-it** - Efficient and fast

### For Multilingual & Coding
1. **mixtral-8x7b-32768** - Best multilingual support
2. **qwen2.5-32b-instruct** - Strong coding with tools
3. **llama-3.1-70b-versatile** - Good coding support

## Key Features by Model Type

### Reasoning Models (DeepSeek R1 Distill)
- **Chain-of-Thought (CoT) thinking** - Explicit reasoning steps
- **Mathematical problem solving** - MATH, AIME benchmarks
- **Advanced coding** - CodeForces performance
- **Step-by-step explanations** - Transparent reasoning process

### Tool Use Models
- **qwen2.5-32b-instruct** - Function calling, JSON mode
- **llama-3.1-405b-reasoning** - Advanced tool integration
- **mixtral-8x7b-32768** - Code execution capabilities

## API Endpoint
Base URL: `https://api.groq.com/openai/v1`

## Best Practices for Reasoning Models
- Set temperature between 0.5-0.7 for DeepSeek R1 models
- Avoid system prompts, include instructions in user messages
- Use zero-shot prompting for best results
- Monitor token usage (reasoning generates many tokens)

## Implementation Notes
- All models support OpenAI-compatible API
- Reasoning models show explicit thinking process
- Ultra-low latency compared to other providers
- No prompt caching (fast inference makes it unnecessary)

## Last Updated
January 2025 - Based on official Groq documentation

## Sources
- https://console.groq.com/docs/models
- https://groq.com/groqcloud-makes-deepseek-r1-distill-llama-70b-available/
- Official Groq API documentation