# RedPen: Client/Server configuration for WebSockets

const SUCCESS = "Success"

function resetpayload()
    payload::Dict{String,Any} = Dict{String,Any}(
        "time"=>"",
        "email"=>"",
        "nickname"=>"",
        "data"=>NaN,
        "type"=>"String",
        "project"=>"")
end

mutable struct File
  name::String
  content::Vector{UInt8}
end

function parse(::Type{File}, dict::Dict)
    if haskey(dict, "name") && haskey(dict, "content")
        file::File = File(dict["name"], dict["content"])
        return file
    else
        error("Dict does not contain File type fields.")
    end
end

function parse(::Type{File}, jsonstr::String)
    # JSON -> Dict -> File type
    dict::Dict = JSON.parse(jsonstr)
    parse(File, dict)
end

function parse(::Type{Vector{File}}, dictarr::Vector{Any})
    files = File[]
    for file in dictarr
        push!(files, parse(File, file))
    end
    return files
end

# RedPen @info style printing
macro rinfo(str)
    quote
        printstyled("[ RedPen: ", color=:red, bold=true)
        println($(esc(str)))
    end
end

# Load JSON config, input can be relative path from parent script
macro loadconfig(filepath::String)
    dir::String = dirname(string(__source__.file))
    return :(JSON.parse(read(joinpath($(esc(dir)), $(esc(filepath))), String)))
end

ismatch(regex::Regex, str::String) = !isa(match(regex, str), Nothing)
trimdir(dir) = replace(replace(dir, "/"=>""), "\\"=>"")

# https://stackoverflow.com/questions/201323/how-to-validate-an-email-address-using-a-regular-expression
isvalidemail(email::String) = occursin(r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])", email)
isvalidstanfordemail(email::String) = occursin(r"(?:[a-z0-9]+(?:\.[a-z0-9]+)*)@stanford.edu", email)
