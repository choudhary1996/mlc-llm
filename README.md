[![MLC-LLM-CI](https://github.com/choudhary1996/mlc-llm/actions/workflows/cicd.yaml/badge.svg)](https://github.com/choudhary1996/mlc-llm/actions/workflows/cicd.yaml)
[![Release](https://github.com/choudhary1996/mlc-llm/actions/workflows/release.yaml/badge.svg)](https://github.com/choudhary1996/mlc-llm/actions/workflows/release.yaml)
[![Docker](https://github.com/choudhary1996/mlc-llm/actions/workflows/docker.yaml/badge.svg)](https://github.com/choudhary1996/mlc-llm/actions/workflows/docker.yaml)

# MLC-LLM CI/CD
multipurpose Docker image, automated tests, CI/CD with GHCR and GitHub releases.

---

## 1. Multipurpose Docker Image

| Requirement | Status | Notes |
|-------------|--------|--------|
| **Development environment** (interactive shell, source mounted, dev tools) | `docker run -it --rm -v $(pwd):/workspace IMAGE /bin/bash`; `WORKDIR /workspace`; dev-init.sh; pytest, black, isort, pylint, mypy, build, wheel, etc. |
| **Build environment** (non-interactive entrypoint for compile + package) | Default `ENTRYPOINT` is `build-entrypoint.sh`: config → cmake/ninja → pip install -e . → validate. Optional `BUILD_WHEEL` for wheel output. |
| **Built & pushed to GHCR automatically** | `docker.yaml` builds and pushes to `ghcr.io/${{ github.repository }}` on push to `main` (when Dockerfile/docker workflow change) and on `workflow_dispatch`. |

**Build-from-source doc alignment (Dockerfile):**

- CMake ≥ 3.24 ✅ (pip install "cmake>=3.24")
- Git ✅ (apt)
- Rust/Cargo ✅ (apt; Hugging Face tokenizer)
- GPU runtime ✅ (Vulkan by default; CUDA via build-arg)
- Step 2: configure & build ✅ (config.cmake + cmake + ninja)
- Step 3: install via Python ✅ (`pip install -e .` in `python/`)
- Step 4: validate ✅ (libs, `mlc_llm chat -h`, `import mlc_llm`)

**Minor:** Doc conda example uses Python 3.13; Dockerfile defaults to 3.10.

---

## 2. Automated Tests

| Requirement | Status | Notes |
|-------------|--------|--------|
| Tests run in CI | ✅ Met | `test-linux` and `test-windows` run pytest (unit tests, excluding integration/op). |
| Tests **gate** further stages | ⚠️ **Gap** | Tests are run but do **not** fail the job when they fail. |

**Gap details:**

- **ci.yaml:** The “Run unit tests” step has `continue-on-error: true` (line 369), so a failing pytest still leaves `test-linux` as success. `ci-success` then sees “success” even when tests failed.
- **release.yaml:** The pytest step uses `|| echo "::warning::Some tests failed"` (line 289), so the step succeeds even when tests fail. The release job still runs.

So “tests must run and gate further stages” is only partially satisfied until test failures actually fail the job.

---

## 3. GitHub Actions CI/CD Pipeline

| Requirement | Status | Notes |
|-------------|--------|--------|
| Test-driven deployment | ⚠️ Partial | Flow is test → release, but tests don’t fail the job (see above). |
| Build MLC-LLM Python package | ✅ Met | Both `ci.yaml` and `release.yaml` build (cmake + ninja, then `pip install -e .`). |
| Publish wheels as GitHub Release | ✅ Met | `release.yaml` on `v*` tags (and manual dispatch) creates a GitHub Release and attaches wheels. |
| Linux x64 | ✅ Met | `ubuntu-22.04`, wheel artifact `wheel-linux-x64`, included in release. |
| Windows x64 | ✅ Met | `windows-latest`, wheel artifact `wheel-windows-x64`, included in release. |

---

## Summary

- **Dockerfile:** Fulfills “multipurpose” (dev + build) and aligns with the build-from-source doc. Image is built and pushed to GHCR by `docker.yaml`.
- **Automated tests:** Run in CI and release workflows, but **do not gate** because of `continue-on-error` and `|| echo`; fixing that is required for true test gating.
- **CI/CD:** Builds and GitHub releases for Linux x64 and Windows x64 are in place; making tests strictly gate (fail the job on failure) will satisfy “test-driven deployment” and “tests gate further stages.”

Recommended change: remove `continue-on-error` from the test step in `ci.yaml` and remove the `|| echo "::warning::..."` in `release.yaml` so that test failures fail the job and block `ci-success` and release.



# MLC-LLM CI/CD & Build Specifications

This repository utilizes a multi-stage **GitHub Actions** pipeline to automate the development lifecycle, ensuring reproducible builds across Linux and Windows.

## 📊 Pipeline Data & Specifications

| Feature | Specification |
| --- | --- |
| **Orchestrator** | GitHub Actions |
| **Configuration** | `.github/workflows/cicd.yaml` |
| **Container Registry** | GitHub Container Registry (GHCR) |
| **Artifacts** | Python Wheels (`.whl`) |
| **Release Strategy** | Tag-based (`v*`) |

### 🔄 Workflow Triggers

| Event | Branch/Tag | Action |
| --- | --- | --- |
| **Push** | `main` | Full Build & Test (Linux + Windows) |
| **Pull Request** | Any | Build Check (No Release) |
| **Tag** | `v*` | **Publish Release** to GitHub Releases |
| **Manual Trigger**|

---

## Build Matrix & Environment

The pipeline uses a matrix strategy to handle cross-platform compilation in parallel.

### 🐧 Linux (Containerized)

* **Runner:** `ubuntu-latest`
* **Environment:** Custom Docker Image (`ghcr.io/owner/mlc-env:latest`)
* **Compiler:** GCC/G++ (via Docker)
* **Python:** 3.13
* **Build Script:** `.devops/scripts/build-mlc.sh`

### 🪟 Windows (Native)

* **Runner:** `windows-latest`
* **Environment:** Native Host
* **Compiler:** MSVC (Microsoft Visual C++)
* **Python:** 3.13
* **Key Config:** `cmake -A x64` with manual `config.cmake` generation.

---

##  Job Architecture

1. **`setup-env`**
* **Input:** `.devops/Dockerfile`
* **Output:** Docker Image pushed to GHCR.
* **Cache:** Uses Docker Layer Caching to speed up subsequent runs.


2. **`build` (Matrix)**
* **Linux:** Pulls image → Mounts Source → Runs `build-mlc` → Validates (`.so` checks) → Uploads Wheel.
* **Windows:** Setups MSVC → Compiles DLLs → Packages Wheel → Uploads Wheel.


3. **`release`**
* **Input:** Artifacts from `build` job.
* **Output:** GitHub Release with downloadable `.whl` files.



---

## 📂 Key File Reference

| File Path | Purpose |
| --- | --- |
| `.github/workflows/cicd.yaml` | **Master CI Configuration.** Defines jobs, secrets, and permissions. |
| `.devops/Dockerfile` | **Build Environment.** Ubuntu 22.04 + Python 3.13 + Rust + CMake. |
| `.devops/scripts/build-mlc.sh` | **Linux Builder.** Automates CMake config and compilation. |
| `.devops/scripts/validate-mlc.sh` | **Test Script.** Verifies shared libraries and CLI functionality. |

##  Quick Commands

**Run Local Build (Linux/Docker):**

```bash
docker build -t mlc-dev -f .devops/Dockerfile .
docker run --rm -v $(pwd):/workspace mlc-dev build-mlc

```

**Verify Artifacts:**

```bash
docker run --rm -v $(pwd):/workspace mlc-dev validate-mlc

```






<div align="center">

# MLC LLM

[![Installation](https://img.shields.io/badge/docs-latest-green)](https://llm.mlc.ai/docs/)
[![License](https://img.shields.io/badge/license-apache_2-blue)](https://github.com/mlc-ai/mlc-llm/blob/main/LICENSE)
[![Join Discoard](https://img.shields.io/badge/Join-Discord-7289DA?logo=discord&logoColor=white)](https://discord.gg/9Xpy2HGBuD)
[![Related Repository: WebLLM](https://img.shields.io/badge/Related_Repo-WebLLM-fafbfc?logo=github)](https://github.com/mlc-ai/web-llm/)

**Universal LLM Deployment Engine with ML Compilation**

[Get Started](https://llm.mlc.ai/docs/get_started/quick_start) | [Documentation](https://llm.mlc.ai/docs) | [Blog](https://blog.mlc.ai/)

</div>

## About

MLC LLM is a machine learning compiler and high-performance deployment engine for large language models.  The mission of this project is to enable everyone to develop, optimize, and deploy AI models natively on everyone's platforms. 

<div align="center">
<table style="width:100%">
  <thead>
    <tr>
      <th style="width:15%"> </th>
      <th style="width:20%">AMD GPU</th>
      <th style="width:20%">NVIDIA GPU</th>
      <th style="width:20%">Apple GPU</th>
      <th style="width:24%">Intel GPU</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Linux / Win</td>
      <td>✅ Vulkan, ROCm</td>
      <td>✅ Vulkan, CUDA</td>
      <td>N/A</td>
      <td>✅ Vulkan</td>
    </tr>
    <tr>
      <td>macOS</td>
      <td>✅ Metal (dGPU)</td>
      <td>N/A</td>
      <td>✅ Metal</td>
      <td>✅ Metal (iGPU)</td>
    </tr>
    <tr>
      <td>Web Browser</td>
      <td colspan=4>✅ WebGPU and WASM </td>
    </tr>
    <tr>
      <td>iOS / iPadOS</td>
      <td colspan=4>✅ Metal on Apple A-series GPU</td>
    </tr>
    <tr>
      <td>Android</td>
      <td colspan=2>✅ OpenCL on Adreno GPU</td>
      <td colspan=2>✅ OpenCL on Mali GPU</td>
    </tr>
  </tbody>
</table>
</div>

MLC LLM compiles and runs code on MLCEngine -- a unified high-performance LLM inference engine across the above platforms. MLCEngine provides OpenAI-compatible API available through REST server, python, javascript, iOS, Android, all backed by the same engine and compiler that we keep improving with the community.

## Get Started

Please visit our [documentation](https://llm.mlc.ai/docs/) to get started with MLC LLM.
- [Installation](https://llm.mlc.ai/docs/install/mlc_llm)
- [Quick start](https://llm.mlc.ai/docs/get_started/quick_start)
- [Introduction](https://llm.mlc.ai/docs/get_started/introduction)

## Citation

Please consider citing our project if you find it useful:

```bibtex
@software{mlc-llm,
    author = {{MLC team}},
    title = {{MLC-LLM}},
    url = {https://github.com/mlc-ai/mlc-llm},
    year = {2023-2025}
}
```

The underlying techniques of MLC LLM include:

<details>
  <summary>References (Click to expand)</summary>

  ```bibtex
  @inproceedings{tensorir,
      author = {Feng, Siyuan and Hou, Bohan and Jin, Hongyi and Lin, Wuwei and Shao, Junru and Lai, Ruihang and Ye, Zihao and Zheng, Lianmin and Yu, Cody Hao and Yu, Yong and Chen, Tianqi},
      title = {TensorIR: An Abstraction for Automatic Tensorized Program Optimization},
      year = {2023},
      isbn = {9781450399166},
      publisher = {Association for Computing Machinery},
      address = {New York, NY, USA},
      url = {https://doi.org/10.1145/3575693.3576933},
      doi = {10.1145/3575693.3576933},
      booktitle = {Proceedings of the 28th ACM International Conference on Architectural Support for Programming Languages and Operating Systems, Volume 2},
      pages = {804–817},
      numpages = {14},
      keywords = {Tensor Computation, Machine Learning Compiler, Deep Neural Network},
      location = {Vancouver, BC, Canada},
      series = {ASPLOS 2023}
  }

  @inproceedings{metaschedule,
      author = {Shao, Junru and Zhou, Xiyou and Feng, Siyuan and Hou, Bohan and Lai, Ruihang and Jin, Hongyi and Lin, Wuwei and Masuda, Masahiro and Yu, Cody Hao and Chen, Tianqi},
      booktitle = {Advances in Neural Information Processing Systems},
      editor = {S. Koyejo and S. Mohamed and A. Agarwal and D. Belgrave and K. Cho and A. Oh},
      pages = {35783--35796},
      publisher = {Curran Associates, Inc.},
      title = {Tensor Program Optimization with Probabilistic Programs},
      url = {https://proceedings.neurips.cc/paper_files/paper/2022/file/e894eafae43e68b4c8dfdacf742bcbf3-Paper-Conference.pdf},
      volume = {35},
      year = {2022}
  }

  @inproceedings{tvm,
      author = {Tianqi Chen and Thierry Moreau and Ziheng Jiang and Lianmin Zheng and Eddie Yan and Haichen Shen and Meghan Cowan and Leyuan Wang and Yuwei Hu and Luis Ceze and Carlos Guestrin and Arvind Krishnamurthy},
      title = {{TVM}: An Automated {End-to-End} Optimizing Compiler for Deep Learning},
      booktitle = {13th USENIX Symposium on Operating Systems Design and Implementation (OSDI 18)},
      year = {2018},
      isbn = {978-1-939133-08-3},
      address = {Carlsbad, CA},
      pages = {578--594},
      url = {https://www.usenix.org/conference/osdi18/presentation/chen},
      publisher = {USENIX Association},
      month = oct,
  }
  ```
</details>
