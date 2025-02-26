using Bonito, Observables, WGLMakie
# using Bonito: @js_str, onjs, Button, TextField, Slider, linkjs, Session, App
using Bonito.DOM
# using Hyperscript

color = Observable("red")

Threads.@spawn while true
    sleep(1)
    color[] = color[] == "red" ? "blue" : "red"
end


app = App() do session::Session
    f, a, p = lines(rand(10); color = color)
    return f
end

if isdefined(Main, :server)
    close(server)
end

server = Bonito.Server(app, "$(get(ENV, "BONITO_DNS", "trybonito")).apps.internal.juliahub.com", parse(Int, get(ENV, "BONITO_PORT", "8081")))
# Important Note: You might want to set the keyword argument `proxy_url` above in case
# you have a reverse proxy (like nginx or caddy) in front of the Bonito instance.
Bonito.HTTPServer.start(server)
# Bonito.HTTPServer.route!(server, "/" => app) # Overwrite app after changing it
wait(server)