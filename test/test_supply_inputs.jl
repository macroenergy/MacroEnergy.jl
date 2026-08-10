module TestSupplyInputs

using Test
using MacroEnergy
using JuMP
using HiGHS
using OrderedCollections: OrderedDict

import MacroEnergy: check_and_convert_supply!
import MacroEnergy: update_node_supply_inputs

function test_typed_supply_parses_to_supply_segments()
    data = Dict{Symbol,Any}(
        :supply => OrderedDict(
            :cheap => Dict(:price => [5.0, 6.0], :min => [1.0], :max => [10.0]),
            :firm => Dict(:price => 9.0, :max => 20.0),
        ),
    )

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :cheap => MacroEnergy.SupplySegment(price = [5.0, 6.0], min = [1.0], max = [10.0]),
        :firm => MacroEnergy.SupplySegment(price = [9.0], min = [0.0], max = [20.0]),
    )
end

function test_typed_supply_requires_price()
    data = Dict{Symbol,Any}(
        :supply => OrderedDict(
            :seg1 => Dict(:max => 10.0),
        ),
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_typed_supply_validates_min_max()
    data = Dict{Symbol,Any}(
        :supply => OrderedDict(
            :seg1 => Dict(:price => [5.0], :min => [12.0], :max => [10.0]),
        ),
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_empty_price_supply_normalizes_to_empty_segments()
    data = Dict{Symbol,Any}(:price_supply => Float64[])

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict{Symbol,MacroEnergy.SupplySegment}()
    @test data[:price_supply] == OrderedDict{Symbol,Vector{Float64}}()
    @test data[:max_supply] == OrderedDict{Symbol,Vector{Float64}}()
    @test data[:supply_segment_names] == Symbol[]
end

function test_single_vector_price_supply_defaults_to_inf_max_supply()
    data = Dict{Symbol,Any}(:price_supply => [5.0, 6.0])

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :segment1 => MacroEnergy.SupplySegment(price = [5.0, 6.0], min = [0.0], max = [Inf]),
    )
    @test data[:price_supply] == OrderedDict(:segment1 => [5.0, 6.0])
    @test data[:min_supply] == OrderedDict(:segment1 => [0.0])
    @test data[:max_supply] == OrderedDict(:segment1 => [Inf])
    @test data[:supply_segment_names] == [:segment1]
end

function test_legacy_price_supply_takes_precedence_over_empty_typed_supply()
    data = Dict{Symbol,Any}(
        :supply => OrderedDict{Symbol,Any}(),
        :price_supply => OrderedDict(:seg1 => [5.0, 6.0]),
        :max_supply => OrderedDict(:seg1 => [10.0]),
        :supply_segment_names => [:seg1],
    )

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :seg1 => MacroEnergy.SupplySegment(price = [5.0, 6.0], min = [0.0], max = [10.0]),
    )
    @test data[:price_supply] == OrderedDict(:seg1 => [5.0, 6.0])
    @test data[:max_supply] == OrderedDict(:seg1 => [10.0])
    @test data[:supply_segment_names] == [:seg1]
end

function test_single_segment_dict_preserves_segment_name_without_max_supply()
    data = Dict{Symbol,Any}(:price_supply => OrderedDict(:gas => [5.0, 6.0]))

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :gas => MacroEnergy.SupplySegment(price = [5.0, 6.0], min = [0.0], max = [Inf]),
    )
    @test data[:price_supply] == OrderedDict(:gas => [5.0, 6.0])
    @test data[:max_supply] == OrderedDict(:gas => [Inf])
    @test data[:supply_segment_names] == [:gas]
end

function test_vector_vector_inputs_are_segmented_and_named()
    data = Dict{Symbol,Any}(
        :price_supply => [5.0, 9.0],
        :max_supply => [10.0, 20.0],
        :supply_segment_names => [:cheap, :firm],
    )

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :cheap => MacroEnergy.SupplySegment(price = [5.0], min = [0.0], max = [10.0]),
        :firm => MacroEnergy.SupplySegment(price = [9.0], min = [0.0], max = [20.0]),
    )
    @test data[:price_supply] == OrderedDict(:cheap => [5.0], :firm => [9.0])
    @test data[:max_supply] == OrderedDict(:cheap => [10.0], :firm => [20.0])
    @test data[:supply_segment_names] == [:cheap, :firm]
end

