import os
import sys
from pathlib import Path

import psycopg

MAX_LOG_BYTES = 500_000


def required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"Required environment variable {name} is not set")
    return value


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: store_build_log.py <build-output-log-path>")

    log_path = Path(sys.argv[1])
    log_bytes = log_path.read_bytes() if log_path.is_file() else b"Build output artifact was unavailable."
    truncated = len(log_bytes) > MAX_LOG_BYTES
    if truncated:
        log_bytes = b"[Earlier output truncated to keep the final 500 KB.]\n" + log_bytes[-MAX_LOG_BYTES:]

    values = (
        required_env("REPOSITORY"),
        int(required_env("RUN_ID")),
        int(required_env("RUN_ATTEMPT")),
        required_env("COMMIT_SHA"),
        required_env("SOURCE_REF"),
        required_env("BUILD_STATUS"),
        os.environ.get("DEPLOY_STATUS", "skipped"),
        os.environ.get("IMAGE_REF") or None,
        required_env("WORKFLOW_URL"),
        log_bytes.decode("utf-8", errors="replace"),
        truncated,
    )

    query = """
        INSERT INTO public.github_action_build_runs (
            repository,
            run_id,
            run_attempt,
            commit_sha,
            source_ref,
            build_status,
            deploy_status,
            image_ref,
            workflow_url,
            build_output,
            output_truncated
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (repository, run_id, run_attempt)
        DO UPDATE SET
            commit_sha = EXCLUDED.commit_sha,
            source_ref = EXCLUDED.source_ref,
            build_status = EXCLUDED.build_status,
            deploy_status = EXCLUDED.deploy_status,
            image_ref = EXCLUDED.image_ref,
            workflow_url = EXCLUDED.workflow_url,
            build_output = EXCLUDED.build_output,
            output_truncated = EXCLUDED.output_truncated,
            recorded_at = now()
    """

    with psycopg.connect(
        required_env("BUILD_LOG_DATABASE_URL"),
        connect_timeout=10,
        sslmode="require",
    ) as connection:
        connection.execute(query, values)

    print(f"Stored build run {values[1]}/{values[2]} with build status {values[5]}.")


if __name__ == "__main__":
    main()
