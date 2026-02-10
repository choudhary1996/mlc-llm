# =========================================================
# Multipurpose Dev + Build Image — Production Stable
# =========================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# ---------------------------------------------------------
# System dependencies
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    pkg-config \
    libssl-dev \
    libtinfo-dev \
    libxml2-dev \
    zlib1g-dev \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Install Miniforge (CI safe, better than Miniconda)
# ---------------------------------------------------------
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p $CONDA_DIR \
 && rm /tmp/miniforge.sh \
 && conda clean -afy

SHELL ["bash", "-c"]

# ---------------------------------------------------------
# Enable libmamba solver (fast + reliable)
# ---------------------------------------------------------
RUN conda install -n base -y conda-libmamba-solver && \
    conda config --set solver libmamba

# ---------------------------------------------------------
# Create build environment (FIXED)
# ---------------------------------------------------------
RUN conda create -y -n mlc-chat-venv -c conda-forge \
    python=3.12 \
    "cmake>=3.24" \
    rust \
    git \
    pip \
    && conda clean -afy

# ---------------------------------------------------------
# Activate env for following RUN steps
# ---------------------------------------------------------
SHELL ["conda", "run", "-n", "mlc-chat-venv", "/bin/bash", "-c"]

# ---------------------------------------------------------
# Python build tools
# ---------------------------------------------------------
RUN pip install --upgrade \
    pip \
    setuptools \
    wheel \
    build \
    pytest

WORKDIR /workspace

CMD ["/bin/bash"]
