using CSV
using Glob
using Missings
using ArgParse
using DataFrames
using TableReader

# We use these commands to mock the variables in case we want to explore in the REPL
# for debugging purposed (mostly)
# function parse_commandline()
# 	args = Dict{String,Any}()
# 	args["data_folder"] = "~/Documents/Research/TILES/Data/tiles-phase1-wav123-processed/2_raw_csv_data/owlinone/test_jelly"
# 	args["write_folder"] = "~/Documents/Research/TILES/Data/tiles-phase1-wav123-processed/2_raw_csv_data/owlinone/test_jelly/jelly_events_by_participant/"
# 	args["files"] = "*.csv.gz"# ["20190402.csv"]
# 	args["mapping"] = "jelly_id_mapping_wav123.csv"

# 	return args
# end

function parse_commandline()
    settings = ArgParseSettings()

    @add_arg_table settings begin
        "--data_folder", "-r"
            help = "Path to the data folder containing raw CSV files."
        	arg_type = String
        	required = true
            range_tester = ispath
        "--mapping", "-i"
        	help = "JellyIDs to EvidationIDs mapping in CSV format. Must contain columns participant_id and jelly_id."
        	arg_type = String
        	required = true
        	default = "jelly_id_mapping_wav123.csv"
        "--write_folder", "-w"
            help = "Path to the folder into which the files are written."
    		default = "jelly_events_by_participant/"
            arg_type = String
            required = false
        "--files", "-f"
        	help = "Files to split in CSV format."
        	default = "*.csv.gz"
        	arg_type = String
        	required = false
    end

    return parse_args(settings)
end

function main()
	args = parse_commandline()
	args["data_folder"] = expanduser(args["data_folder"])
	args["write_folder"] = expanduser(args["write_folder"]) # If necessary

	try
		mkdir(args["write_folder"])
	catch SystemError
		@warn "Write folder already exists"
	end

	mapping = CSV.read(args["mapping"])
	mapping = Dict(zip(mapping[!,:jellyID], mapping[!,:participantID]))

	files = glob(args["files"], args["data_folder"])
	data = readcsv.(files)
	data = vcat(data...)
	dropmissing!(data)

	jellyIDs = unique(data[!,:jellyId])
	jellyIDs = convert(Array{String,1}, filter(x -> length(x) == 4, collect(skipmissing(jellyIDs))))

	for participant in jellyIDs
		try
			filename = string(args["write_folder"], mapping[participant], ".csv")
			println("Writing file $(filename)")
			CSV.write(filename, data[data[!,:jellyId] .== participant,[:timeStamp, :receiverDirectory, :rssi]])
		catch KeyError
			# Do nothing
		end
	end
end

main()