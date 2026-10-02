FROM paperist/texlive-ja:latest

# LinuxのパッケージマネージャーでPython3とpipをインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-setuptools \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 👇 ここに numpy を追加しました
RUN pip3 install --no-cache-dir --break-system-packages \
    ipykernel \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn