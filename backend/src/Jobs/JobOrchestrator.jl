module JobOrchestrator

using UUIDs, Dates, SQLite, DBInterface, JSON3
using ..Database

struct JobRecord
    id::String
    workspace_id::String
    job_type::String
    input_fingerprint::String
    pipeline_version::String
    status::String
    progress::Float64
    stage::String
    attempts::Int
    error_message::Union{String, Nothing}
    output_references::Union{String, Nothing}
    created_at::String
    updated_at::String
end

const STATUS_QUEUED = "queued"
const STATUS_RUNNING = "running"
const STATUS_RETRY_WAIT = "retry_wait"
const STATUS_CANCEL_REQUESTED = "cancel_requested"
const STATUS_CANCELLED = "cancelled"
const STATUS_SUCCEEDED = "succeeded"
const STATUS_FAILED = "failed"

function create_job(db::SQLite.DB, workspace_id::String, job_type::String, input_fingerprint::String; pipeline_version::String="1.0.0")
    job_id = string(uuid4())
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

    Database.execute(db, """
        INSERT INTO processing_jobs (id, workspace_id, job_type, input_fingerprint, pipeline_version, status, progress, stage, attempts, error_message, output_references, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 0.0, 'initialized', 1, NULL, NULL, ?, ?);
    """, (job_id, workspace_id, job_type, input_fingerprint, pipeline_version, STATUS_QUEUED, now_iso, now_iso))

    return JobRecord(job_id, workspace_id, job_type, input_fingerprint, pipeline_version, STATUS_QUEUED, 0.0, "initialized", 1, nothing, nothing, now_iso, now_iso)
end

function update_job_progress(db::SQLite.DB, job_id::String, stage::String, progress::Float64)
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    Database.execute(db, """
        UPDATE processing_jobs
        SET stage = ?, progress = ?, status = ?, updated_at = ?
        WHERE id = ? AND status != ?;
    """, (stage, progress, STATUS_RUNNING, now_iso, job_id, STATUS_CANCEL_REQUESTED))
end

function is_cancellation_requested(db::SQLite.DB, job_id::String)
    rows = Database.query(db, "SELECT status FROM processing_jobs WHERE id = ? LIMIT 1;", (job_id,))
    for row in rows
        return string(row.status) == STATUS_CANCEL_REQUESTED || string(row.status) == STATUS_CANCELLED
    end
    return false
end

function complete_job(db::SQLite.DB, job_id::String, output_refs::Dict{String, Any})
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    refs_json = JSON3.write(output_refs)
    Database.execute(db, """
        UPDATE processing_jobs
        SET status = ?, progress = 1.0, stage = 'completed', output_references = ?, updated_at = ?
        WHERE id = ?;
    """, (STATUS_SUCCEEDED, refs_json, now_iso, job_id))
end

function fail_job(db::SQLite.DB, job_id::String, error_msg::String)
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    Database.execute(db, """
        UPDATE processing_jobs
        SET status = ?, stage = 'failed', error_message = ?, updated_at = ?
        WHERE id = ?;
    """, (STATUS_FAILED, error_msg, now_iso, job_id))
end

function request_job_cancellation(db::SQLite.DB, job_id::String)
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    Database.execute(db, """
        UPDATE processing_jobs
        SET status = ?, updated_at = ?
        WHERE id = ? AND status IN (?, ?);
    """, (STATUS_CANCEL_REQUESTED, now_iso, job_id, STATUS_QUEUED, STATUS_RUNNING))
    return true
end

function get_job(db::SQLite.DB, job_id::String)
    query = """
        SELECT id, workspace_id, job_type, input_fingerprint, pipeline_version, status, progress, stage, attempts, error_message, output_references, created_at, updated_at
        FROM processing_jobs
        WHERE id = ? LIMIT 1;
    """
    rows = Database.query(db, query, (job_id,))
    for row in rows
        return JobRecord(
            string(row.id),
            string(row.workspace_id),
            string(row.job_type),
            string(row.input_fingerprint),
            string(row.pipeline_version),
            string(row.status),
            Float64(row.progress),
            string(row.stage),
            Int(row.attempts),
            ismissing(row.error_message) || row.error_message === nothing ? nothing : string(row.error_message),
            ismissing(row.output_references) || row.output_references === nothing ? nothing : string(row.output_references),
            string(row.created_at),
            string(row.updated_at)
        )
    end
    return nothing
end

function list_jobs(db::SQLite.DB, workspace_id::String; limit::Int=50)
    query = """
        SELECT id, workspace_id, job_type, input_fingerprint, pipeline_version, status, progress, stage, attempts, error_message, output_references, created_at, updated_at
        FROM processing_jobs
        WHERE workspace_id = ?
        ORDER BY created_at DESC
        LIMIT ?;
    """
    rows = Database.query(db, query, (workspace_id, limit))
    jobs = JobRecord[]
    for row in rows
        push!(jobs, JobRecord(
            string(row.id),
            string(row.workspace_id),
            string(row.job_type),
            string(row.input_fingerprint),
            string(row.pipeline_version),
            string(row.status),
            Float64(row.progress),
            string(row.stage),
            Int(row.attempts),
            ismissing(row.error_message) || row.error_message === nothing ? nothing : string(row.error_message),
            ismissing(row.output_references) || row.output_references === nothing ? nothing : string(row.output_references),
            string(row.created_at),
            string(row.updated_at)
        ))
    end
    return jobs
end

function retry_job!(db::SQLite.DB, job_id::String)
    job = get_job(db, job_id)
    job !== nothing || throw(ArgumentError("Job not found: $job_id"))
    
    # Can only retry jobs that have stopped
    if job.status in [STATUS_RUNNING, STATUS_QUEUED]
        throw(ArgumentError("Cannot retry an active job (current status: $(job.status))"))
    end

    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    new_attempts = job.attempts + 1

    Database.execute(db, """
        UPDATE processing_jobs
        SET status = ?, progress = 0.0, stage = 'retry_queued', attempts = ?, error_message = NULL, updated_at = ?
        WHERE id = ?;
    """, (STATUS_QUEUED, new_attempts, now_iso, job_id))

    return get_job(db, job_id)
end

function recover_stale_jobs!(db::SQLite.DB)
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    Database.execute(db, """
        UPDATE processing_jobs
        SET status = ?, stage = 'recovered_after_restart', error_message = 'Application restart interrupted job.', updated_at = ?
        WHERE status IN (?, ?);
    """, (STATUS_FAILED, now_iso, STATUS_RUNNING, STATUS_QUEUED))
end

end # module JobOrchestrator
