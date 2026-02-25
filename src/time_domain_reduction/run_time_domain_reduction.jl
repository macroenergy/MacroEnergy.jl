function run_time_domain_reduction(case_path::String, myTDRsetup::Dict; num_periods::Int = 1, v::Bool=false)

    # Load settings
    system_path = joinpath(case_path, "system")

    # Check for existing files to skip running TDR
    tdr_output_path = joinpath(system_path, myTDRsetup["TimeDomainReductionFolder"])

    if v
        println("TDR Settings: ")
        println("    TimestepsPerRepPeriod       : ", myTDRsetup["TimestepsPerRepPeriod"])
        println("    NumberOfSubperiods          : ", myTDRsetup["NumberOfSubperiods"])
        println("    ClusterMethod               : ", myTDRsetup["ClusterMethod"])
        println("    ScalingMethod               : ", myTDRsetup["ScalingMethod"])
        println("    UseExtremePeriods           : ", myTDRsetup["UseExtremePeriods"])
        println("    ClusterSubperiodResults     : ", myTDRsetup["ClusterSubperiodResults"])
        println("    TotalHoursModeled           : ", myTDRsetup["TotalHoursModeled"])
        println("    Output folder               : ", tdr_output_path)
        println()
    end

    for s in 1:num_periods

        @info "Setup TDR for period $s"

        if tdr_inputs_exist(tdr_output_path, myTDRsetup; period_idx = s)
            @info "Skipping full TDR — existing files detected for period $s"
            continue
        else
            @info "Initializing TDR for period $(s)"
            mkpath(tdr_output_path)
        end

        # Pre-clustering processing
        (ClusteringInputDF, ModifiedDataNormalized, NClusters, ExtremeWksList) = pre_clustering_tdr(case_path, myTDRsetup; period_idx = s, v=v)

        # Clustering
        (A, M, W) = clustering_tdr(tdr_output_path, myTDRsetup, ClusteringInputDF, NClusters; period_idx = s, v=v)

        # Post-clustering processing
        (A, W, M, PeriodMap) = post_clustering_tdr(myTDRsetup, ClusteringInputDF, NClusters, A, W, M, ExtremeWksList, ModifiedDataNormalized; v=v)

        # Write outputs
        write_outputs_tdr(case_path, myTDRsetup, PeriodMap, M; period_idx = s, v=v)
    end

    @info "TDR Completed"
    
end
