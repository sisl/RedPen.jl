# RedPen: Server
module Server

using ..RedPen
using HTTP
using JSON
using Nettle

export listen

# Inputs:
#   callbacks: Dictionary of project IDs => callback function that takes the payload JSON
#   config: JSON dictionary with "address", "port", and "email" fields
function listen(callbacks::Dict, config::Dict; passwd::Union{String,Nothing}=nothing, salt::Union{String,Number}=0x01)
    emailPOC::String = config["email"] # maintainer's email
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
        	RAWDATACACHE = ""
            try
                while !eof(ws)
                    rawdata = readavailable(ws)
                    if !isempty(rawdata)
                    	RAWDATACACHE = deepcopy(String(rawdata))
                        payload::Dict = JSON.parse(RAWDATACACHE)
                        email::String = payload["email"] # submitter's email
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
                                    @warn "$email tried to submit a different project: $(payload["project"])"
                                    write(ws, "Currently only accepting: $projectlist")
                                end
                            catch callbackerr
                                senderror(ws, email, callbackerr)
                            end
                            hline()
                        else
                            null_err_msg::String = "Null payload data."
                            senderror(ws, email, null_err_msg)
                        end
                    end
                end
            catch err
                # sendnotification(emailPOC, err)
                @info RAWDATACACHE
                senderror(ws, err)
            end
        end
    catch ws_err
        # sendnotification(emailPOC, ws_err)
        @warn("Cannot connect to WebSocket.")
        throw(ws_err)
    end
end

function decrypt_payload!(payload::Dict, ws::HTTP.WebSockets.WebSocket, passwd::String, salt::Union{String,Number})
    email::String = payload["email"]
    vsalt::Vector{UInt8} = hex2bytes(string(hash(salt), base=16))
    (key32::Vector{UInt8}, iv16::Vector{UInt8}) = gen_key32_iv16(Vector{UInt8}(passwd), vsalt)
    dec::Decryptor = Decryptor("AES256", key32)
    try
        deciphertext = decrypt(dec, :CBC, iv16, Vector{UInt8}(payload["data"]))
        decrypted_data::String = String(trim_padding_PKCS5(deciphertext))
        T = eval(Meta.parse(payload["type"]))
        if typeof(decrypted_data) <: String
            if T == String
                # Use data directly if it's already a String
                payload["data"] = decrypted_data
            else
                # Parse as type T
                data::T = parse(T, decrypted_data)
                payload["data"] = data
            end
        else
            senderror(ws, email, "Submission is not a Dict type.")
        end
    catch converterr
        if isa(converterr, ArgumentError)
            warnidentify(email, "Invalid decryption, cannot convert decoding to " * payload["type"])
            senderror(ws, email, "Invalid decryption.")
        else
            senderror(ws, email, converterr)
        end
    end
    return payload::Dict
end

senderror(ws::HTTP.WebSockets.WebSocket, err::Union{Exception,String}) = senderror(ws, "<EMAIL UNAVAILABLE>", err)
function senderror(ws::HTTP.WebSockets.WebSocket, email::String, err::Union{Exception,String})
    err_str::String = string(err)
    warnidentify(email, err_str)
    write(ws, err_str)
end

# UNUSED
function sendnotification(emailPOC::String, email::String, err)
    if isempty(emailPOC)
        @warn "RedPen.Server: Ran into error..."
    else
        # TODO: Send email notification
        @warn "RedPen.Server: Ran into error, sending notification email to $emailPOC..."
    end
end

# Helper to identify who caused the warning/error
function warnidentify(email::String, warnmsg)
    @warn "$email: $warnmsg"
end

end ## module Server
