module TestTimeData

using Test
import MacroEnergy: TimeData, Hydrogen, NaturalGas, Electricity
import MacroEnergy: load_time_data, load_period_map!

include("utilities.jl")

function test_time_data_commodity(input_data, expected_data, rel_path)
    haskey(input_data, :PeriodMap) && load_period_map!(input_data, rel_path)

    time_data = load_time_data(input_data, Dict(
        :Hydrogen => Hydrogen,
        :NaturalGas => NaturalGas,
        :Electricity => Electricity
    ))
    
    @test length(time_data) == length(expected_data)
    for (k, v) in time_data
        # Check that the keys are the same
        @test k in keys(expected_data)
        # Check that the fields are the same
        for i in fieldnames(typeof(v))
            @test getfield(v, i) == getfield(expected_data[k], i)
        end
    end
end

function test_load_time_data()
    rel_path = "test_inputs"
    
    # Test different input data
    scenarios = [
        (input_data_no_period_map, time_data_true_no_period_map, "No period map"),
        (input_data_with_period_map, time_data_true_with_period_map, "With period map")
    ]
    
    for (input_data, expected_data, scenario_name) in scenarios
        @testset "$scenario_name" begin
            @error_logger test_time_data_commodity(input_data, expected_data, rel_path)
        end
    end
    
    return nothing
end

input_data_no_period_map = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :PeriodLength => 504
)

input_data_with_period_map = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :PeriodLength => 504,
    :PeriodMap => Dict(
        :path => "system/Period_map.csv"
    )
)

time_data_true_no_period_map = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 168.0, 2 => 168.0, 3 => 168.0), period_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 168.0, 2 => 168.0, 3 => 168.0), period_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 168.0, 2 => 168.0, 3 => 168.0), period_map=Dict(1 => 1, 2 => 2, 3 => 3))
)

