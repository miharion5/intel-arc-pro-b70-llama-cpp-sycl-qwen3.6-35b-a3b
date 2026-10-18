# llama.cpp + SYCL + Qwen3.6-35B-A3B on Intel Arc Pro B70

A single PowerShell script that starts [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server`
on the **SYCL backend** and serves **Qwen3.6-35B-A3B (UD-Q4_K_M)** entirely on the GPU of an
**Intel Arc Pro B70**. Drop the llama.cpp SYCL build into `Llama\`, drop the model into `Model\`, run the
script, and you get an OpenAI-compatible endpoint on `http://127.0.0.1:8010`.

## Why this script exists

I wrote it to make it easy to run **llama.cpp + SYCL + Qwen3.6-35B-A3B** on an Intel Arc Pro B70.

The reason such a script is needed at all is that llama.cpp out of the box does not use SYCL: the generic
Windows binaries and the "just follow the README" path lead you to the **Vulkan** backend. SYCL is the
backend that actually gets the most out of Xe2 GPUs, but it needs a dedicated build plus a couple of
environment variables and launch flags that are easy to get wrong. And even when you do pick Vulkan on
purpose, there is a known problem — [ggml-org/llama.cpp#28721](https://github.com/ggml-org/llama.cpp/issues/28721) —
where the Vulkan backend loses a large amount of performance, so token generation gets noticeably slower
than it should be on this class of hardware.

So: take the official SYCL release build, set up the SYCL environment, and launch `llama-server` with a
sane set of flags for this specific model and card. That is all this repository does.

## Requirements

- Windows 11 x64
- Intel Arc Pro B70 (32 GB) — or another Arc/Xe2 GPU with enough VRAM; ~21 GB is occupied by the model
- A reasonably recent Intel graphics driver (it provides the Level Zero runtime that the SYCL backend talks to)
- PowerShell 5.1+ (the one shipped with Windows is fine)

No separate Intel oneAPI installation is required: the SYCL release archive already ships everything it
needs (`sycl9.dll`, `ur_loader.dll`, `ur_adapter_level_zero.dll`, oneAPI MKL, TBB, OpenMP). You only need
the GPU driver.

## Setup

### 1. llama.cpp SYCL build → `Llama\`

Download the SYCL build from the llama.cpp releases and unzip it into a folder named **`Llama`** right next
to the script:

- [llama.cpp releases, b11576 (page 9)](https://github.com/ggml-org/llama.cpp/releases?page=9#release-b11576)
  — grab `llama-b11576-bin-win-sycl-x64.zip`
- direct link: <https://github.com/ggml-org/llama.cpp/releases/tag/b11576>

A newer `llama-bXXXXX-bin-win-sycl-x64.zip` build works too — just keep the word `sycl` in the file name,
otherwise you will get the Vulkan or CPU build.

The result must be exactly `Llama\llama-server.exe`, i.e. the contents of the archive go into `Llama\`.

### 2. Model → `Model\`

Download the GGUF and save it as `Model\Qwen3.6-35B-A3B-UD-Q4_K_M.gguf`:

- [unsloth/Qwen3.6-35B-A3B-GGUF — Qwen3.6-35B-A3B-UD-Q4_K_M.gguf](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/blob/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf)
- direct download: <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf>
  (~21 GB)

### 3. Layout

```
intel-arc-pro-b70-llama-cpp-sycl-qwen3.6-35b-a3b\
├─ start-qwen3.6-35b-a3b.ps1
├─ Llama\                                (gitignored)  llama.cpp SYCL build
│  └─ llama-server.exe
├─ Model\                                (gitignored)  the GGUF
│  └─ Qwen3.6-35B-A3B-UD-Q4_K_M.gguf
└─ Cache\                                (gitignored)  created by the script
   ├─ llama-slots\
   └─ sycl\
```

`Llama\`, `Model\` and `Cache\` are listed in `.gitignore` — nothing of that ends up in the repository.

### 4. Run

```powershell
powershell -ExecutionPolicy Bypass -File .\start-qwen3.6-35b-a3b.ps1
```

Then:

| What | Where |
| --- | --- |
| Web UI | <http://127.0.0.1:8010> |
| OpenAI-compatible API | `http://127.0.0.1:8010/v1` (model name `qwen3.6-35b-a3b`) |
| Health | <http://127.0.0.1:8010/health> |
| Prometheus metrics | <http://127.0.0.1:8010/metrics> |

Loading the model takes roughly 25 seconds; the script's log tells you when it is up.

## What the script does

**Environment (SYCL):**

| Variable | Value | Why |
| --- | --- | --- |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:gpu` | Pins the backend to the Level Zero driver instead of OpenCL |
| `ZES_ENABLE_SYSMAN` | `1` | Lets llama.cpp read GPU memory/frequency counters via Sysman |
| `SYCL_CACHE_PERSISTENT` | `1` | Reuses compiled SYCL kernels across runs |
| `SYCL_CACHE_DIR` | `.\Cache\sycl` | Where those kernels are cached (speeds up the first tokens a lot) |

**Launch flags:**

| Flag | Value | Why |
| --- | --- | --- |
| `-ngl` | `99` | All layers on the GPU |
| `-c` | `131072` | 128K context |
| `-ctk` / `-ctv` | `q8_0` | Quantized KV cache — keeps 128K context inside 32 GB |
| `-fa` | `on` | Flash attention, needed for the quantized KV cache |
| `-b` / `-ub` | `8192` / `4096` | Batch and micro-batch for prompt processing |
| `-t` | `8` | CPU threads (tuned for a 6 P-core + 4 E-core CPU; adjust to your own) |
| `--parallel` | `1` | One request at a time, the whole context for it |
| `--jinja` | | Use the chat template from the GGUF metadata |
| `--no-warmup` | | Skip the warm-up pass, the SYCL cache already handles the first run |
| `--no-reasoning-preserve` | | Do not feed previous reasoning back into the prompt |
| `--slot-save-path` | `.\Cache\llama-slots` | Saved slots (prompt/KV snapshots) |
| `--metrics` | | Expose `/metrics` |

It also cleans up after itself: a stale `llama-server` still holding port 8010 (for example from a previous
run of this script) is stopped before starting a new one. Processes serving other ports are left alone.

## Why Qwen3.6-35B-A3B works so well on an Intel Arc Pro B70

Qwen3.6-35B-A3B delivers high performance on the Intel Arc Pro B70 thanks to the combination of a sparse
Mixture-of-Experts (MoE) architecture and the card's well-balanced hardware. The key factor is that the model
activates only a small fraction of its parameters for every token, which maps almost perfectly onto what the
B70 can offer in terms of memory and compute.

**MoE architecture: the main secret of the efficiency.** Qwen3.6-35B-A3B has 35 billion total parameters, but
only about 3 billion are activated to generate each token. It uses 256 experts, of which 8 routed experts
plus 1 shared expert are selected per token. That means the compute load and the amount of data that has to
be read from memory during generation are an order of magnitude lower than for a dense 35B model.

**An almost ideal match with the B70's capabilities.** The hardware configuration of the Intel Arc Pro B70
fits this sparse workload very well:

- **Enough memory (32 GB GDDR6)** — in the popular UD-Q4_K_M quantization the model takes about 20.6 GB, so
  it fits entirely in the memory of a single card with no slow spillover to system RAM. INT4 and INT8
  versions fit into 32 GB comfortably as well.
- **High memory bandwidth (~608 GB/s)** — token generation is bound by how fast the weights can be read.
  Although 608 GB/s is not a record-setting figure, it is more than enough to stream the weights of just
  ~3 billion active parameters per token and still sustain a high generation speed.
- **XMX tensor cores (256 engines)** — the Xe2 "Battlemage" architecture comes with 256 XMX engines that
  efficiently accelerate the matrix multiplications behind every expert.

Tested on: Intel Core i5-12600KF, 64 GB RAM, Intel Arc Pro B70 32 GB (driver 32.0.101.8976), Windows 11.

## Notes and troubleshooting

- **`llama-server.exe not found` / `Model not found`** — the script expects the layout from step 3. If you
  unpacked the archive one level too deep, move the contents of `Llama\llama-b11576-bin-win-sycl-x64\` up
  into `Llama\`.
- **Check that the GPU is visible to SYCL:** run `Llama\sycl-ls.exe`. You should see your Arc card under the
  Level Zero backend.
- **Out of memory** — either lower `-c` (context) or use a smaller quantization. At `-c 131072` with a `q8_0`
  KV cache the model plus cache use most of the 32 GB.
- **Speed** — if you run a Vulkan build instead of the SYCL one, expect a large regression
  ([#28721](https://github.com/ggml-org/llama.cpp/issues/28721)).
- The script is Windows/PowerShell. llama.cpp supports SYCL on Linux as well, but the paths and the launch
  wrapper here are Windows-specific.

## References

- llama.cpp — <https://github.com/ggml-org/llama.cpp>
- SYCL backend performance issue on Vulkan — <https://github.com/ggml-org/llama.cpp/issues/28721>
- llama.cpp builds — <https://github.com/ggml-org/llama.cpp/releases>
- Qwen3.6-35B-A3B GGUF (unsloth) — <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF>
