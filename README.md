# llama.cpp + SYCL + Qwen3.6-35B-A3B on Intel Arc Pro B70

[English](#english) | [Русский](#русский)

---

## English

Two launchers — one for Windows (PowerShell) and one for Linux (Bash) — that start
[llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` on the **SYCL backend** and serve
**Qwen3.6-35B-A3B (UD-Q4_K_M)** entirely on the GPU of an **Intel Arc Pro B70**. Drop the llama.cpp SYCL
build into `Llama\`, drop the model into `Model\`, run the script, and you get an OpenAI-compatible endpoint
on `http://127.0.0.1:8010`.

### Which script to use

| OS | Script | Shell |
| --- | --- | --- |
| Windows 11 x64 | `start-qwen3.6-35b-a3b.ps1` | PowerShell |
| Linux x64 | `start-qwen3.6-35b-a3b.sh` | Bash |

Both do exactly the same thing: resolve the files next to themselves, set the SYCL environment, clean up a
stale server on port 8010 and launch `llama-server` with the same flags. Pick the one for your OS.

### Why these scripts exist

I wrote them to make it easy to run **llama.cpp + SYCL + Qwen3.6-35B-A3B** on an Intel Arc Pro B70.

The reason such a launcher is needed at all is that llama.cpp out of the box does not use SYCL: the generic
binaries and the "just follow the README" path lead you to the **Vulkan** backend. SYCL is the backend that
actually gets the most out of Xe2 GPUs, but it needs a dedicated build plus a couple of environment
variables and launch flags that are easy to get wrong. And even when you do pick Vulkan on purpose, there is
a known problem — [ggml-org/llama.cpp#28721](https://github.com/ggml-org/llama.cpp/issues/28721) — where the
Vulkan backend loses a large amount of performance, so token generation gets noticeably slower than it
should be on this class of hardware.

So: take the official SYCL release build, set up the SYCL environment, and launch `llama-server` with a sane
set of flags for this specific model and card. That is all this repository does.

### Requirements

Common:

- Intel Arc Pro B70 (32 GB) — or another Arc/Xe2 GPU with enough VRAM; the model occupies ~21 GB
- A reasonably recent Intel graphics driver that provides the Level Zero runtime the SYCL backend talks to

Windows:

- Windows 11 x64, PowerShell 5.1+ (the one shipped with Windows is fine)
- No separate Intel oneAPI installation: the Windows SYCL archive already ships everything it needs
  (`sycl9.dll`, `ur_*.dll`, oneAPI MKL, TBB, OpenMP)

Linux:

- Bash, `iproute2` (`ss`) — or `lsof` as a fallback — to detect a server holding the port
- The **Intel oneAPI runtime is required**: unlike the Windows archive, the Linux archive contains only
  llama.cpp's own libraries. The prebuilt `llama-server` links against `libsycl.so.9` (oneAPI DPC++ runtime),
  `libmkl_*.so` (oneAPI MKL), `libtbb.so.12` (TBB) and `libze_loader.so.1` (Level Zero loader). The easiest
  way is the Intel oneAPI Base Toolkit or the `intel-oneapi-runtime-*` packages from Intel's apt repository,
  plus the Intel GPU runtime (`intel-level-zero-gpu` / Ubuntu `libze1`, `libtbb12`)
- Your user must be allowed to use the GPU — put it into the `render` and `video` groups

### Setup

#### 1. llama.cpp SYCL build → `Llama\` / `Llama/`

**Windows** — download and unzip the SYCL build into a folder named **`Llama`** next to the script:

- [llama.cpp releases, b11576 (page 9)](https://github.com/ggml-org/llama.cpp/releases?page=9#release-b11576)
  — grab `llama-b11576-bin-win-sycl-x64.zip`
- direct link: <https://github.com/ggml-org/llama.cpp/releases/tag/b11576>

**Linux** — download the Ubuntu SYCL build and unpack it into `Llama/`:

- `llama-b11576-bin-ubuntu-sycl-fp16-x64.tar.gz` — **recommended**: half-precision math goes through the XMX
  engines, which is faster, at a tiny precision cost
- `llama-b11576-bin-ubuntu-sycl-fp32-x64.tar.gz` — full fp32 accuracy, slower

```bash
mkdir -p Llama
tar -xzf llama-b11576-bin-ubuntu-sycl-fp16-x64.tar.gz --strip-components=1 -C Llama
```

A newer `llama-bXXXXX-bin-*-sycl-*.zip` / `.tar.gz` build works too — just keep the word `sycl` in the file
name, otherwise you will get the Vulkan or CPU build. Windows ships only one SYCL variant, Linux ships fp16
and fp32.

The result must be exactly `Llama\llama-server.exe` (Windows) or `Llama/llama-server` (Linux), i.e. the
contents of the archive go directly into `Llama`.

#### 2. Model → `Model\` / `Model/`

Download the GGUF and save it as `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` in the `Model` folder:

- [unsloth/Qwen3.6-35B-A3B-GGUF — Qwen3.6-35B-A3B-UD-Q4_K_M.gguf](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/blob/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf)
- direct download: <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf>
  (~21 GB)

#### 3. Layout

```
intel-arc-pro-b70-llama-cpp-sycl-qwen3.6-35b-a3b\
├─ start-qwen3.6-35b-a3b.ps1             Windows launcher (PowerShell)
├─ start-qwen3.6-35b-a3b.sh              Linux launcher (Bash)
├─ Llama\                                (gitignored)  SYCL build
│  └─ llama-server.exe                   (Linux: llama-server)
├─ Model\                                (gitignored)  the GGUF
│  └─ Qwen3.6-35B-A3B-UD-Q4_K_M.gguf
└─ Cache\                                (gitignored)  created by the script
   ├─ llama-slots\
   └─ sycl\
```

`Llama\`, `Model\` and `Cache\` are listed in `.gitignore` — nothing of that ends up in the repository.

#### 4. Run

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-qwen3.6-35b-a3b.ps1
```

Linux:

```bash
chmod +x start-qwen3.6-35b-a3b.sh   # not needed if you cloned the repository normally
./start-qwen3.6-35b-a3b.sh
```

Then:

| What | Where |
| --- | --- |
| Web UI | <http://127.0.0.1:8010> |
| OpenAI-compatible API | `http://127.0.0.1:8010/v1` (model name `qwen3.6-35b-a3b`) |
| Health | <http://127.0.0.1:8010/health> |
| Prometheus metrics | <http://127.0.0.1:8010/metrics> |

Loading the model takes roughly 25 seconds; the script's log tells you when it is up.

### What the scripts do

**Environment (SYCL), identical on both OSes:**

| Variable | Value | Why |
| --- | --- | --- |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:gpu` | Pins the backend to the Level Zero driver instead of OpenCL |
| `ZES_ENABLE_SYSMAN` | `1` | Lets llama.cpp read GPU memory/frequency counters via Sysman |
| `SYCL_CACHE_PERSISTENT` | `1` | Reuses compiled SYCL kernels across runs |
| `SYCL_CACHE_DIR` | `.\Cache\sycl` (`./Cache/sycl`) | Where those kernels are cached (speeds up the first tokens a lot) |

**Launch flags, identical on both OSes:**

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
| `--slot-save-path` | `.\Cache\llama-slots` (`./Cache/llama-slots`) | Saved slots (prompt/KV snapshots) |
| `--metrics` | | Expose `/metrics` |

Both scripts also clean up after themselves: a stale `llama-server` still holding port 8010 (for example
from a previous run of the same script) is stopped before a new one starts, while processes serving other
ports are left alone. The Windows script checks port owners first and then leftover processes by name; the
Linux script uses `ss` (or `lsof`) plus `/proc` and ignores the caller's directory. The Linux script finishes
with `exec`, so `Ctrl+C` stops the server itself.

### Why Qwen3.6-35B-A3B works so well on an Intel Arc Pro B70

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

### Notes and troubleshooting

- **`llama-server` / `Model not found`** — the scripts expect the layout from step 3. If you unpacked the
  archive one level too deep, move the contents of `Llama\llama-b11576-bin-win-sycl-x64\` (or
  `Llama/llama-b11576/`) up into `Llama`.
- **Check that the GPU is visible to SYCL** — Windows: run `Llama\sycl-ls.exe`. Linux: run
  `Llama/llama-server --list-devices` (or `sycl-ls` from the oneAPI install). Your Arc card should show up
  under the Level Zero backend.
- **`error while loading shared libraries: libsycl.so.9` (Linux)** — the oneAPI runtime is missing. Check
  what is actually missing with `ldd Llama/llama-server | grep 'not found'`, then install the oneAPI Base
  Toolkit or the `intel-oneapi-runtime-*` packages; if you installed it into a non-standard prefix, run the
  script from a shell where `source /opt/intel/oneapi/setvars.sh` has been executed.
- **`libze_loader.so.1` is missing (Linux)** — install the Level Zero runtime (Intel GPU runtime /
  `intel-level-zero-gpu`, Ubuntu `libze1`).
- **`Permission denied` when running the Linux script** — `chmod +x start-qwen3.6-35b-a3b.sh`. The
  repository keeps the executable bit and LF line endings for `.sh` (see `.gitattributes`).
- **Out of memory** — either lower `-c` (context) or use a smaller quantization. At `-c 131072` with a `q8_0`
  KV cache the model plus cache use most of the 32 GB.
- **Speed** — if you run a Vulkan build instead of the SYCL one, expect a large regression
  ([#28721](https://github.com/ggml-org/llama.cpp/issues/28721)).
- The launchers cover Windows and Linux x64. llama.cpp builds for macOS as well, but SYCL does not target it
  and there is no script here for it.

### References

- llama.cpp — <https://github.com/ggml-org/llama.cpp>
- SYCL backend performance issue on Vulkan — <https://github.com/ggml-org/llama.cpp/issues/28721>
- llama.cpp builds — <https://github.com/ggml-org/llama.cpp/releases>
- Qwen3.6-35B-A3B GGUF (unsloth) — <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF>

---

## Русский

Два скрипта запуска — под Windows (PowerShell) и под Linux (Bash), — которые стартуют
[llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` на **бэкенде SYCL** и обслуживают
**Qwen3.6-35B-A3B (UD-Q4_K_M)** целиком на GPU **Intel Arc Pro B70**. Кладёте SYCL-сборку llama.cpp в
`Llama\`, модель — в `Model\`, запускаете скрипт и получаете OpenAI-совместимый эндпоинт на
`http://127.0.0.1:8010`.

### Какой скрипт брать

| ОС | Скрипт | Оболочка |
| --- | --- | --- |
| Windows 11 x64 | `start-qwen3.6-35b-a3b.ps1` | PowerShell |
| Linux x64 | `start-qwen3.6-35b-a3b.sh` | Bash |

Оба делают ровно одно и то же: находят файлы рядом с собой, настраивают SYCL-окружение, убирают зависший
сервер на порту 8010 и запускают `llama-server` с одинаковыми флагами. Берите тот, что под вашу ОС.

### Зачем эти скрипты

Я сделал их, чтобы помочь запустить **llama.cpp + SYCL + Qwen3.6-35B-A3B** на Intel Arc Pro B70.

Скрипты вообще понадобились потому, что llama.cpp «сама по себе» не умеет работать с SYCL: обычные сборки и
путь «просто как написано в README» приводят к бэкенду **Vulkan**. А выжимает максимум из GPU Xe2 именно
SYCL — но для него нужна отдельная сборка плюс пара переменных окружения и флагов запуска, в которых легко
ошибиться. И даже если сознательно выбрать Vulkan, есть известная проблема —
[ggml-org/llama.cpp#28721](https://github.com/ggml-org/llama.cpp/issues/28721) — из-за которой
Vulkan-бэкенд теряет значительную часть производительности, и генерация токенов идёт заметно медленнее, чем
должна на таком железе.

То есть: берём официальную SYCL-сборку, настраиваем SYCL-окружение и запускаем `llama-server` с разумным
набором флагов под конкретную модель и карту. Это всё, что делает репозиторий.

### Требования

Общее:

- Intel Arc Pro B70 (32 ГБ) — либо другая Arc/Xe2 с достаточным объёмом видеопамяти; модель занимает ~21 ГБ
- Достаточно свежий драйвер Intel Graphics, который даёт runtime Level Zero, нужный SYCL-бэкенду

Windows:

- Windows 11 x64, PowerShell 5.1+ (встроенный в Windows подходит)
- Отдельная установка Intel oneAPI не нужна: в Windows-архиве SYCL-сборки уже есть всё необходимое
  (`sycl9.dll`, `ur_*.dll`, oneAPI MKL, TBB, OpenMP)

Linux:

- Bash, `iproute2` (`ss`) — или `lsof` как запасной вариант — чтобы найти процесс, держащий порт
- **Нужен runtime Intel oneAPI**: в отличие от Windows-архива, Linux-архив содержит только библиотеки
  самого llama.cpp. Готовый `llama-server` линкуется с `libsycl.so.9` (runtime oneAPI DPC++), `libmkl_*.so`
  (oneAPI MKL), `libtbb.so.12` (TBB) и `libze_loader.so.1` (загрузчик Level Zero). Проще всего поставить
  Intel oneAPI Base Toolkit или пакеты `intel-oneapi-runtime-*` из apt-репозитория Intel, плюс runtime для
  GPU Intel (`intel-level-zero-gpu` / в Ubuntu `libze1`, `libtbb12`)
- Пользователь должен иметь доступ к GPU — добавьте его в группы `render` и `video`

### Установка

#### 1. Сборка llama.cpp с SYCL → `Llama\` / `Llama/`

**Windows** — скачайте и распакуйте SYCL-сборку в папку **`Llama`** рядом со скриптом:

- [релизы llama.cpp, b11576 (страница 9)](https://github.com/ggml-org/llama.cpp/releases?page=9#release-b11576)
  — нужен файл `llama-b11576-bin-win-sycl-x64.zip`
- прямая ссылка: <https://github.com/ggml-org/llama.cpp/releases/tag/b11576>

**Linux** — скачайте Ubuntu-сборку с SYCL и распакуйте её в `Llama/`:

- `llama-b11576-bin-ubuntu-sycl-fp16-x64.tar.gz` — **рекомендуется**: вычисления в половинной точности
  идут через движки XMX, это быстрее, ценой совсем небольшой потери точности
- `llama-b11576-bin-ubuntu-sycl-fp32-x64.tar.gz` — полная точность fp32, но медленнее

```bash
mkdir -p Llama
tar -xzf llama-b11576-bin-ubuntu-sycl-fp16-x64.tar.gz --strip-components=1 -C Llama
```

Более свежая сборка `llama-bXXXXX-bin-*-sycl-*.zip` / `.tar.gz` тоже подойдёт — главное, чтобы в имени файла
было слово `sycl`, иначе это будет сборка под Vulkan или CPU. В Windows SYCL-вариант только один, в Linux —
fp16 и fp32.

В итоге должно получиться ровно `Llama\llama-server.exe` (Windows) или `Llama/llama-server` (Linux), то
есть содержимое архива кладём прямо в `Llama`.

#### 2. Модель → `Model\` / `Model/`

Скачайте GGUF и сохраните его как `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf` в папке `Model`:

- [unsloth/Qwen3.6-35B-A3B-GGUF — Qwen3.6-35B-A3B-UD-Q4_K_M.gguf](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/blob/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf)
- прямая ссылка на скачивание: <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf>
  (~21 ГБ)

#### 3. Раскладка

```
intel-arc-pro-b70-llama-cpp-sycl-qwen3.6-35b-a3b\
├─ start-qwen3.6-35b-a3b.ps1             запуск под Windows (PowerShell)
├─ start-qwen3.6-35b-a3b.sh              запуск под Linux (Bash)
├─ Llama\                                (в .gitignore)  SYCL-сборка
│  └─ llama-server.exe                   (в Linux: llama-server)
├─ Model\                                (в .gitignore)  сама модель (GGUF)
│  └─ Qwen3.6-35B-A3B-UD-Q4_K_M.gguf
└─ Cache\                                (в .gitignore)  создаётся скриптом
   ├─ llama-slots\
   └─ sycl\
```

`Llama\`, `Model\` и `Cache\` перечислены в `.gitignore` — ничего из этого в репозиторий не попадает.

#### 4. Запуск

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-qwen3.6-35b-a3b.ps1
```

Linux:

```bash
chmod +x start-qwen3.6-35b-a3b.sh   # не понадобится, если репозиторий склонирован обычным способом
./start-qwen3.6-35b-a3b.sh
```

Дальше:

| Что | Где |
| --- | --- |
| Веб-интерфейс | <http://127.0.0.1:8010> |
| OpenAI-совместимый API | `http://127.0.0.1:8010/v1` (имя модели `qwen3.6-35b-a3b`) |
| Health | <http://127.0.0.1:8010/health> |
| Метрики Prometheus | <http://127.0.0.1:8010/metrics> |

Загрузка модели занимает примерно 25 секунд; по логу скрипта видно, когда сервер поднялся.

### Что делают скрипты

**Окружение (SYCL), одинаковое в обеих ОС:**

| Переменная | Значение | Зачем |
| --- | --- | --- |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:gpu` | Привязывает бэкенд к драйверу Level Zero вместо OpenCL |
| `ZES_ENABLE_SYSMAN` | `1` | Позволяет llama.cpp читать счётчики памяти/частоты GPU через Sysman |
| `SYCL_CACHE_PERSISTENT` | `1` | Переиспользует скомпилированные SYCL-ядра между запусками |
| `SYCL_CACHE_DIR` | `.\Cache\sycl` (`./Cache/sycl`) | Где эти ядра кэшируются (сильно ускоряет первые токены) |

**Флаги запуска, одинаковые в обеих ОС:**

| Флаг | Значение | Зачем |
| --- | --- | --- |
| `-ngl` | `99` | Все слои на GPU |
| `-c` | `131072` | Контекст 128K |
| `-ctk` / `-ctv` | `q8_0` | Квантованный KV-кэш — позволяет уложить контекст 128K в 32 ГБ |
| `-fa` | `on` | Flash attention, нужен для квантованного KV-кэша |
| `-b` / `-ub` | `8192` / `4096` | Batch и micro-batch для обработки промпта |
| `-t` | `8` | Потоки CPU (подобрано под 6 P-ядер + 4 E-ядра; подстройте под свой процессор) |
| `--parallel` | `1` | По одному запросу за раз, весь контекст — ему |
| `--jinja` | | Брать chat-шаблон из метаданных GGUF |
| `--no-warmup` | | Пропустить прогревочный прогон, SYCL-кэш и так решает вопрос первого запуска |
| `--no-reasoning-preserve` | | Не подмешивать предыдущие рассуждения обратно в промпт |
| `--slot-save-path` | `.\Cache\llama-slots` (`./Cache/llama-slots`) | Сохранённые слоты (снимки промпта/KV) |
| `--metrics` | | Отдавать `/metrics` |

Оба скрипта ещё и убирают за собой: зависший `llama-server`, всё ещё держащий порт 8010 (например, от
прошлого запуска того же скрипта), останавливается перед стартом нового, а процессы на других портах не
трогаются. Windows-скрипт сначала смотрит владельцев порта, а затем — зависшие процессы по имени;
Linux-скрипт использует `ss` (или `lsof`) и `/proc` и не зависит от текущего каталога. Linux-скрипт
завершается через `exec`, поэтому `Ctrl+C` останавливает сам сервер.

### Почему Qwen3.6-35B-A3B так хорошо идёт на Intel Arc Pro B70

Qwen3.6-35B-A3B показывает высокую производительность на Intel Arc Pro B70 благодаря сочетанию разреженной
архитектуры Mixture-of-Experts (MoE) и сбалансированных аппаратных характеристик видеокарты. Ключевой фактор —
модель активирует лишь малую часть параметров для каждого токена, что идеально ложится на возможности B70 по
памяти и вычислениям.

**Архитектура MoE: главный секрет эффективности.** Qwen3.6-35B-A3B — это модель со 35 млрд общих параметров,
но для генерации каждого токена активируется лишь около 3 млрд. В ней используется 256 экспертов, из которых
для каждого токена выбираются 8 маршрутизируемых и 1 общий. Это означает, что вычислительная нагрузка и
объём данных, которые нужно прочитать из памяти во время генерации, на порядок ниже, чем у плотной модели с
35 млрд параметров.

**Идеальное совпадение с возможностями B70.** Аппаратная конфигурация Intel Arc Pro B70 хорошо подходит для
такой разреженной нагрузки:

- **Достаточный объём памяти (32 ГБ GDDR6)** — модель в популярном квантовании UD-Q4_K_M занимает около
  20.6 ГБ, что позволяет полностью разместить её в памяти одной карты и избежать медленного обмена с
  системной RAM. Версии в INT4 или INT8 также комфортно помещаются в 32 ГБ.
- **Высокая пропускная способность памяти (~608 ГБ/с)** — для генерации токенов критична скорость чтения
  весов. Хотя 608 ГБ/с — не рекордный показатель, для чтения весов всего ~3 млрд активных параметров этого
  более чем достаточно, чтобы обеспечить высокую скорость.
- **Тензорные ядра XMX (256 движков)** — архитектура Xe2 «Battlemage» оснащена 256 XMX-движками, которые
  эффективно ускоряют матричные умножения, лежащие в основе работы каждого эксперта.

Проверено на: Intel Core i5-12600KF, 64 ГБ RAM, Intel Arc Pro B70 32 ГБ (драйвер 32.0.101.8976), Windows 11.

### Заметки и решение проблем

- **`llama-server` / `Model not found`** — скрипты ожидают раскладку из шага 3. Если архив распаковался на
  уровень глубже, перенесите содержимое `Llama\llama-b11576-bin-win-sycl-x64\` (или `Llama/llama-b11576/`)
  наверх, в `Llama`.
- **Проверить, что GPU виден для SYCL** — Windows: запустите `Llama\sycl-ls.exe`. Linux: запустите
  `Llama/llama-server --list-devices` (или `sycl-ls` из поставки oneAPI). Карта Arc должна отображаться у
  бэкенда Level Zero.
- **`error while loading shared libraries: libsycl.so.9` (Linux)** — нет runtime oneAPI. Посмотрите, чего
  именно не хватает: `ldd Llama/llama-server | grep 'not found'`, затем поставьте Intel oneAPI Base Toolkit
  или пакеты `intel-oneapi-runtime-*`; если oneAPI установлен в нестандартный префикс, запускайте скрипт из
  оболочки, где выполнен `source /opt/intel/oneapi/setvars.sh`.
- **Не хватает `libze_loader.so.1` (Linux)** — поставьте runtime Level Zero (Intel GPU runtime /
  `intel-level-zero-gpu`, в Ubuntu `libze1`).
- **`Permission denied` при запуске Linux-скрипта** — `chmod +x start-qwen3.6-35b-a3b.sh`. В репозитории
  для `.sh` сохраняются бит исполнения и переводы строк LF (см. `.gitattributes`).
- **Не хватает памяти** — уменьшите `-c` (контекст) или возьмите более сильное квантование. При
  `-c 131072` и `q8_0`-KV-кэше модель вместе с кэшем занимают почти все 32 ГБ.
- **Скорость** — если запустить сборку под Vulkan вместо SYCL, ждите большого падения производительности
  ([#28721](https://github.com/ggml-org/llama.cpp/issues/28721)).
- Скрипты рассчитаны на Windows и Linux x64. Сборки llama.cpp есть и под macOS, но SYCL туда не
  нацелен, и скрипта для него здесь нет.

### Ссылки

- llama.cpp — <https://github.com/ggml-org/llama.cpp>
- Проблема производительности SYCL-бэкенда на Vulkan — <https://github.com/ggml-org/llama.cpp/issues/28721>
- Сборки llama.cpp — <https://github.com/ggml-org/llama.cpp/releases>
- Qwen3.6-35B-A3B GGUF (unsloth) — <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF>
