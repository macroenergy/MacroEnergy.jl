function clustering_tdr(tdr_output_path, myTDRsetup, ClusteringInputDF, NClusters; period_idx::Int = 1, v::Bool=false)
    
    println("=== Step 5: Clustering ===")

    # Extract key parameters
    TimestepsPerRepPeriod = myTDRsetup["TimestepsPerRepPeriod"]
    NumberOfSubperiods = myTDRsetup["NumberOfSubperiods"]
    ClusterMethod = myTDRsetup["ClusterMethod"]
    nReps = myTDRsetup["nReps"]

    # Run clustering
    cluster_results = []

    println("Performing TDR clustering using method: ", ClusterMethod)
    println("TimestepsPerRepPeriod = $TimestepsPerRepPeriod")
    println("NumberOfSubperiods = $NumberOfSubperiods")

    push!(cluster_results, cluster(tdr_output_path, myTDRsetup, ClusterMethod, ClusteringInputDF, NClusters, nReps; period_idx = period_idx, v=v))

    # Interpret Final Clustering Result
    R = last(cluster_results)[1]  # Cluster Object
    A = last(cluster_results)[2]  # Assignments
    W = last(cluster_results)[3]  # Weights
    M = last(cluster_results)[4]  # Centers or Medoids
    DistMatrix = last(cluster_results)[5]  # Pairwise distances
    autoencoder_training_time = last(cluster_results)[6]
    clustering_time = last(cluster_results)[7]
    
    if v
        println("Sum(W): Total Cluster Weights: ", sum(W))
    end

    A = Int.(A)
    M = Int.(M)

    println("=== Completed ===") 
    println()

    return (A, M, W)
end