FROM python:3.12-slim

RUN apt-get update && \
    apt-get install --yes --no-install-recommends ghdl gcc make && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

ENV PYTHONPATH=/workspace/verification
CMD ["python", "verification/run.py", "all"]
