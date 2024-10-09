function load_data_from_genx(compare_with_TDR,case_path,genx_settings)

    H2_MWh = 33.33 # MWh per tonne of H2
    NG_MWh = 0.29307107 # MWh per MMBTU of NG 

    if compare_with_TDR==false
        df = CSV.read(case_path*"system/Demand_data.csv",DataFrame);
        df_var = CSV.read(case_path*"system/Generators_variability.csv",DataFrame);
        df_fuels = CSV.read(case_path*"system/Fuels_data.csv",DataFrame);
    else
        df = CSV.read(case_path*"TDR_results/Demand_data.csv",DataFrame);
        df_var = CSV.read(case_path*"TDR_results/Generators_variability.csv",DataFrame);
        df_fuels = CSV.read(case_path*"TDR_results/Fuels_data.csv",DataFrame);
    end

    macro_settings = (Commodities = Dict(Electricity=>Dict(:HoursPerTimeStep=>1,
                                                        :HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period],
                                                        :WeightsPerSubperiod=>collect(skipmissing(df[!,:Sub_Weights]))),
                                    Hydrogen=>Dict(:HoursPerTimeStep=>1,
                                                    :HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period],
                                                    :WeightsPerSubperiod=>collect(skipmissing(df[!,:Sub_Weights]))),
                                    NaturalGas=>Dict(:HoursPerTimeStep=>1,
                                                    :HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period],
                                                    :WeightsPerSubperiod=>collect(skipmissing(df[!,:Sub_Weights]))),
                                    CO2=>Dict(:HoursPerTimeStep=>1,
                                                :HoursPerSubperiod=>df[1,:Timesteps_per_Rep_Period],
                                                :WeightsPerSubperiod=>collect(skipmissing(df[!,:Sub_Weights])))),
                PeriodLength = df[1,:Rep_Periods]*df[1,:Timesteps_per_Rep_Period]);

    number_of_electricity_zones = length(names(df)[findfirst(names(df).=="Time_Index")+1:end]);

    all_timedata = create_time_data(macro_settings);

    e_nodes = Vector{Node{Electricity}}(undef, number_of_electricity_zones)
    for i in 1:number_of_electricity_zones
    e_nodes[i] = Node{Electricity}(;
        id = Symbol("E_node_$i"),
        demand = df[!,Symbol("Demand_MW_z$i")],
        timedata = all_timedata[Electricity],
        max_nsd = Float64.(df[.!ismissing.(df[!,:Max_Demand_Curtailment]),:Max_Demand_Curtailment]),
        price_nsd = Float64.(df[.!ismissing.(df[!,:Cost_of_Demand_Curtailment_per_MW]),:Cost_of_Demand_Curtailment_per_MW])*df[1,:Voll],
        constraints = [DemandBalanceConstraint(),MaxNonServedDemandConstraint(),MaxNonServedDemandPerSegmentConstraint()]
    )
    end

    ##Water nodes for Hydrostor; Added by Sam 
    w_nodes = Vector{Node{Water}}(undef, number_of_water_zones)
    for i in 1:number_of_water_zones
    e_nodes[i] = Node{Water}(;
        id = Symbol("W_node_$i"),
        demand = df[!,Symbol("Demand_MW_z$i")],
        timedata = all_timedata[Water],
        max_nsd = Float64.(df[.!ismissing.(df[!,:Max_Demand_Curtailment]),:Max_Demand_Curtailment]),
        price_nsd = Float64.(df[.!ismissing.(df[!,:Cost_of_Demand_Curtailment_per_MW]),:Cost_of_Demand_Curtailment_per_MW])*df[1,:Voll],
        constraints = [DemandBalanceConstraint(),MaxNonServedDemandConstraint(),MaxNonServedDemandPerSegmentConstraint()]
    )
    end
    ##Water nodes for Hydrostor; Added by Sam 

    df = CSV.read(case_path*"system/Network.csv",DataFrame);
    number_of_electricity_lines = maximum(df[.!ismissing.(df[!,:Network_Lines]),:Network_Lines]);
    e_edges = Vector{Edge{Electricity}}(undef,number_of_electricity_lines)
    for i in 1:number_of_electricity_lines

    e_edges[i] = Edge{Electricity}(;
        timedata = all_timedata[Electricity],
        start_node = e_nodes[df[i,:Start_Zone]],
        end_node = e_nodes[df[i,:End_Zone]],
        existing_capacity = df[i,:Line_Max_Flow_MW],
        unidirectional = false,
        max_line_reinforcement = df[i,:Line_Max_Reinforcement_MW],
        line_reinforcement_cost = df[i,:Line_Reinforcement_Cost_per_MWyr],
        can_expand = genx_settings.NetworkExpansion==1,
        line_loss_fraction = df[i,:Line_Loss_Percentage],
        distance = df[i,:distance_mile],
        constraints = [CapacityConstraint()]
    )

    end

    df = CSV.read(case_path*"resources/Vre.csv",DataFrame);

    vre = Vector{Transformation{VRE}}(undef, size(df,1))
    for r in eachrow(df)
    idx = rownumber(r);
    vre[idx] = Transformation{VRE}(;
    id = Symbol(r.Resource),
    timedata = all_timedata[Electricity],
    )

    vre[idx].TEdges[:E] = TEdge{Electricity}(;
        id = :E,
        timedata = all_timedata[Electricity],
        node = e_nodes[r.Zone],
        transformation = vre[idx],
        direction = :output,
        has_planning_variables = true,
        can_expand = r.New_Build==1,
        can_retire = r.Can_Retire==1,
        capacity_factor = df_var[!,Symbol(r.Resource)],
        existing_capacity = r.Existing_Cap_MW,
        investment_cost = r.Inv_Cost_per_MWyr,
        fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
        variable_om_cost = r.Var_OM_Cost_per_MWh,
        constraints = [CapacityConstraint()],
    )
    end


    df = CSV.read(case_path*"resources/Storage.csv",DataFrame);
    storage = Vector{Transformation{Storage}}(undef,size(df,1));
    for r in eachrow(df)
    idx = rownumber(r);
    storage[idx] = Transformation{Storage}(;
    id = Symbol(r.Resource),
    stoichiometry_balance_names = [:storage],
    timedata = all_timedata[Electricity],
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    existing_capacity_storage = r.Existing_Cap_MWh,
    investment_cost_storage = r.Inv_Cost_per_MWhyr,
    fixed_om_cost_storage = r.Fixed_OM_Cost_per_MWhyr,
    storage_loss_fraction = r.Self_Disch,
    min_duration = r.Min_Duration,
    max_duration = r.Max_Duration,
    discharge_edge = :discharge,
    charge_edge = :charge,
    constraints = [StorageCapacityConstraint(),SymmetricCapacityConstraint(),StoichiometryBalanceConstraint()],
    )
    storage[idx].TEdges[:discharge] = TEdge{Electricity}(;
    id = :discharge,
    node = e_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = storage[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost = r.Var_OM_Cost_per_MWh,
    st_coeff = Dict(:storage=>1/r.Eff_Down),
    constraints = [CapacityConstraint()],
    )

    storage[idx].TEdges[:charge] = TEdge{Electricity}(;
    id = :charge,
    node = e_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = storage[idx],
    direction = :input,
    has_planning_variables = false,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    variable_om_cost = r.Var_OM_Cost_per_MWh_In,
    st_coeff = Dict(:storage=>r.Eff_Up),
    )
    end

    ##Transformation for Hydrostor; Added by Sam
    vre = Vector{Transformation{VRE}}(undef, size(df,1))
    for r in eachrow(df)
    idx = rownumber(r);
    vre[idx] = Transformation{VRE}(;
    id = Symbol(r.Resource),
    timedata = all_timedata[Electricity],
    )

    vre[idx].TEdges[:E] = TEdge{Electricity}(;
        id = :E,
        timedata = all_timedata[Electricity],
        node = e_nodes[r.Zone],
        transformation = vre[idx],
        direction = :output,
        has_planning_variables = true,
        can_expand = r.New_Build==1,
        can_retire = r.Can_Retire==1,
        capacity_factor = df_var[!,Symbol(r.Resource)],
        existing_capacity = r.Existing_Cap_MW,
        investment_cost = r.Inv_Cost_per_MWyr,
        fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
        variable_om_cost = r.Var_OM_Cost_per_MWh,
        constraints = [CapacityConstraint()],
    )
    end


    df = CSV.read(case_path*"resources/Storage.csv",DataFrame);
    storage = Vector{Transformation{HydroStor}}(undef,size(df,1));
    for r in eachrow(df)
    idx = rownumber(r);
    hydrostorage[idx] = Transformation{HydroStor}(;
    id = Symbol(r.Resource),
    stoichiometry_balance_names = [:storage],
    timedata = all_timedata[Electricity],
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    existing_capacity_storage = r.Existing_Cap_MWh,
    investment_cost_storage = r.Inv_Cost_per_MWhyr,
    fixed_om_cost_storage = r.Fixed_OM_Cost_per_MWhyr,
    storage_loss_fraction = r.Self_Disch,
    min_duration = r.Min_Duration,
    max_duration = r.Max_Duration,
    discharge_edge = :discharge,
    charge_edge = :charge,
    constraints = [StorageCapacityConstraint(),SymmetricCapacityConstraint(),StoichiometryBalanceConstraint()],
    )
    storage[idx].TEdges[:discharge] = TEdge{Electricity}(;
    id = :discharge,
    node = e_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = hydrostorage[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost = r.Var_OM_Cost_per_MWh,
    st_coeff = Dict(:storage=>1/r.Eff_Down),
    constraints = [CapacityConstraint()],
    )

    storage[idx].TEdges[:charge] = TEdge{Electricity}(;
    id = :charge,
    node = e_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = hydrostorage[idx],
    direction = :input,
    has_planning_variables = false,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    variable_om_cost = r.Var_OM_Cost_per_MWh_In,
    st_coeff = Dict(:storage=>r.Eff_Up),
    )
    end

    storage[idx].TEdges[:discharge] = TEdge{Water}(;
    id = :discharge,
    node = w_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = hydrostorage[idx],
    direction = :output,
    has_planning_variables = true,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    existing_capacity = r.Existing_Cap_MW,
    investment_cost = r.Inv_Cost_per_MWyr,
    fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
    variable_om_cost = r.Var_OM_Cost_per_MWh,
    st_coeff = Dict(:storage=>1/r.Eff_Down),
    constraints = [CapacityConstraint()],
    )

    storage[idx].TEdges[:charge] = TEdge{Water}(;
    id = :charge,
    node = w_nodes[r.Zone],
    timedata = all_timedata[Electricity],
    transformation = hydrostorage[idx],
    direction = :input,
    has_planning_variables = false,
    can_expand = r.New_Build==1,
    can_retire = r.Can_Retire==1,
    variable_om_cost = r.Var_OM_Cost_per_MWh_In,
    st_coeff = Dict(:storage=>r.Eff_Up),
    )
    ##Transformation for Hydrostor; Added by Sam

    ng_node = Node{NaturalGas}(;
        id = :ng_source,
        timedata = all_timedata[NaturalGas],
        demand = zeros(length(all_timedata[NaturalGas].time_interval)),   
        #### Note that this node does not have a demand balance because we are modeling exogenous inflow of NG
    )

    df_co2 = CSV.read(case_path*"policies/CO2_cap.csv",DataFrame);
    #### We have as many CO2 nodes as the CO_2_Cap_Zones
    co2_cap_zones = names(df_co2)[occursin.("CO_2_Cap_Zone_",names(df_co2))];
    co2_nodes = Vector{Node{CO2}}(undef,length(co2_cap_zones))
    for i in 1:length(co2_cap_zones)
    co2_nodes[i] = Node{CO2}(;
    id = Symbol("CO2_node_$i"),
    timedata = all_timedata[CO2],
    demand = zeros(length(all_timedata[CO2].time_interval)),
    rhs_policy = Dict(CO2CapConstraint => 1e6*sum(df_co2[z,Symbol("CO_2_Max_Mtons_$i")] for z in findall(collect(df_co2[:,Symbol("CO_2_Cap_Zone_$i")]).==1))),
    constraints = [CO2CapConstraint()]
    )
    end

    df = CSV.read(case_path*"resources/Thermal.csv",DataFrame);
    thermal = Vector{Transformation{NaturalGasPower}}(undef,size(df,1));
    for r in eachrow(df)
    idx = rownumber(r);
    thermal[idx] = Transformation{NaturalGasPower}(;
        id = Symbol(r.Resource),
        timedata = all_timedata[Electricity],
        stoichiometry_balance_names = [:energy,:emissions],
        constraints = [StoichiometryBalanceConstraint()]
    )

    thermal[idx].TEdges[:E] = TEdgeWithUC{Electricity}(;
        id = :E,
        timedata = all_timedata[Electricity],
        node = e_nodes[r.Zone],
        transformation = thermal[idx],
        direction = :output,
        has_planning_variables = true,
        can_expand = r.New_Build=1,
        can_retire = r.Can_Retire==1,
        capacity_size = r.Cap_Size,
        st_coeff = Dict(:energy=>r.Heat_Rate_MMBTU_per_MWh*NG_MWh,:emissions=>0.0),
        existing_capacity = r.Existing_Cap_MW,
        investment_cost = r.Inv_Cost_per_MWyr,
        fixed_om_cost = r.Fixed_OM_Cost_per_MWyr,
        variable_om_cost =r.Var_OM_Cost_per_MWh,
        ramp_up_fraction = r.Ramp_Up_Percentage,
        ramp_down_fraction = r.Ramp_Dn_Percentage,
        min_flow_fraction = r.Min_Power,
        min_up_time = r.Up_Time,
        min_down_time = r.Down_Time,
        start_cost = r.Start_Cost_per_MW,
        start_fuel = r.Start_Fuel_MMBTU_per_MW*NG_MWh,
        start_fuel_stoichiometry_name = :energy,
        constraints = [CapacityConstraint(), 
                        RampingLimitConstraint(),
                        MinFlowConstraint(),
                        MinUpTimeConstraint(),
                        MinDownTimeConstraint()]
    )

    thermal[idx].TEdges[:NG] = TEdge{NaturalGas}(;
        id = :NG,
        timedata = all_timedata[NaturalGas],
        node = ng_node,
        transformation = thermal[idx],
        direction = :input,
        has_planning_variables = false,
        st_coeff = Dict(:energy=>1.0,:emissions=>df_fuels[1,Symbol(r.Fuel)]/NG_MWh),
        price = df_fuels[2:end,Symbol(r.Fuel)]/NG_MWh,
    )

    for co2capzone in findall(collect(df_co2[r.Zone,Symbol.(co2_cap_zones)]).==1)
        thermal[idx].TEdges[Symbol("CO2_$co2capzone")] = TEdge{CO2}(;
        id = Symbol("CO2_$co2capzone"),
        timedata = all_timedata[CO2],
        node = co2_nodes[co2capzone],
        transformation = thermal[idx],
        direction = :output,
        has_planning_variables = false,
        st_coeff = Dict(:energy=>0.0,:emissions=>1.0)
        )
    end

    end

return [e_nodes;ng_node;co2_nodes;e_edges;vre;storage;thermal], all_timedata


end