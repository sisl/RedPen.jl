# RedPen: Server
module Server

export listen

using ..RedPen
using HTTP
using JSON
using Nettle

# Inputs:
#   callbacks: Dictionary of project IDs => callback function that takes the payload JSON
#   config: JSON dictionary with "address", "port", and "email" fields
function listen(callbacks::Dict, config::Dict; passwd::Union{String,Nothing}=nothing, salt::Union{String,Number}=0x01)
    emailPOC::String = config["email"]
    address::String = config["address"]
    port::Int = config["port"]

    # Horizontal line separation
    hline() = println(repeat("—", 40))

    try
        projects::Vector{String} = collect(keys(callbacks))
        projectlist::String = join(projects, ", ")
        @rinfo "Starting RedPen for: $projectlist"
        @rinfo "Listening for submissions ($address:$port)."
        hline()
        # Server Side
        # No longer @async, let listen control the process
        HTTP.WebSockets.listen(address, UInt16(port)) do ws
            try
                while !eof(ws)
                    rawdata = readavailable(ws)
                    if !isempty(rawdata)
                        payload::Dict = JSON.parse(String(rawdata))
                        if haskey(payload, "data") && !isnothing(payload["data"])
                            try
                                if !isnothing(passwd)
                                    # Decrpyt data if passwd is provided
                                    decrypt_payload!(payload, ws, passwd, salt)
                                end
                                # Use project ID as the key for the callback functions
                                project::String = payload["project"]
                                if haskey(callbacks, project)
                                    callback::Function = callbacks[project]
                                    # Run callback processing function for the specified project
                                    message_back::Union{String,Nothing} = callback(payload)
                                    if !isa(message_back, Nothing)
                                        # Send back a message specified by the project
                                        write(ws, message_back)
                                    end
                                else
                                    @warn ("$(payload["email"]) tried to submit a different project: $(payload["project"])")
                                    write(ws, "Currently only accepting: $projectlist")
                                end
                                hline()
                            catch callbackerr
                                senderror(ws, callbackerr)
                            end
                        else
                            null_err_msg::String = "Null payload data."
                            senderror(ws, null_err_msg)
                        end
                    end
                end
            catch err
                sendnotification(emailPOC, err)
                senderror(ws, err)
            end
        end
    catch ws_err
        sendnotification(emailPOC, ws_err)
        @warn("Cannot connect to WebSocket.")
        throw(ws_err)
    end
end

function decrypt_payload!(payload::Dict, ws::HTTP.WebSockets.WebSocket, passwd::String, salt::Union{String,Number})
    vsalt::Vector{UInt8} = hex2bytes(string(hash(salt), base=16))
    (key32::Vector{UInt8}, iv16::Vector{UInt8}) = gen_key32_iv16(Vector{UInt8}(passwd), vsalt)
    dec::Decryptor = Decryptor("AES256", key32)
    try
        deciphertext = decrypt(dec, :CBC, iv16, Vector{UInt8}(payload["data"]))
        decrypted_data::String = String(trim_padding_PKCS5(deciphertext))
        T = eval(Meta.parse(payload["type"]))
        if typeof(decrypted_data) <: String
            data::T = parse(T, decrypted_data)
            payload["data"] = data
        else
            senderror(ws, "Submission is not a Dict type.")
        end
    catch converterr
        if isa(converterr, ArgumentError)
            @warn "Invalid decryption, cannot convert decoding to " * payload["type"]
            senderror(ws, "Invalid decryption.")
        else
            @warn converterr
            senderror(ws, converterr)
        end
    end
    return payload::Dict
end

function senderror(ws::HTTP.WebSockets.WebSocket, err::Union{Exception,String})
    err_str::String = string(err)
    write(ws, err_str)
    @warn err_str
end

function sendnotification(emailPOC::String, err)
    if isempty(emailPOC)
        @warn "Ran into error..."
    else
        # TODO: Send email notification
        @warn "Ran into error, sending notification email to $emailPOC..."
    end
end

end # module Server