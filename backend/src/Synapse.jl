module Synapse

# Core Synapse Modular Monolith
include("Application/Config.jl")
using .Config

include("Domain/Epistemic.jl")
using .Epistemic

include("Domain/Entities.jl")
using .Entities

include("Domain/Relations.jl")
using .Relations

include("Persistence/Schema.jl")
using .Schema

include("Persistence/Database.jl")
using .Database

include("Workspace/WorkspaceManager.jl")
using .WorkspaceManager

include("Provenance/ProvenanceTracker.jl")
using .ProvenanceTracker

include("Ingestion/DocumentParsers.jl")
using .DocumentParsers

include("Ingestion/Chunking.jl")
using .Chunking

include("Sources/SourceService.jl")
using .SourceService

include("Audit/AuditService.jl")
using .AuditService

include("Audit/ReviewQueue.jl")
using .ReviewQueue

include("Graph/GraphStore.jl")
using .GraphStore

include("Graph/GraphQueries.jl")
using .GraphQueries

include("Retrieval/FTS5Search.jl")
using .FTS5Search

include("Retrieval/HybridRetriever.jl")
using .HybridRetriever

include("Models/ModelAdapters.jl")
using .ModelAdapters

include("Models/MockAdapter.jl")
using .MockAdapter

include("Models/CloudConsentGuard.jl")
using .CloudConsentGuard

include("Jobs/JobOrchestrator.jl")
using .JobOrchestrator

include("Research/CitationValidator.jl")
using .CitationValidator

include("Research/Assistant.jl")
using .Assistant

include("Export/WorkspaceExport.jl")
using .WorkspaceExport

include("API/Routes.jl")
using .Routes

include("API/Server.jl")
using .Server

export Config, Epistemic, Entities, Relations, Database, WorkspaceManager
export ProvenanceTracker, DocumentParsers, Chunking, SourceService
export GraphStore, GraphQueries, FTS5Search, HybridRetriever
export ModelAdapters, MockAdapter, CloudConsentGuard, JobOrchestrator
export AuditService, ReviewQueue, CitationValidator, Assistant, WorkspaceExport
export Routes, Server

function main(args=ARGS)
    port = 8765
    base_dir = joinpath(homedir(), ".synapse")
    
    i = 1
    while i <= length(args)
        if args[i] == "--port" && i + 1 <= length(args)
            port = parse(Int, args[i+1])
            i += 2
        elseif args[i] == "--data-dir" && i + 1 <= length(args)
            base_dir = args[i+1]
            i += 2
        else
            i += 1
        end
    end

    cfg = Config.default_config(base_dir=base_dir, port=port)
    println("==================================================")
    println(" Synapse Research Engine (Julia v1.13)")
    println(" Listening strictly on: http://127.0.0.1:$port")
    println(" Session token: $(cfg.session_token)")
    println(" Base data dir: $(cfg.base_dir)")
    println("==================================================")
    
    srv = Server.start_server(cfg)
    
    # Wait until interrupted
    try
        while true
            sleep(1)
        end
    catch e
        if isa(e, InterruptException)
            println("\nShutting down Synapse engine...")
            Server.stop_server(srv)
        else
            rethrow(e)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module Synapse
