# RedPen: Client
module Client

using ..RedPen
using HTTP
using JSON
using Nettle
using Obfuscatee

export submit

function submit(payload::Dict, config::Dict; passwd::Union{String,Nothing}=nothing, salt::Union{String,Number}=0x01)
    emailPOC::String = config["email"]
    address::String = config["address"]
    if haskey(config, "port")
        port::Int = config["port"]
        address = "$address:$port"
    end

    # Set payload data type
    payload["type"] = typeof(payload["data"])

    # Encrypt payload if a passwd is provided
    if !isnothing(passwd)
        encrypt_payload!(payload, passwd, salt)
    end

    @info "Sending data..."
    try
        # Client Side
        HTTP.WebSockets.open("ws://$address") do ws
            # Write JSON payload to WebSocket
            write(ws, JSON.json(payload))
            # Get response back
            response = readavailable(ws)
            response_str::String = String(response)
            if occursin(SUCCESS, response_str)
                @info response_str
            else
                throw("Submission failed: $response_str")
            end
        end
    catch err
        if isa(err, HTTP.IOExtras.IOError)
            error("Cannot connect to RedPen server. Check your internet connection or contact POC: $emailPOC")
        else
            # printstyled("ERROR: If errors persist, please contact $emailPOC\n", color = :red, bold = true)
            throw(err)
        end
    end
    return nothing # Suppress REPL
end

function encrypt_payload!(payload::Dict, passwd::String, salt::Union{String,Number})
    # Encrypt data
    vsalt::Vector{UInt8} = hex2bytes(string(hash(salt), base=16))
    (key32::Vector{UInt8}, iv16::Vector{UInt8}) = gen_key32_iv16(Vector{UInt8}(passwd), vsalt)
    enc::Encryptor = Encryptor("AES256", key32)
    plaintext::String = string(payload["data"])
    ciphertext::Vector{UInt8} = encrypt(enc, :CBC, iv16, add_padding_PKCS5(Vector{UInt8}(plaintext), 64))
    payload["data"] = ciphertext
    return payload::Dict
end

end # module Client
