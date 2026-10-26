module DocumentParsers

using CodecZlib

struct ParsedSection
    title::String
    level::Int
    start_line::Int
    end_line::Int
    start_char::Int
    end_char::Int
    content::String
end

struct ParsedDocument
    title::String
    format::String
    total_pages::Int
    total_lines::Int
    total_bytes::Int
    full_text::String
    sections::Vector{ParsedSection}
    is_scanned::Bool
    warning::Union{String, Nothing}
end

# 1. Markdown Parser
function parse_markdown(content::String; default_title::String="Untitled Document")
    lines = split(content, '\n')
    total_lines = length(lines)
    total_bytes = sizeof(content)
    
    sections = ParsedSection[]
    current_title = default_title
    current_level = 0
    current_start_line = 1
    current_start_char = 1
    current_lines = String[]
    char_counter = 1

    doc_title = default_title
    found_h1 = false

    for (line_idx, line) in enumerate(lines)
        line_str = String(line)
        line_len = sizeof(line_str) + 1 # including newline
        
        m = match(r"^(#{1,6})\s+(.*)$", strip(line_str))
        if m !== nothing
            header_level = length(m.captures[1])
            header_text = strip(m.captures[2])
            
            if !found_h1 && header_level == 1
                doc_title = header_text
                found_h1 = true
            end

            # Flush previous section if it has content
            if !isempty(current_lines)
                sec_content = join(current_lines, '\n')
                sec_end_char = char_counter - 1
                push!(sections, ParsedSection(
                    current_title,
                    current_level,
                    current_start_line,
                    line_idx - 1,
                    current_start_char,
                    sec_end_char,
                    sec_content
                ))
                empty!(current_lines)
            end

            current_title = header_text
            current_level = header_level
            current_start_line = line_idx
            current_start_char = char_counter
        else
            push!(current_lines, line_str)
        end
        char_counter += line_len
    end

    # Flush final section
    if !isempty(current_lines)
        sec_content = join(current_lines, '\n')
        sec_end_char = char_counter - 1
        push!(sections, ParsedSection(
            current_title,
            current_level,
            current_start_line,
            total_lines,
            current_start_char,
            sec_end_char,
            sec_content
        ))
    end

    if isempty(sections)
        push!(sections, ParsedSection(doc_title, 0, 1, max(1, total_lines), 1, max(1, total_bytes), content))
    end

    return ParsedDocument(doc_title, "markdown", 1, total_lines, total_bytes, content, sections, false, nothing)
end

# 2. Plain Text Parser
function parse_plaintext(content::String; default_title::String="Untitled Text")
    lines = split(content, '\n')
    total_lines = length(lines)
    total_bytes = sizeof(content)

    sections = ParsedSection[]
    current_start_line = 1
    current_start_char = 1
    current_lines = String[]
    char_counter = 1
    paragraph_idx = 1

    for (line_idx, line) in enumerate(lines)
        line_str = String(line)
        line_len = sizeof(line_str) + 1

        if isempty(strip(line_str))
            # Blank line separates paragraphs
            if !isempty(current_lines)
                sec_content = join(current_lines, '\n')
                sec_end_char = char_counter - 1
                sec_title = "Paragraph $paragraph_idx"
                push!(sections, ParsedSection(
                    sec_title,
                    1,
                    current_start_line,
                    line_idx - 1,
                    current_start_char,
                    sec_end_char,
                    sec_content
                ))
                empty!(current_lines)
                paragraph_idx += 1
            end
            current_start_line = line_idx + 1
            current_start_char = char_counter + line_len
        else
            push!(current_lines, line_str)
        end
        char_counter += line_len
    end

    if !isempty(current_lines)
        sec_content = join(current_lines, '\n')
        sec_end_char = char_counter - 1
        push!(sections, ParsedSection(
            "Paragraph $paragraph_idx",
            1,
            current_start_line,
            total_lines,
            current_start_char,
            sec_end_char,
            sec_content
        ))
    end

    if isempty(sections)
        push!(sections, ParsedSection(default_title, 0, 1, max(1, total_lines), 1, max(1, total_bytes), content))
    end

    return ParsedDocument(default_title, "plaintext", 1, total_lines, total_bytes, content, sections, false, nothing)
