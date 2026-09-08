# Use the latest stable Python image based on Debian Bookworm
FROM python:3.10-slim-bookworm

# Install system dependencies for SWI-Prolog and PostgreSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    swi-prolog \
    build-essential \
    libpq-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create a non-root user for production security
RUN useradd -m jonkai && chown -R jonkai:jonkai /app
USER jonkai

# Install Python dependencies
COPY --chown=jonkai:jonkai requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy the rest of the application code
COPY --chown=jonkai:jonkai . .

# Ensure the local bin is in the PATH
ENV PATH="/home/jonkai/.local/bin:${PATH}"
ENV PYTHONUNBUFFERED=1

# Run the FastAPI application
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
