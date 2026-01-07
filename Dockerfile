# NVIDIA Driver 470 compatible (CUDA 11.4) for A100 GPU
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies and CMake 3.24+
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    libcurl4-openssl-dev \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install latest CMake (llama.cpp requires 3.18+)
RUN wget -q https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-linux-x86_64.sh && \
    chmod +x cmake-3.28.1-linux-x86_64.sh && \
    ./cmake-3.28.1-linux-x86_64.sh --skip-license --prefix=/usr/local && \
    rm cmake-3.28.1-linux-x86_64.sh

# Install Python packages for model conversion (Qwen3 support)
RUN pip3 install --no-cache-dir \
    numpy \
    torch \
    transformers \
    sentencepiece \
    protobuf

# Set working directory
WORKDIR /app

# Clone llama.cpp (separate layer for better caching)
RUN git clone https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA support for A100 (compute capability 8.0)
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. \
        -DLLAMA_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="80" \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --config Release -j$(nproc)

# Create model directory
RUN mkdir -p /app/models

# Set environment variables
ENV LLAMA_CPP_PATH=/app/llama.cpp
ENV PATH=/app/llama.cpp/build/bin:${PATH}

# Expose default llama.cpp server port
EXPOSE 8080

# Set working directory
WORKDIR /app

# Default command (can be overridden at runtime)
CMD ["llama-server", "--help"]
