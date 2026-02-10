FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# Base system deps
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    pkg-config \
    libssl-dev \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
 && bash /tmp/miniconda.sh -b -p $CONDA_DIR \
 && rm /tmp/miniconda.sh

# Create build env
RUN conda create -y -n mlc-chat-venv -c conda-forge \
    "cmake>=3.24" \
    rust \
    git \
    python=3.13 \
    pip

SHELL ["conda", "run", "-n", "mlc-chat-venv", "/bin/bash", "-c"]

RUN pip install --upgrade \
    pip \
    setuptools \
    wheel \
    build \
    pytest

WORKDIR /workspace
CMD ["/bin/bash"]
