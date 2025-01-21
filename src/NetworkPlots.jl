module NetworkPlots

using WGLMakie
using Bonito
using Dates
using Oxygen: html
import ..NetworkVisualizer: NetworkData, NetworkNode, NetworkLink, MetricData

# Cache active plots for data updates
const PLOT_DATA = Dict{String, Observable{Vector{Point2f}}}()

function init()
    WGLMakie.activate!()
end

"""
Convert timestamps to relative seconds for plotting
"""
function timestamps_to_seconds(timestamps::Vector{DateTime})
    t0 = minimum(timestamps)
    return Float32[Float32(Dates.value(t - t0) / 1000.0) for t in timestamps]
end

"""
Create a figure with a plot in it
"""
function create_figure(resource_id::String)
    data = PLOT_DATA[resource_id]

    # Create a figure with specific dimensions and styling
    fig = Figure(size = (800, 400), font = "Arial")
    ax = Axis(
        fig[1, 1],
        xlabel = "Time (seconds)",
        ylabel = "Allocation (%)",
        title = "Resource Allocation History",
        xgridvisible = true,
        ygridvisible = true,
        xtickalign = 1,
        ytickalign = 1,
    )

    # Create the line plot with styling
    lines!(ax, data; color = (:blue, 0.8), linewidth = 2)
    scatter!(ax, data; color = :blue, markersize = 4)

    # Set y axis limits for percentage and consistent ticks
    ylims!(ax, 0, 100)
    ax.yticks = 0:20:100

    # Rotate x ticks for better readability
    ax.xticklabelrotation = π / 4

    return fig
end

"""
Create or update a metric plot for a given resource
"""
function plot_metrics(resource_id::String, history::Vector{Dict{String, Any}})
    @info "Plot metrics called" resource_id=resource_id history_length=length(history)

    if isempty(history)
        @warn "Empty history, returning nothing" resource_id=resource_id
        return nothing
    end

    try
        timestamps = [DateTime(m["timestamp"], "yyyy-mm-ddTHH:MM:SSZ") for m in history]
        values = Float32[Float32(m["allocation"]) for m in history]
        @info "Data converted" resource_id=resource_id num_timestamps=length(timestamps) num_values=length(values)

        seconds = timestamps_to_seconds(timestamps)
        @info "Timestamps converted to seconds" resource_id=resource_id num_seconds=length(seconds)

        # Create or update Observable
        if !haskey(PLOT_DATA, resource_id)
            @info "Creating new plot data" resource_id=resource_id
            PLOT_DATA[resource_id] = Observable(Point2f.(seconds, values))
        else
            @info "Updating existing plot data" resource_id=resource_id
            PLOT_DATA[resource_id][] = Point2f.(seconds, values)
        end

        # Create app with plot using Bonito with proper styling
        app = App() do
            DOM.div(
                DOM.div(
                    create_figure(resource_id),
                    className = "bg-white p-4 shadow-sm rounded-lg",
                ),
                className = "w-full overflow-hidden",
            )
        end

        response = html(app)
        @info "Plot generated" resource_id=resource_id response_type=typeof(response) response_length=length(response.body)

        return response
    catch e
        @error "Error generating plot" resource_id=resource_id exception=(
            e, catch_backtrace(),)
        rethrow(e)
    end
end

"""
Add a new data point and return updated plot
"""
function add_point!(resource_id::String, timestamp::DateTime, value::Float64)
    if haskey(PLOT_DATA, resource_id)
        current_points = PLOT_DATA[resource_id][]

        # Get current points and convert new value
        timestamps = [DateTime(0) + Second(round(Int, p[1])) for p in current_points]
        push!(timestamps, timestamp)
        seconds = timestamps_to_seconds(timestamps)

        values = [p[2] for p in current_points]
        push!(values, Float32(value))

        # Keep only last 50 points if needed
        if length(seconds) > 50
            seconds = seconds[(end - 49):end]
            values = values[(end - 49):end]
        end

        PLOT_DATA[resource_id][] = Point2f.(seconds, values)

        # Create new app with updated plot
        app = App() do
            DOM.div(
                DOM.h3("Resource: $resource_id"),
                DOM.div(create_figure(resource_id)),
            )
        end

        return html(app)
    end
    return nothing
end

function remove_plot!(resource_id::String)
    delete!(PLOT_DATA, resource_id)
end

function clear_plots!()
    empty!(PLOT_DATA)
end

function get_active_plots()
    collect(keys(PLOT_DATA))
end

end # module