function test_vector_vector_inputs_pad_and_trim_names()
    short_names = Dict{Symbol,Any}(
        :price_supply => [5.0, 9.0],
        :max_supply => [10.0, 20.0],
        :supply_segment_names => [:a],
    )
    long_names = Dict{Symbol,Any}(
        :price_supply => [5.0, 9.0],
        :max_supply => [10.0, 20.0],
        :supply_segment_names => [:a, :b, :c],
    )

    check_and_convert_supply!(short_names)
    check_and_convert_supply!(long_names)

    @test short_names[:supply_segment_names] == [:a, :segment1]
    @test short_names[:price_supply] == OrderedDict(:a => [5.0], :segment1 => [9.0])
    @test long_names[:supply_segment_names] == [:a, :b]
    @test long_names[:price_supply] == OrderedDict(:a => [5.0], :b => [9.0])
end

function test_mixed_vector_and_dict_inputs_normalize_max_supply()
    vector_price = Dict{Symbol,Any}(
        :price_supply => [5.0, 9.0],
        :max_supply => OrderedDict(:cheap => 10.0, :firm => 20.0),
    )
    vector_max = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:cheap => [5.0], :firm => [9.0]),
        :max_supply => [10.0, 20.0],
    )

    check_and_convert_supply!(vector_price)
    check_and_convert_supply!(vector_max)

    @test vector_price[:price_supply] == OrderedDict(:cheap => [5.0], :firm => [9.0])
    @test vector_price[:max_supply] == OrderedDict(:cheap => [10.0], :firm => [20.0])
    @test vector_price[:supply_segment_names] == [:cheap, :firm]

    @test vector_max[:price_supply] == OrderedDict(:cheap => [5.0], :firm => [9.0])
    @test vector_max[:max_supply] == OrderedDict(:cheap => [10.0], :firm => [20.0])
    @test vector_max[:supply_segment_names] == [:cheap, :firm]
end

function test_dict_inputs_convert_numeric_scalars_to_float_vectors()
    data = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:seg1 => 5),
        :min_supply => OrderedDict(:seg1 => 3),
        :max_supply => OrderedDict(:seg1 => 10),
    )

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :seg1 => MacroEnergy.SupplySegment(price = [5.0], min = [3.0], max = [10.0]),
    )
    @test data[:price_supply] == OrderedDict(:seg1 => [5.0])
    @test data[:min_supply] == OrderedDict(:seg1 => [3.0])
    @test data[:max_supply] == OrderedDict(:seg1 => [10.0])
    @test data[:supply_segment_names] == [:seg1]
end

function test_min_supply_defaults_to_zero_when_not_provided()
    data = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:cheap => [5.0], :firm => [9.0]),
        :max_supply => OrderedDict(:cheap => [10.0], :firm => [20.0]),
    )

    check_and_convert_supply!(data)

    @test data[:supply] == OrderedDict(
        :cheap => MacroEnergy.SupplySegment(price = [5.0], min = [0.0], max = [10.0]),
        :firm => MacroEnergy.SupplySegment(price = [9.0], min = [0.0], max = [20.0]),
    )
    @test data[:min_supply] == OrderedDict(:cheap => [0.0], :firm => [0.0])
end

function test_min_supply_vector_input_errors()
    data = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:seg1 => [5.0]),
        :max_supply => OrderedDict(:seg1 => [10.0]),
        :min_supply => [1.0],
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_min_supply_greater_than_max_supply_errors()
    data = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:seg1 => [5.0, 6.0]),
        :max_supply => OrderedDict(:seg1 => [10.0, 10.0]),
        :min_supply => OrderedDict(:seg1 => [8.0, 12.0]),
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_min_supply_is_enforced_in_operation_model()
    timedata = MacroEnergy.TimeData{MacroEnergy.Electricity}(;
        time_interval=1:2,
        hours_per_timestep=1,
        subperiods=[1:1, 2:2],
        subperiod_indices=[1, 2],
        subperiod_weights=Dict(1 => 1.0, 2 => 1.0),
        period_index=1,
    )

    node = MacroEnergy.Node{MacroEnergy.Electricity}(;
        id=:supply_node,
        timedata=timedata,
        balance_data=Dict(:demand => Dict{Symbol,Float64}()),
        supply=OrderedDict(
            :seg1 => MacroEnergy.SupplySegment(price = [3.0], min = [2.0], max = [5.0]),
        ),
    )

    model = Model(HiGHS.Optimizer)
    model[:vREF] = @variable(model, base_name="vREF")
    model[:eVariableCost] = AffExpr(0.0)

    MacroEnergy.operation_model!(node, model)
    @objective(model, Min, model[:eVariableCost])
    set_silent(model)
    optimize!(model)

    @test is_solved_and_feasible(model)
    @test value(MacroEnergy.supply_flow(node, 1, 1)) ≈ 2.0
    @test value(MacroEnergy.supply_flow(node, 1, 2)) ≈ 2.0
