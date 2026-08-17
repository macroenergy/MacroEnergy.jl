module TestContainerTypes


using Test
using JuMP
using HiGHS
using MacroEnergy

import MacroEnergy:
    AbstractEdge,
    AbstractStorage,
    AbstractVertex,
    AffExprArrayOrDense,
    DenseAffExprOverTime,
    DenseVarOverSegmentTime,
    DenseVarOverTime,
    MatrixVarOrDense,
    Node,
    VarArrayOrDense,
    array_container,
    flow,
    get_balance,
    non_served_demand,
    segments_non_served_demand,
    storage_level,
    supply_flow,
    supply_segments,
    time_interval,
    ucommit,
    ushut,
    ustart

const CASE_PATH = joinpath(@__DIR__, "test_small_case", "system_data.json")

# Index-set accessors with the same *return types* as the real ones in Macro, so the
# containers below go through the identical (non-literal) macro path.
fake_time_interval(first_t, n) = first_t:1:(first_t + n - 1)   # StepRange, as TimeData
fake_segments(n) = Base.OneTo(n)  # as segments_non_served_demand / supply_segments
unitrange_segments(n) = 1:n       # the shape both segment accessors must NOT return

# The real accessors must keep agreeing with each other and with `fake_segments`.
function test_segment_accessors_agree()
    n = first(filter(x -> x isa Node, first(load_case(CASE_PATH).systems).locations))
    @test typeof(segments_non_served_demand(n)) === Base.OneTo{Int64}
    @test typeof(supply_segments(n)) === Base.OneTo{Int64}
    @test typeof(fake_segments(2)) === typeof(segments_non_served_demand(n))
    return nothing
end

# ---------------------------------------------------------------------------
# 1. Derived types match what the JuMP macros really produce
# ---------------------------------------------------------------------------
function test_derived_types_match_jump()
    model = Model()

    # Benders subproblem shape: contiguous but not one-based -> DenseAxisArray.
    ti = fake_time_interval(169, 24)
    @test array_container(ti) === JuMP.Containers.DenseAxisArray

    v1d = @variable(model, [t in ti], container = array_container(ti))
    e1d = @expression(model, [t in ti], container = array_container(ti), 1.0 * v1d[t])
    v2d = @variable(
        model,
        [s in fake_segments(3), t in ti],
        container = array_container(ti)
    )

    @test typeof(v1d) === DenseVarOverTime
    @test typeof(e1d) === DenseAffExprOverTime
    @test typeof(v2d) === DenseVarOverSegmentTime

    # A `UnitRange` segment axis is a *different* container type, even though `1:3`
    # and `Base.OneTo(3)` are `==`.
    v2d_unitrange =
        @variable(model, [s in unitrange_segments(3), t in ti], container = array_container(ti))
    @test typeof(v2d_unitrange) !== DenseVarOverSegmentTime
    @test !(v2d_unitrange isa MatrixVarOrDense)

    # ...and every one of them is a member of the union its accessor asserts.
    @test v1d isa VarArrayOrDense
    @test e1d isa AffExprArrayOrDense
    @test v2d isa MatrixVarOrDense

    # One-based (Monolithic/Myopic, and Benders' first subproblem) -> plain Array.
    ti1 = fake_time_interval(1, 24)
    @test array_container(ti1) === Array
    w1d = @variable(model, [t in ti1], container = array_container(ti1))
    w2d = @variable(
        model,
        [s in fake_segments(3), t in ti1],
        container = array_container(ti1)
    )
    @test typeof(w1d) === Vector{VariableRef}
    @test typeof(w2d) === Matrix{VariableRef}
    @test w1d isa VarArrayOrDense
    @test w2d isa MatrixVarOrDense
    return nothing
end

# ---------------------------------------------------------------------------
# 2. Accessors infer concretely and do not allocate, on BOTH branches
# ---------------------------------------------------------------------------
# Loops are monomorphic and accumulate the MOI index so the read cannot be elided;
# `@allocated` over a splatting/closure harness measures the harness, not the read.
read_1d(c, t, n) = (a = 0; for _ = 1:n; a += ((c::VarArrayOrDense)[t]).index.value; end; a)
read_2d(c, s, t, n) = (a = 0; for _ = 1:n; a += ((c::MatrixVarOrDense)[s, t]).index.value; end; a)

