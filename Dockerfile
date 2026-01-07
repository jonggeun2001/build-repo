# ============================================
# Stage 1: Builder (CUDA devel for compilation)
# ============================================
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CMake 3.28.1 (llama.cpp requires 3.18+)
RUN wget -q https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-linux-x86_64.sh && \
    chmod +x cmake-3.28.1-linux-x86_64.sh && \
    ./cmake-3.28.1-linux-x86_64.sh --skip-license --prefix=/usr/local && \
    rm cmake-3.28.1-linux-x86_64.sh

# Clone llama.cpp (shallow clone to reduce size)
WORKDIR /app
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA support for A100 (compute capability 8.0)
WORKDIR /app/llama.cpp
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    mkdir build && cd build && \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH} \
    cmake .. \
        -DLLAMA_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="80" \
        -DCMAKE_BUILD_TYPE=Release && \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH} \
    cmake --build . --config Release -j$(nproc) && \
    rm /usr/local/cuda/lib64/stubs/libcuda.so.1

# Collect all required shared libraries for runtime
RUN mkdir -p /app/runtime-libs && \
    ldd /app/llama.cpp/build/bin/llama-server | grep "=> /" | awk '{print $3}' | \
    xargs -I {} cp -v {} /app/runtime-libs/ || true

# ============================================
# Stage 2: Runtime (CUDA runtime, much smaller)
# ============================================
FROM nvidia/cuda:11.4.3-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app
RUN mkdir -p /app/models

# Copy built binaries from builder
COPY --from=builder /app/llama.cpp/build/bin/ /app/bin/

# Copy all runtime dependencies collected by ldd
COPY --from=builder /app/runtime-libs/ /usr/local/lib/

# Copy llama.cpp shared libraries
COPY --from=builder /app/llama.cpp/build/ggml/src/libggml*.so* /usr/local/lib/
COPY --from=builder /app/llama.cpp/build/src/libllama.so* /usr/local/lib/

# Update library cache
RUN ldconfig

# Set environment variables
ENV PATH=/app/bin:${PATH}

# Expose default llama.cpp server port
EXPOSE 8080

# Default command
CMD ["llama-server", "--help"]
