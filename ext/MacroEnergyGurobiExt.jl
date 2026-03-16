module MacroEnergyGurobiExt

import MacroEnergy: opt_env, set_opt_env!
import Gurobi
const _LOCK = ReentrantLock()

function gurobi_env!()
    env = opt_env(:Gurobi)
    if !isnothing(env)
        return env
    end

    lock(_LOCK)
    try
        env = Gurobi.Env()
        set_opt_env!(:Gurobi, env)
        return env
    catch e
        if isa(e, ErrorException) && occursin("Gurobi Error", string(e))
            @debug "Failed to initialize the Gurobi environment: $e"
        else
            rethrow(e)
        end
    finally
        unlock(_LOCK)
    end
end

opt_env(::Type{Gurobi.Optimizer}) = gurobi_env!()

end