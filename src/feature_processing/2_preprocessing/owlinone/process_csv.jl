using CSV
using Glob
using Dates
using ArgParse
using TimeZones
using DataFrames
using TableReader
using StringEncodings

# function parse_commandline()
#     args = Dict{String,Any}()
#     args["sensor"] = "jelly"
#     args["data_folder"] = expanduser("~/Documents/Research/TILES/Data/tiles-phase1-wav123/owlinone/jelly/")
#     args["write_folder"] = expanduser("~/Documents/Research/TILES/Data/tiles-phase1-wav123-processed/2_raw_csv_data/owlinone/test_jelly/")
#     args["deviceids"] = "deviceIDs.csv"
#     args["directories"] = "directories_by_date_wav123.csv"
#     args["files"] = "*.csv.gz"
#     args["earliest_date"] = Date(2018,03,04)

#     return args
# end

function parse_commandline()
    settings = ArgParseSettings()

    @add_arg_table settings begin
        "--data_folder", "-r"
            help = "Path to the data folder containing csv.gz files."
            arg_type = String
            required = true
            range_tester = ispath
        "--write_folder", "-w"
            help = "Path to the folder into which the files are written."
            arg_type = String
            required = true
            range_tester = ispath
        "--sensor", "-s"
            help = "Sensor information to parse from {owl, jelly, minew}."
            arg_type = String
            range_tester = (x -> x in ["jelly", "owl", "minew"])
            required = true
         "--deviceids", "-i"
            help = "DeviceIDs for each Owl-in-One."
            required = false
            default = "deviceIDs.csv"
            arg_type = String
         "--directories", "-d"
            help = "Directory <-> receiverId mapping for each wave of data"
            required = false
            default = "directories_by_date_wav123.csv"
            arg_type = String
         "--files", "-f"
            help = "CSV file(s) to process in data_folder. It can be a regex such as *.csv.gz (default)"
            default = "*.csv.gz"
            arg_type = String
            required = false
    end

    return parse_args(settings)
end

"""
function getdatetime(unixtime::Int64; tz::TimeZones.VariableTimeZone=tz)

    Get datetime in a given tz from a unix time. Assumes that that unix time
    includes milliseconds.
"""
function getdatetime(unixtime::Int64; tz::TimeZones.VariableTimeZone=tz"America/Los_Angeles")
    return DateTime(ZonedDateTime(unix2datetime(unixtime/1000), tz, from_utc=true))
end

function fixtimes!(df::DataFrame; tz::TimeZones.VariableTimeZone=tz"America/Los_Angeles")
    df[!,:timeStamp] = getdatetime.(df[!,:timeStamp], tz=tz)
end

"""
function datefromfilename(file::String)

    Obtain a date from a filename.
"""
function datefromfilename(file::String; dateformat::DateFormat=DateFormat("yyyymmdd"))
    return Date(split(basename(file), '.')[1], dateformat)
end

"""
function getjellyID(hexID::Union{String,Missings.Missing})

    Decode the hex representation of the jelly ID into UTF-8.
"""
function getjellyID(hexID::Union{String,Missings.Missing})
    bytes = Array{UInt8,1}()
    participantId = ""

    try
        bytes = hex2bytes(hexID)
    catch KeyError
        return missing
    end

    try
        participantId = decode(bytes, "UTF-8")
    catch LoadError
        return missing
    end

    if !all(isxdigit, participantId)
        return missing
    else
        return participantId
    end
end

"""
function fixjellyID!(df::DataFrame)

    Helper function to decode Jelly IDs in a DataFrame.
"""
function fixjellyID!(df::DataFrame)
    df[!,:jellyId] = getjellyID.(df[!,:jellyId])
end

function main()
    args = parse_commandline()
    args["data_folder"] = expanduser(args["data_folder"])
    args["write_folder"] = expanduser(args["write_folder"])
    try
        mkdir(args["write_folder"])
    catch SystemError
    end

    files = glob(args["files"], args["data_folder"])

    # deviceIDS -> receiverIDs mapping
    println("Loading deviceIDs from $(args["deviceids"])")
    deviceIDs = readcsv(args["deviceids"])
    deviceIDs = Dict(deviceIDs[!,:deviceId] .=> deviceIDs[!,:receiverId])

    # receiverIDs -> directories mapping
    println("Loading directories by date from $(args["directories"])")
    directories = readcsv(args["directories"])

    dates = datefromfilename.(files)

    if length(files) > 1
        println("Processing started on ", Dates.format(now(), "Y-m-dd @ HH:MM"))
        for (d, date) in enumerate(dates)
            if d < length(files)
                print("Processing date "); printstyled("$(date) / $(dates[end])\n", bold=true)
                today = readcsv(files[d]) # has current and next date
                tomorrow = readcsv(files[d+1])

                fixtimes!(today)
                fixtimes!(tomorrow)

                receiverIDs = Dict(directories[!,:receiverId] .=> directories[!, Symbol(date + Day(1))])

                df = vcat(
                    today[Date.(today[!,:timeStamp]) .== date, :],
                    tomorrow[Date.(tomorrow[!,:timeStamp]) .== date, :]
                    )

                df[!,:receiverDirectory] = [id in keys(receiverIDs) ? receiverIDs[id] : missing for id in df[!,:receiverId]]

                if args["sensor"] == "owl"
                    df[!,:deviceDirectory] = [id in keys(deviceIDs) ? receiverIDs[deviceIDs[id]] : missing for id in df[!,:deviceId]]
                    select!(df, [:timeStamp, :deviceDirectory, :receiverDirectory, :rssi])
                elseif args["sensor"] == "minew"
                    select!(df, [:timeStamp, :deviceId, :productModel, :receiverDirectory, :rssi])
                elseif args["sensor"] == "jelly"
                    fixjellyID!(df)
                    select!(df, [:timeStamp, :jellyId, :receiverDirectory, :rssi])
                end

                CSV.write(joinpath(args["write_folder"], string(replace(string(date), "-" => ""), ".csv")), df)
            end
        end
    else
        @warn "I need at least two files to process the data."
    end
end

main()