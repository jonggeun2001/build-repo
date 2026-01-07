# NVIDIA Driver 470 compatible (CUDA 11.4)
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    libcurl4-openssl-dev \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone and build llama.cpp
RUN git clone https://github.com/ggerganov/llama.cpp.git && \
    cd llama.cpp && \
    mkdir build && \
    cd build && \
    cmake .. -DLLAMA_CUBLAS=ON -DCMAKE_CUDA_ARCHITECTURES=native && \
    cmake --build . --config Release -j$(nproc)

# Create model directory
RUN mkdir -p /app/models

# Copy llama.cpp binaries to /app
RUN cp -r /app/llama.cpp/build/bin/* /app/ || \
    (cp /app/llama.cpp/build/llama-* /app/ && \
     cp /app/llama.cpp/build/main /app/ 2>/dev/null || true && \
     cp /app/llama.cpp/build/server /app/ 2>/dev/null || true)

# Set the default command to run llama.cpp server
WORKDIR /app
ENV LLAMA_CPP_PATH=/app/llama.cpp

# Expose default llama.cpp server port
EXPOSE 8080

# Default command (can be overridden)
CMD ["/app/llama.cpp/build/bin/llama-server", "--help"]
