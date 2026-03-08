# Setup
## Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh
## Install packages with UV
uv sync


# Run Airflow Locally
docker compose -f docker-compose-airflow.yaml up -d