end

# 3. Text PDF Parser & Scanned Detection
function parse_pdf(raw_bytes::AbstractVector{UInt8}; default_title::String="Untitled Document")
    total_bytes = length(raw_bytes)
    raw_str = String(Vector{UInt8}(raw_bytes))

    # Basic PDF sanity check
    if !startswith(raw_str, "%PDF")
        throw(ArgumentError("Invalid PDF format: Missing %PDF header"))
    end

    # Extract text from streams
    extracted_text_blocks = String[]
    has_image = occursin("/Subtype /Image", raw_str) || occursin("/Subtype/Image", raw_str)
    
    # Locate all stream ... endstream blocks
    stream_regex = r"stream\r?\n(.*?)\r?\nendstream"s
    for m in eachmatch(stream_regex, raw_str)
        stream_content = m.captures[1]
        
        # Check if stream is FlateDecode
        decoded_bytes = try
            transcode(ZlibDecompressor, codeunits(stream_content))
        catch
            codeunits(stream_content)
        end
        decoded_str = String(decoded_bytes)

        # Look for BT ... ET text blocks
        bt_regex = r"BT\s*(.*?)\s*ET"s
        for text_block in eachmatch(bt_regex, decoded_str)
            inner = text_block.captures[1]
            # Match (text) Tj or [(text)] TJ
            # Tj pattern: \((.*?)\)\s*Tj
            for tj in eachmatch(r"\((.*?)\)\s*Tj", inner)
                push!(extracted_text_blocks, tj.captures[1])
            end
            # TJ pattern: \[(.*?)\]\s*TJ
            for tj_arr in eachmatch(r"\[(.*?)\]\s*TJ", inner)
                arr_inner = tj_arr.captures[1]
                for str_part in eachmatch(r"\((.*?)\)", arr_inner)
                    push!(extracted_text_blocks, str_part.captures[1])
                end
            end
        end
    end

    # Count pages
    page_matches = collect(eachmatch(r"/Type\s*/Page\b", raw_str))
    total_pages = max(1, length(page_matches))

    full_text = join(extracted_text_blocks, " ")
    full_text = replace(full_text, "\\n" => "\n", "\\r" => "", "\\t" => " ", "\\(" => "(", "\\)" => ")")
    full_text = strip(full_text)

    # Scanned PDF Detection Rule:
    # If the file has images or 0 extractable text characters from streams, it is a scanned/raster PDF.
    if isempty(full_text) || (has_image && length(full_text) < 20)
        warning_msg = "PDF contains scanned or raster graphics without extractable text streams. OCR is required."
        return ParsedDocument(default_title, "pdf", total_pages, 0, total_bytes, "", ParsedSection[], true, warning_msg)
    end

    lines = split(full_text, '\n')
    total_lines = length(lines)
    sections = ParsedSection[]
    push!(sections, ParsedSection(default_title, 1, 1, total_lines, 1, sizeof(full_text), full_text))

    return ParsedDocument(default_title, "pdf", total_pages, total_lines, total_bytes, full_text, sections, false, nothing)
end

function parse_file(file_path::String)
    isfile(file_path) || throw(SystemError("File not found: $file_path"))
    ext = lowercase(splitext(file_path)[2])
    base_name = splitext(basename(file_path))[1]

    if ext == ".md" || ext == ".markdown"
        content = read(file_path, String)
        return parse_markdown(content; default_title=base_name)
    elseif ext == ".txt"
        content = read(file_path, String)
        return parse_plaintext(content; default_title=base_name)
    elseif ext == ".pdf"
        bytes = read(file_path)
        return parse_pdf(bytes; default_title=base_name)
    else
        throw(ArgumentError("Unsupported file extension: $ext. Supported: .md, .txt, .pdf"))
    end
end

end # module DocumentParsers
