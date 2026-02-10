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
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Install Miniforge (CI safe)
# ---------------------------------------------------------
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p $CONDA_DIR \
 && rm /tmp/miniforge.sh \
 && conda clean -afy

SHELL ["bash", "-c"]

# ---------------------------------------------------------
# Faster solver
# ---------------------------------------------------------
RUN conda install -n base -y conda-libmamba-solver && \
    conda config --set solver libmamba

# ------------------------------