period_map = Dict(56 => 363, 35 => 83, 60 => 363, 220 => 230, 308 => 363, 67 => 230, 215 => 363, 73 => 230, 319 => 363, 251 => 363,
    115 => 363, 112 => 363, 185 => 83, 348 => 83, 365 => 363, 333 => 230, 86 => 83, 168 => 230, 364 => 363, 207 => 363,
    263 => 363, 242 => 83, 183 => 83, 224 => 230, 177 => 230, 12 => 230, 75 => 230, 23 => 230, 111 => 363, 264 => 363,
    41 => 83, 68 => 230, 82 => 83, 130 => 83, 125 => 230, 77 => 83, 172 => 230, 71 => 230, 339 => 83, 66 => 230,
    103 => 363, 280 => 230, 59 => 363, 208 => 363, 336 => 83, 26 => 83, 211 => 363, 343 => 83, 358 => 363, 127 => 83,
    116 => 230, 100 => 363, 79 => 83, 230 => 230, 279 => 230, 195 => 83, 141 => 83, 278 => 230, 135 => 83, 138 => 83,
    222 => 230, 107 => 363, 46 => 363, 276 => 230, 295 => 83, 57 => 363, 152 => 363, 247 => 83, 170 => 230, 129 => 83,
    238 => 83, 250 => 363, 78 => 83, 133 => 83, 72 => 230, 258 => 363, 184 => 83, 252 => 363, 1 => 363, 137 => 83,
    22 => 230, 154 => 363, 313 => 363, 237 => 83, 206 => 363, 288 => 83, 270 => 363, 354 => 363, 299 => 83, 33 => 83,
    345 => 83, 40 => 83, 113 => 363, 231 => 230, 245 => 83, 254 => 363, 283 => 230, 165 => 363, 309 => 363, 142 => 83,
    5 => 363, 55 => 363, 114 => 363, 265 => 363, 325 => 363, 136 => 83, 117 => 363, 45 => 363, 145 => 363, 282 => 230,
    275 => 230, 337 => 230, 342 => 83, 363 => 363, 351 => 83, 158 => 363, 218 => 363, 176 => 230, 28 => 83, 148 => 363,
    92 => 83, 36 => 83, 118 => 230, 162 => 363, 84 => 83, 7 => 363, 25 => 83, 95 => 363, 203 => 363, 292 => 83, 353 => 83,
    232 => 83, 93 => 83, 296 => 83, 304 => 363, 18 => 230, 240 => 83, 147 => 363, 157 => 363, 16 => 230, 341 => 83,
    287 => 83, 349 => 83, 19 => 230, 44 => 363, 266 => 363, 31 => 83, 217 => 363, 146 => 363, 74 => 230, 61 => 363,
    29 => 83, 212 => 363, 303 => 363, 228 => 230, 159 => 363, 193 => 83, 226 => 230, 101 => 363, 360 => 363, 105 => 363,
    223 => 230, 285 => 230, 17 => 230, 271 => 363, 335 => 230, 166 => 363, 89 => 83, 198 => 83, 214 => 363, 80 => 83,
    331 => 230, 51 => 363, 274 => 230, 246 => 83, 143 => 83, 48 => 363, 15 => 230, 97 => 363, 330 => 230, 284 => 83,
    134 => 83, 110 => 363, 30 => 83, 6 => 363, 234 => 83, 219 => 363, 272 => 230, 182 => 83, 164 => 363, 153 => 363,
    186 => 83, 253 => 363, 64 => 363, 267 => 363, 90 => 83, 139 => 83, 4 => 363, 13 => 230, 359 => 363, 104 => 363,
    316 => 363, 328 => 230, 52 => 363, 179 => 230, 356 => 363, 300 => 83, 43 => 363, 11 => 363, 69 => 230, 171 => 230,
    302 => 363, 85 => 83, 119 => 230, 39 => 83, 216 => 363, 126 => 230, 108 => 363, 156 => 363, 2 => 363, 10 => 230,
    27 => 83, 124 => 230, 261 => 363, 307 => 363, 144 => 83, 273 => 230, 257 => 363, 352 => 83, 200 => 363, 290 => 83,
    20 => 230, 81 => 83, 312 => 363, 340 => 83, 187 => 83, 213 => 363, 329 => 230, 9 => 363, 344 => 83, 189 => 83,
    346 => 83, 227 => 230, 294 => 83, 109 => 363, 161 => 363, 249 => 83, 241 => 83, 88 => 83, 209 => 363, 236 => 83,
    120 => 230, 323 => 363, 260 => 363, 297 => 83, 24 => 83, 8 => 363, 37 => 83, 83 => 83, 190 => 83, 201 => 363,
    99 => 363, 121 => 230, 311 => 363, 281 => 230, 14 => 230, 314 => 363, 357 => 363, 334 => 230, 174 => 230, 298 => 83,
    322 => 363, 269 => 363, 315 => 363, 123 => 230, 305 => 363, 268 => 363, 32 => 83, 197 => 83, 233 => 83, 196 => 363,
    262 => 363, 320 => 363, 324 => 363, 210 => 363, 151 => 363, 239 => 83, 54 => 363, 63 => 363, 191 => 83, 91 => 83,
    62 => 363, 205 => 363, 244 => 83, 327 => 230, 150 => 363, 122 => 230, 58 => 363, 199 => 363, 173 => 230, 256 => 363,
    188 => 83, 277 => 230, 361 => 363, 98 => 363, 355 => 83, 235 => 83, 204 => 363, 310 => 363, 321 => 363, 76 => 83,
    34 => 83, 50 => 363, 243 => 83, 318 => 363, 194 => 83, 167 => 363, 42 => 363, 87 => 83, 132 => 83, 140 => 83,
    202 => 363, 248 => 83, 169 => 363, 301 => 83, 317 => 363, 180 => 83, 255 => 363, 160 => 363, 289 => 83, 49 => 363,
    291 => 83, 106 => 363, 94 => 83, 225 => 230, 102 => 363, 128 => 83, 259 => 363, 70 => 230, 347 => 83, 332 => 230,
    21 => 230, 350 => 83, 229 => 230, 38 => 83, 163 => 363, 131 => 83, 192 => 83, 326 => 230, 221 => 363, 53 => 363,
    362 => 363, 47 => 363, 175 => 230, 286 => 83, 338 => 83, 3 => 363, 178 => 230, 96 => 363, 306 => 363, 149 => 363,
    155 => 363, 181 => 83, 65 => 230, 293 => 83)

time_data_true_with_period_map = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[83, 230, 363], subperiod_weights=Dict(83 => 126, 230 => 80, 363 => 159), period_map=period_map),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[83, 230, 363], subperiod_weights=Dict(83 => 126, 230 => 80, 363 => 159), period_map=period_map),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[83, 230, 363], subperiod_weights=Dict(83 => 126, 230 => 80, 363 => 159), period_map=period_map)
)

test_load_time_data()

end # module TestTimeData