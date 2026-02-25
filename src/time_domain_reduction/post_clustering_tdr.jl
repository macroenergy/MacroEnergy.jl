function post_clustering_tdr(myTDRsetup::Dict, ClusteringInputDF, NClusters, A, W, M, ExtremeWksList, ModifiedDataNormalized; v::Bool=false)
    
    UseExtremePeriods = myTDRsetup["UseExtremePeriods"]

    ################################################################
    ################### Step 6 - Post Processing ###################
    ################################################################

    println("=== Step 6: Chronological Sorting and Mapping, Create Period Map ===")

    # Orginal M is produced in alphabetical order
    # Need to identify the right data point number based on column name
    M = [parse(Int64, string(names(ClusteringInputDF)[i])) for i in M]
    
    # ClusterInputDF Ordering of All Periods
    A_Dict = Dict()   # States index of representative period within M for each period a in A
    M_Dict = Dict()   # States representative period m for each period a in A
    for i in 1:length(A)
        A_Dict[parse(Int64, string(names(ClusteringInputDF)[i]))] = A[i]
        M_Dict[parse(Int64, string(names(ClusteringInputDF)[i]))] = M[A[i]]
    end

    # Add extreme periods into the clustering result
    ExtremeWksList = sort(ExtremeWksList)
    if UseExtremePeriods == 1
        if v
            println("Extreme Periods: ", ExtremeWksList)
        end
        M = [M; ExtremeWksList]
        A_idx = NClusters + 1
        for w in ExtremeWksList
            A_Dict[w] = A_idx
            M_Dict[w] = w
            push!(W, 1)
            A_idx += 1
        end
        NClusters += length(ExtremeWksList) # NClusers from this point forward is the ending number of periods
    end 

    # Recreate A in numeric order (as opposed to ClusterInputDF order)
    A = [A_Dict[i] for i in 1:(length(A) + length(ExtremeWksList))]

    # Order representative periods chronologically
    # Sort A, W, M in conjunction, chronologically by M to be consistent
    old_M = M
    df_sort = DataFrame( Weights = W, Rep_Period = M)
    sort!(df_sort, [:Rep_Period])
    W = df_sort[!, :Weights]
    M = df_sort[!, :Rep_Period]

    # Sorting the representative periods to be in chronological order
    AssignMap = Dict( i => findall(x->x==old_M[i], M)[1] for i in 1:length(M))
    A = [AssignMap[a] for a in A]

    # Make PeriodMap, maps each period to its representative period
    PeriodMap = DataFrame(Period_Index = 1:length(A),
                            Rep_Period = [M[a] for a in A],
                            Rep_Period_Index = [a for a in A])

    if v
        println("Representative periods: ", M)
        println("Cluster weights: ", W)
        println("Assignments: ", A)
     end

    # Extract representative profiles and convert dataframes to numeric matrices for RMSE computation
    rep_profiles = ModifiedDataNormalized[:, M]
    reconstructed_series = hcat([rep_profiles[:, A[j]] for j in 1:length(A)]...)

    # RMSE
    MSE = mean((Matrix(ModifiedDataNormalized) .- Matrix(reconstructed_series)) .^ 2)
    RMSE = sqrt(MSE)

    println("Normalized RMSE across all series: ", round(RMSE, digits=6))

    println("=== Completed ===") 
    println()

    return A, W, M, PeriodMap

end
