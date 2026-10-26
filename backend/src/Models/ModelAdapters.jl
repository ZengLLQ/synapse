module ModelAdapters

abstract type AbstractModelAdapter end

function generate_text(adapter::AbstractModelAdapter, prompt::String; options...)
    error("generate_text not implemented for $(typeof(adapter))")
end

function extract_structured(adapter::AbstractModelAdapter, text::String, schema_name::String)
    error("extract_structured not implemented for $(typeof(adapter))")
end

function embed_texts(adapter::AbstractModelAdapter, texts::Vector{String})
    error("embed_texts not implemented for $(typeof(adapter))")
end

end # module ModelAdapters
