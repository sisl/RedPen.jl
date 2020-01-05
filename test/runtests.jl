using RedPen
using Test

server_state = Dict{String, Any}("test"=>nothing)

callbacks = Dict("test"=>function (payload)
                     server_state["test"] = payload
                     return "Success"
                 end
                )

config = Dict("address"=>"127.0.0.1",
              "port"=>8228,
              "email"=>"instructor@colorado.edu")

@async RedPen.Server.listen(callbacks, config)

payload = Dict{String,Any}("email"=>"student@colorado.edu",
               "project"=>"test",
               "data"=>"")
RedPen.Client.submit(payload, config)
sleep(0.1)
tp = server_state["test"]
@test tp["email"] == "student@colorado.edu"
@test tp["project"] == "test"
