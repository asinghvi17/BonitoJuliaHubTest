#=
This is a simple test case and example of the 
single-producer, multiple-session architecture with Bonito.

There is a global Observable that 
=#

@info "Starting BonitoJuliaHubTest"
@info "Number of threads: $(Threads.nthreads())"
@info "Number of CPU threads: $(Sys.CPU_THREADS)"
@info "Number of threadpools: $(Threads.nthreadpools())"
@info "Running on threadpool $(Threads.threadpool()) with $(Threads.threadpoolsize(Threads.threadpool())) threads."


using Bonito, Observables, WGLMakie
# using Bonito: @js_str, onjs, Button, TextField, Slider, linkjs, Session, App
using Bonito.DOM
# using Hyperscript
@info "Loaded all packages"

color = Observable("red")
number_of_listeners = 0


Threads.@spawn begin
    tic = time()
    while true
        elapsed = tic - time()
        tic = time()
        (elapsed < 1) && sleep(1 - elapsed)
        color[] = color[] == "red" ? "blue" : "red"

        # Log when number of listeners changes - this is important to know
        # so that we can understand if the Observable architecture used here makes
        # sense, or if we should use a different architecture, like channels or 
        # global arrays that get polled every frame.
        # if number_of_listeners != length(color.listeners)
        #     number_of_listeners = length(color.listeners)
        #     @info "Number of listeners changed to $number_of_listeners"
        # end
    end
end
@info "Instantiated async task to change color every second"

# Create a Bonito app for each session,
# that creates a plot where the color is linked to the 
# global `color` Observable.  This is a proxy for any
# global task that runs once but must be displayed in 
# multiple sessions.
app = App() do session::Session
    @info "Creating app for session "
    f, a, p = lines(rand(10); color = color)
    return f
end

# If the server was already created, close it
# Mainly for interactive use in the REPL
if isdefined(Main, :server)
    close(server)
end

# Get the DNS and port from environment variables,
# and log the values we are using.
port = get(ENV, "PORT", "8081") # it's guaranteed this exists on JuliaHub

if haskey(ENV, "PORT")
    @info "Using port from environment variable PORT: $port"
else
    @info "Using default port: $port"
end

BONITO_PROXY = get(ENV, "BONITO_PROXY", "")
if isempty(BONITO_PROXY)
    @info "No Bonito proxy found in environment variable BONITO_PROXY"
else
    @info "Using Bonito proxy from BONITO_PROXY: $BONITO_PROXY"
end

# Construct the Bonito server
# JuliaHub uses nginx as a proxy server,
# so we need to tell Bonito what the final URL will be.
# If you select the DNS on the app,
# then you must provide Bonito the environment variable BONITO_PROXY
# set to "$DNS.internal.juliahub.com" (or your juliahub.com subdomain).
@info "Constructing Bonito server on 0.0.0.0:$port $(isempty(BONITO_PROXY) ? "" : "with proxy $BONITO_PROXY")"
server = Bonito.Server(app, "0.0.0.0", parse(Int, port); proxy_url = BONITO_PROXY, verbose = 3)

# Start the server
@info "Starting Bonito server"
Bonito.HTTPServer.start(server)
# Bonito.HTTPServer.route!(server, "/" => app) # Overwrite app after changing it
@info "Server successfully started, waiting on connections"

# Wait for the server to exit, because if running in an app, the app will
# exit when the script is done.  This makes sure that the app is only closed
# if (a) the server closes, or (b) the app itself times out and is killed externally.
wait(server)