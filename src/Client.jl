# RedPen: Client
module Client

using ..RedPen
using HTTP
using JSON
using Nettle
using Obfuscatee

export submit
@binclude ".cbin"
end # module Client