# Stage 1: Build/Base
FROM python:3.10-slim-bullseye

# Install system dependencies
# libswipl8 is required for SWI-Prolog
RUN apt-get update && apt-get install -y --no-install-recommends \
    swi-prolog \
    libswipl-dev \
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
ENV JONKAI_DATABASE_URL=""

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose internal API port
EXPOSE 8000

# Start application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
