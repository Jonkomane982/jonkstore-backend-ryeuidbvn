# Stage 1: Build/Base
FROM python:3.10-slim-bullseye

# Install system dependencies
# We use swi-prolog which includes the necessary runtime for pyswip
RUN apt-get update && apt-get install -y --no-install-recommends \
    swi-prolog \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create a non-root user
RUN useradd -m jonkai && chown -R jonkai:jonkai /app
USER jonkai

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy application code
COPY --chown=jonkai:jonkai . .

# Environment configuration
ENV PATH="/home/jonkai/.local/bin:${PATH}"
ENV PYTHONUNBUFFERED=1

# Start application using the dynamic Render port
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