function test_accessors_are_concrete_and_free()
    @test Base.return_types(read_1d, (VarArrayOrDense, Int, Int))[1] === Int
    @test Base.return_types(read_2d, (MatrixVarOrDense, Int, Int, Int))[1] === Int

    model = Model()
    ti_dense = fake_time_interval(169, 24)
    ti_flat = fake_time_interval(1, 24)

    dense_1d = @variable(model, [t in ti_dense], container = array_container(ti_dense))
    flat_1d = @variable(model, [t in ti_flat], container = array_container(ti_flat))
    dense_2d = @variable(model, [s in fake_segments(3), t in ti_dense], container = array_container(ti_dense))
    flat_2d = @variable(model, [s in fake_segments(3), t in ti_flat], container = array_container(ti_flat))

    n = 1_000
    for (c, t) in ((dense_1d, 169), (flat_1d, 1))
        read_1d(c, t, 10)
        @test (@allocated read_1d(c, t, n)) == 0
    end
    for (c, t) in ((dense_2d, 169), (flat_2d, 1))
        read_2d(c, 1, t, 10)
        @test (@allocated read_2d(c, 1, t, n)) == 0
    end
    return nothing
end

# ---------------------------------------------------------------------------
# 3. Every container in a real generated model is a union member
# ---------------------------------------------------------------------------
# If a new asset or vertex ever introduces a fourth container shape, this 
# fails instead of silently de-optimizing every accessor that touches it.
function collect_components(case)
    edges, storages, nodes, vertices = AbstractEdge[], AbstractStorage[], Node[], AbstractVertex[]
    for system in case.systems
        for n in system.locations
            n isa Node && push!(nodes, n)
            n isa AbstractVertex && push!(vertices, n)
        end
        for a in system.assets, f in fieldnames(typeof(a))
            v = getfield(a, f)
            v isa AbstractEdge && push!(edges, v)
            v isa AbstractStorage && push!(storages, v)
            v isa AbstractVertex && push!(vertices, v)
        end
    end
    return (; edges, storages, nodes, vertices)
end

function test_real_model_containers()
    case = load_case(CASE_PATH)
    alg = MacroEnergy.solution_algorithm(case)
    opt = create_optimizer(HiGHS.Optimizer, nothing, ("solver" => "ipm",))
    MacroEnergy.generate_model(case, opt, alg)

    c = collect_components(case)
    @test !isempty(c.edges)
    @test !isempty(c.vertices)

    n_flow = n_uc = n_level = n_nsd = n_supply = n_balance = 0
    for e in c.edges
        isempty(flow(e)) && continue
        @test flow(e) isa VarArrayOrDense
        @test flow(e, first(time_interval(e))) isa VariableRef
        n_flow += 1
        if e isa MacroEnergy.EdgeWithUC && !isempty(ucommit(e))
            for acc in (ucommit, ustart, ushut)
                @test acc(e) isa VarArrayOrDense
                @test acc(e, first(time_interval(e))) isa VariableRef
            end
            n_uc += 1
        end
    end
    for g in c.storages
        isempty(storage_level(g)) && continue
        @test storage_level(g) isa VarArrayOrDense
        @test storage_level(g, first(time_interval(g))) isa VariableRef
        n_level += 1
    end
    for n in c.nodes
        if !isempty(non_served_demand(n))
            @test non_served_demand(n) isa MatrixVarOrDense
            @test non_served_demand(n, first(segments_non_served_demand(n)), first(time_interval(n))) isa VariableRef
            n_nsd += 1
        end
        if !isempty(supply_flow(n))
            @test supply_flow(n) isa MatrixVarOrDense
            @test supply_flow(n, first(supply_segments(n)), first(time_interval(n))) isa VariableRef
            n_supply += 1
        end
    end
    for v in c.vertices, (bid, expr) in v.operation_expr
        @test expr isa AffExprArrayOrDense
        @test get_balance(v, bid, first(time_interval(v))) isa AffExpr
        n_balance += 1
    end

    # The walk must actually have covered each container kind, otherwise the asserts
    # above are vacuous and a broken union would still pass.
    @info "container coverage" n_flow n_uc n_level n_nsd n_supply n_balance
    @test n_flow > 0
    @test n_uc > 0
    @test n_level > 0
    @test n_nsd > 0        # both exercise DenseVarOverSegmentTime's shape
    @test n_supply > 0
    @test n_balance > 0
    return nothing
end

@testset "Container types" begin
    @testset "Segment accessors agree" begin
        test_segment_accessors_agree()
    end
    @testset "Derived types match JuMP" begin
        test_derived_types_match_jump()
    end
    @testset "Accessors concrete and allocation-free" begin
        test_accessors_are_concrete_and_free()
    end
    @testset "Real generated model" begin
        test_real_model_containers()
    end
end

end # module TestContainerTypes
