# llama.cpp Build Repository

NVIDIA Driver 470 (CUDA 11.4) 환경에서 폐쇄망 OpenShift에 배포하기 위한 llama.cpp 빌드 레포지터리입니다.

## 빌드 정보

- **CUDA 버전**: 11.4.3
- **호환 드라이버**: NVIDIA Driver 470
- **타겟 모델**: Qwen3
- **베이스 이미지**: nvidia/cuda:11.4.3-devel-ubuntu20.04

## 자동 빌드

이 레포지터리는 GitHub Actions를 통해 자동으로 빌드됩니다:

- `main` 또는 `master` 브랜치에 push 시 자동 빌드
- `Dockerfile` 또는 워크플로우 파일 변경 시 트리거
- 빌드된 이미지는 GitHub Container Registry (ghcr.io)에 저장

## 이미지 태그

- `latest`: 최신 빌드 (기본 브랜치)
- `cuda11.4-driver470`: CUDA 11.4 / Driver 470 특정 버전
- `main-{sha}`: 커밋 SHA별 버전

## 사용 방법

### 1. 이미지 Pull

```bash
# 공개 네트워크에서
docker pull ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470

# 폐쇄망 환경으로 전송
docker save ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470 -o llama-cpp.tar
# 파일을 폐쇄망으로 복사 후
docker load -i llama-cpp.tar
```

### 2. OpenShift에서 실행

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-cpp-qwen3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-cpp
  template:
    metadata:
      labels:
        app: llama-cpp
    spec:
      containers:
      - name: llama-cpp
        image: ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470
        command: ["/app/llama.cpp/build/bin/llama-server"]
        args:
          - "-m"
          - "/app/models/qwen3-model.gguf"
          - "--host"
          - "0.0.0.0"
          - "--port"
          - "8080"
          - "-ngl"
          - "99"  # GPU 레이어 수
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: model-storage
          mountPath: /app/models
        resources:
          limits:
            nvidia.com/gpu: 1
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: qwen3-model-pvc
```

### 3. 모델 파일 준비

Qwen3 모델을 GGUF 형식으로 변환하여 볼륨에 저장:

```bash
# 컨테이너 내부에서 모델 변환 (필요시)
docker run --rm -it --gpus all \
  -v /path/to/qwen3:/models \
  ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470 \
  /app/llama.cpp/convert.py /models/qwen3 --outtype f16
```

### 4. 로컬 테스트

```bash
docker run --rm -it --gpus all \
  -p 8080:8080 \
  -v /path/to/models:/app/models \
  ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470 \
  /app/llama.cpp/build/bin/llama-server \
  -m /app/models/qwen3-model.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  -ngl 99
```

## 빌드 포함 내용

- llama.cpp (최신 버전)
- CUDA 11.4 툴킷
- 필요한 빌드 도구
- Python3 및 pip

## 참고사항

- GPU 메모리에 따라 `-ngl` (GPU 레이어 수) 조정 필요
- OpenShift에서 GPU 사용을 위해 Node Feature Discovery 및 GPU Operator 설치 필요
- 폐쇄망 환경에서는 이미지를 tar 파일로 전송 후 import

## 문제 해결

### CUDA 버전 확인
```bash
docker run --rm ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470 nvcc --version
```

### llama.cpp 버전 확인
```bash
docker run --rm ghcr.io/jonggeun2001/build-repo:cuda11.4-driver470 \
  /app/llama.cpp/build/bin/llama-server --version
```
