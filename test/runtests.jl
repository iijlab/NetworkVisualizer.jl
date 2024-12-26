using Oxygen
using NetworkVisualizer
using Test
using Aqua
using JET

@testset "NetworkVisualizer.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(NetworkVisualizer)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(NetworkVisualizer; target_defined_modules = true)
    end

    # Write your tests here.
    cd("..")
    start_server(; mock = true, async = true)
    sleep(3)
    Oxygen.terminate()
end
