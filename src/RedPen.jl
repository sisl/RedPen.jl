#=
    RedPen: Submit project material for grading
    ('Rubric' in latin is 'rubrica', or 'red ink')

    - Robert Moss, Stanford University, Sep. 2019
=#
module RedPen
    using JSON
    using Obfuscatee

    import Base.parse

    export
        parse,
        submit,
        trimdir,
        ismatch,
        isvalidemail,
        isvalidstanfordemail,
        resetpayload,
        @rinfo,
        @loadconfig,
        File,
        SUCCESS

    include("utils.jl") # Utility functions
    include("submit.jl") # Command line submit script

    include("Server.jl") # module
    include("Client.jl") # module
end # module RedPen
