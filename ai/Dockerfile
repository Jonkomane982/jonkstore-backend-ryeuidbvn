# Stage 1: Build/Base
FROM python:3.10-slim-bullseye

# Install system dependencies
# swi-prolog-nox is used for a smaller footprint on servers (no X11)
RUN apt-get update && apt-get install -y --no-install-recommends \
    swi-prolog-nox \
    swi-prolog-dev \
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
# Defaulting to 10000 if PORT is not set
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
