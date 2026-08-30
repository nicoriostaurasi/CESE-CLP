FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        ghdl \
        make \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/cocotb \
    && /opt/cocotb/bin/pip install --no-cache-dir -r /tmp/requirements.txt

ENV PATH="/opt/cocotb/bin:${PATH}"
WORKDIR /work/Guia_TP/cocotb
