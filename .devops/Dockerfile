FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=/usr/local/bin:$CONDA_DIR/bin:$PATH

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    pkg-config \
    libssl-dev \
    libtinfo-dev \
    libxml2-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p $CONDA_DIR \
 && rm /tmp/miniforge.sh \
 && conda clean -afy

SHELL ["bash", "-c"]

RUN conda install -n base -y conda-libmamba-solver && \
    conda config --set solver libmamba

RUN conda create -y -n mlc-chat-venv -c conda-forge \
    python=3.12 \
    "cmake>=3.24" \
    rust \
    git \
    pip \
    && conda clean -afy

WORKDIR /workspace
COPY . /workspace

COPY .devops/build-mlc.sh /usr/local/bin/build-mlc
COPY .devops/validate-mlc.sh /usr/local/bin/validate-mlc

RUN chmod +x /usr/local/bin/build-mlc \
 && chmod +x /usr/local/bin/validate-mlc

CMD ["bash"]