end

function test_multi_segment_price_supply_without_max_supply_errors()
    data = Dict{Symbol,Any}(
        :price_supply => OrderedDict(:seg1 => [5.0], :seg2 => [9.0]),
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_extra_names_without_max_supply_errors()
    data = Dict{Symbol,Any}(
        :price_supply => [5.0, 6.0],
        :supply_segment_names => [:a, :b],
    )

    @test_throws ArgumentError check_and_convert_supply!(data)
end

function test_update_node_supply_inputs_converts_legacy_schema_to_supply()
    data = Dict{Symbol,Any}(
        :type => :Biomass,
        :instance_data => [
            Dict{Symbol,Any}(
                :id => :bio_node,
                :price_supply => OrderedDict(:base => [40.0], :peak => [80.0]),
                :min_supply => OrderedDict(:base => [5.0], :peak => [0.0]),
                :max_supply => OrderedDict(:base => [10.0], :peak => [20.0]),
                :supply_segment_names => [:base, :peak],
            ),
        ],
    )

    update_node_supply_inputs(data)

    instance = data[:instance_data][1]
    @test instance[:supply] == OrderedDict(
        :base => OrderedDict(:price => [40.0], :min => [5.0], :max => [10.0]),
        :peak => OrderedDict(:price => [80.0], :min => [0.0], :max => [20.0]),
    )
    @test !haskey(instance, :price_supply)
    @test !haskey(instance, :min_supply)
    @test !haskey(instance, :max_supply)
    @test !haskey(instance, :supply_segment_names)
end

function test_update_node_supply_inputs_converts_price_to_supply()
    data = Dict{Symbol,Any}(
        :type => :NaturalGas,
        :instance_data => Dict{Symbol,Any}(
            :id => :fuel_node,
            :price => [7.0, 8.0],
        ),
    )

    update_node_supply_inputs(data)

    instance = data[:instance_data]
    @test instance[:supply] == OrderedDict(
        :segment1 => OrderedDict(:price => [7.0, 8.0], :min => [0.0], :max => [Inf]),
    )
    @test !haskey(instance, :price)
end

function test_update_node_supply_inputs_preserves_timeseries_supply_references()
    data = Dict{Symbol,Any}(
        :type => :NaturalGas,
        :instance_data => [
            Dict{Symbol,Any}(
                :id => :fuel_node,
                :price_supply => OrderedDict(
                    :seg1 => Dict(
                        :timeseries => Dict(
                            :path => "system/fuel_prices.csv",
                            :header => "CT_NG",
                        ),
                    ),
                ),
                :max_supply => OrderedDict(:seg1 => [Inf]),
                :supply_segment_names => [:seg1],
            ),
        ],
    )

    update_node_supply_inputs(data)

    instance = data[:instance_data][1]
    @test instance[:supply] == OrderedDict(
        :seg1 => OrderedDict(
            :price => Dict(
                :timeseries => Dict(
                    :path => "system/fuel_prices.csv",
                    :header => "CT_NG",
                ),
            ),
            :min => [0.0],
            :max => [Inf],
        ),
    )
    @test !haskey(instance, :price_supply)
    @test !haskey(instance, :max_supply)
    @test !haskey(instance, :supply_segment_names)
end

@testset "Supply Inputs" begin
    test_typed_supply_parses_to_supply_segments()
    test_typed_supply_requires_price()
    test_typed_supply_validates_min_max()
    test_empty_price_supply_normalizes_to_empty_segments()
    test_single_vector_price_supply_defaults_to_inf_max_supply()
    test_single_segment_dict_preserves_segment_name_without_max_supply()
    test_vector_vector_inputs_are_segmented_and_named()
    test_vector_vector_inputs_pad_and_trim_names()
    test_mixed_vector_and_dict_inputs_normalize_max_supply()
    test_dict_inputs_convert_numeric_scalars_to_float_vectors()
    test_min_supply_defaults_to_zero_when_not_provided()
    test_min_supply_vector_input_errors()
    test_min_supply_greater_than_max_supply_errors()
    test_min_supply_is_enforced_in_operation_model()
    test_multi_segment_price_supply_without_max_supply_errors()
    test_extra_names_without_max_supply_errors()
    test_update_node_supply_inputs_converts_legacy_schema_to_supply()
    test_update_node_supply_inputs_converts_price_to_supply()
    test_update_node_supply_inputs_preserves_timeseries_supply_references()
end

end # module TestSupplyInputs