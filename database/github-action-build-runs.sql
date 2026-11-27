CREATE TABLE public.github_action_build_runs (
    repository text NOT NULL,
    run_id bigint NOT NULL,
    run_attempt integer NOT NULL,
    commit_sha text NOT NULL,
    source_ref text NOT NULL,
    build_status text NOT NULL,
    deploy_status text NOT NULL,
    image_ref text,
    workflow_url text NOT NULL,
    build_output text NOT NULL,
    output_truncated boolean NOT NULL DEFAULT false,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (repository, run_id, run_attempt)
);
