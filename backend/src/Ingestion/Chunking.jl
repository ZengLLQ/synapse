module Chunking

using UUIDs, Dates, SQLite, DBInterface
using ..DocumentParsers: ParsedDocument, ParsedSection

struct DocumentChunk
    id::String
    source_version_id::String
    chunk_index::Int
    page_number::Union{Int, Nothing}
    start_line::Int
    end_line::Int
    start_char::Int
    end_char::Int
    title::String
    content::String
end

function chunk_document(doc::ParsedDocument, source_version_id::String; target_chunk_size::Int=800, overlap::Int=100)
    chunks = DocumentChunk[]
    chunk_counter = 1

    for sec in doc.sections
        content = strip(sec.content)
        if isempty(content)
            continue
        end

        # If section is small enough, make it a single chunk
        if sizeof(content) <= target_chunk_size
            push!(chunks, DocumentChunk(
                string(uuid4()),
                source_version_id,
                chunk_counter,
                1,
                sec.start_line,
                sec.end_line,
                sec.start_char,
                sec.end_char,
                sec.title,
                content
            ))
            chunk_counter += 1
        else
            # Split section by paragraphs or sliding window
            paragraphs = split(content, "\n\n")
            current_buffer = String[]
            current_bytes = 0
            chunk_start_char = sec.start_char
            chunk_start_line = sec.start_line

            for p in paragraphs
                p_str = strip(String(p))
                if isempty(p_str)
                    continue
                end
                p_bytes = sizeof(p_str)

                if current_bytes + p_bytes > target_chunk_size && !isempty(current_buffer)
                    chunk_text = join(current_buffer, "\n\n")
                    chunk_end_char = chunk_start_char + sizeof(chunk_text)
                    line_count = count(c -> c == '\n', chunk_text)
                    chunk_end_line = chunk_start_line + line_count

                    push!(chunks, DocumentChunk(
                        string(uuid4()),
                        source_version_id,
                        chunk_counter,
                        1,
                        chunk_start_line,
                        chunk_end_line,
                        chunk_start_char,
                        chunk_end_char,
                        sec.title,
                        chunk_text
                    ))
                    chunk_counter += 1

                    empty!(current_buffer)
                    current_bytes = 0
                    chunk_start_char = chunk_end_char + 1
                    chunk_start_line = chunk_end_line + 1
                end

                push!(current_buffer, p_str)
                current_bytes += p_bytes
            end

            if !isempty(current_buffer)
                chunk_text = join(current_buffer, "\n\n")
                chunk_end_char = chunk_start_char + sizeof(chunk_text)
                line_count = count(c -> c == '\n', chunk_text)
                chunk_end_line = chunk_start_line + line_count

                push!(chunks, DocumentChunk(
                    string(uuid4()),
                    source_version_id,
                    chunk_counter,
                    1,
                    chunk_start_line,
                    chunk_end_line,
                    chunk_start_char,
                    chunk_end_char,
                    sec.title,
                    chunk_text
                ))
                chunk_counter += 1
            end
        end
    end

    return chunks
end

function index_chunks!(db::SQLite.DB, workspace_id::String, source_id::String, chunks::Vector{DocumentChunk})
    now_iso = Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    sql_chunk = """
        INSERT INTO chunks (id, source_version_id, chunk_index, page_number, start_line, end_line, start_char, end_char, title, content, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """
    sql_fts = """
        INSERT INTO chunks_fts (chunk_id, source_id, source_version_id, workspace_id, page_number, title, content)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    """

    for chunk in chunks
        DBInterface.execute(db, sql_chunk, (
            chunk.id,
            chunk.source_version_id,
            chunk.chunk_index,
            chunk.page_number,
            chunk.start_line,
            chunk.end_line,
            chunk.start_char,
            chunk.end_char,
            chunk.title,
            chunk.content,
            now_iso
        ))

        DBInterface.execute(db, sql_fts, (
            chunk.id,
            source_id,
            chunk.source_version_id,
            workspace_id,
            chunk.page_number,
            chunk.title,
            chunk.content
        ))
    end
end

end # module Chunking
