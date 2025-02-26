#=
This is a simple test case and example of the 
single-producer, multiple-session architecture with Bonito.

There is a global Observable that changes color every second, 
which is shared across multiple user sessions. Each session creates 
a plot that displays this shared color, demonstrating how to handle 
shared state in a web application.

There are two endpoints: 
- `/` which is the main plot page
- `/color` which returns an HTTP 200 response with the current color as the body.
=#

@info "Starting BonitoJuliaHubTest"
@info "Thread configuration" Threads.nthreads() Sys.CPU_THREADS Threads.nthreadpools() Threads.threadpool() Threads.threadpoolsize(Threads.threadpool())
@info environment=ENV

using Bonito, Observables, WGLMakie
# using Bonito: @js_str, onjs, Button, TextField, Slider, linkjs, Session, App
using Bonito.DOM
using Bonito.HTTP
# using Hyperscript
@info "Loaded all packages"

color = Observable("red")
number_of_listeners = 0


# Get the DNS and port from environment variables,
# and log the values we are using.
# You don't have to do the logging bit at all - it's just
# so we can show it in the example app.
port = get(ENV, "PORT", "8081") # it's guaranteed this exists on JuliaHub

if haskey(ENV, "PORT")
    @info "Using port from environment variable PORT: $port"
else
    @info "Using default port: $port"
end

proxy = get(ENV, "JULIAHUB_APP_URL", "")
if isempty(proxy)
    @info "No Bonito proxy found in environment variable JULIAHUB_APP_URL"
else
    @info "Using Bonito proxy from JULIAHUB_APP_URL: $proxy"
end

# Construct the Bonito server!
# JuliaHub uses nginx as a proxy server,
# so we need to tell Bonito what the final URL will be.
# If you select the DNS on the app,
# then you must provide Bonito the environment variable BONITO_PROXY
# set to "$DNS.internal.juliahub.com" (or your juliahub.com subdomain).
@info "Constructing Bonito server on 0.0.0.0:$port $(isempty(proxy) ? "" : "with proxy $proxy")"
server = Bonito.Server("0.0.0.0", parse(Int, port); proxy_url = proxy, verbose = -1)

# Make sure the simulation loop runs on the interactive threadpool
# so that it does not conflict with the main (`:default`) threadpool
# and can run as fast as it needs to.
color_task = Threads.@spawn :interactive begin
    tic = time()
    while true
        elapsed = tic - time()
        tic = time()
        # (elapsed < 1) && sleep(1 - elapsed)
        @info "Elapsed time in color loop: $elapsed"
        sleep(1)
        color[] = color[] == "red" ? "blue" : "red"

        # Log when number of listeners changes - this is important to know
        # so that we can understand if the Observable architecture used here makes
        # sense, or if we should use a different architecture, like channels or 
        # global arrays that get polled every frame.
        # if number_of_listeners != length(color.listeners)
        #     number_of_listeners = length(color.listeners)
        #     @info "Number of listeners on color observable changed to $number_of_listeners"
        # end
    end
end
@info "Instantiated async task to change color every second"

# In Bonito, you can create an HTML page / app by using the `App`
# constructor.  The way you link an app to an HTTP endpoint is 
# by using the `route!` function.
# Here, we reate a Bonito app for each session,
# that creates a plot where the color is linked to the 
# global `color` Observable.  This shows how to display plots
# where the plot is per-session but the data is shared across
# all sessions of this particular app / server.
plot_app = App(; threaded = true) do session::Session
    @info "Creating app for session $(session.id)"
    # Spawn the figure on a different thread in the 
    # default threadpool.  This means that the figure's 
    # renderloop runs on an arbitrary thread and is not
    # blocking the main thread.
    f, a, p = lines(rand(10); color = color)
    return f
end
# Now we link the app to the HTTP endpoint `/`
route!(server, "/" => plot_app)

# Apps can also return DOM divs
# ```julia
# page_404 = App() do session, request
#     return Bonito.DOM.div("no page for $(request.target)")
# end
# You can use string (paths), or a regex
# route!(server, r".*" => page_404)
# ```

# We may also want to serve some data over HTTP alongside the plot,
# like a JSON response or a text response.
# Let's serve a text response indicating the current color
# at the "/color" endpoint.

# Bonito doesn't require you to use apps - you can use 
# the `route!` function to serve arbitrary data behind
# a HTTP.jl Response.
# The handler function has to have this signature, though.

function color_handler(context, args...)
    (; routes, application, request, match) = context
    return HTTP.Response(
        200; 
        body =  color[] |> collect .|> UInt8,
        request
    )
end
route!(server, "/color" => color_handler)

# Start the server
@info "Starting Bonito server"
Bonito.HTTPServer.start(server)

@info "Server successfully started, waiting on connections"

# Wait for the server to exit, because if running in an app, the app will
# exit when the script is done.  This makes sure that the app is only closed
# if (a) the server closes, or (b) the app itself times out and is killed externally.
wait(server)